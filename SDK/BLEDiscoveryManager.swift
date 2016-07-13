//
//  BLEDiscoveryManager.swift
//  Nuimo
//
//  Created by Lars Blumberg on 12/10/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

import CoreBluetooth

/**
    Allows for easy discovering bluetooth devices.
    Automatically re-starts discovery if bluetooth was disabled for a previous discovery.
*/
public class BLEDiscoveryManager: NSObject {
    public private(set) lazy var centralManager: CBCentralManager = self.discovery.centralManager
    public var delegate: BLEDiscoveryManagerDelegate?

    private let options: [String : AnyObject]
    private lazy var discovery: BLEDiscoveryManagerPrivate = BLEDiscoveryManagerPrivate(discovery: self, options: self.options)

    public init(delegate: BLEDiscoveryManagerDelegate? = nil, options: [String : AnyObject] = [:]) {
        self.delegate = delegate
        self.options = options
        super.init()
    }

    /// If detectUnreachableDevices is set to true, it will invalidate devices if they stop advertising. Consumes more energy since `CBCentralManagerScanOptionAllowDuplicatesKey` is set to true.
    public func startDiscovery(_ discoverServiceUUIDs: [CBUUID], detectUnreachableDevices: Bool = false) {
        discovery.startDiscovery(discoverServiceUUIDs, detectUnreachableDevices: detectUnreachableDevices)
    }

    public func stopDiscovery() {
        discovery.stopDiscovery()
    }

    internal func invalidateDevice(_ device: BLEDevice) {
        discovery.invalidateDevice(device)
    }
}

public protocol BLEDiscoveryManagerDelegate {
    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, deviceWithPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject]?) -> BLEDevice?

    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didDiscoverDevice device: BLEDevice)

    func bleDiscoveryManager(_ discovery: BLEDiscoveryManager, didRestoreDevice device: BLEDevice)
}

/**
    Private implementation of BLEDiscoveryManager.
    Hides implementation of CBCentralManagerDelegate.
*/
private class BLEDiscoveryManagerPrivate: NSObject, CBCentralManagerDelegate {
    let discovery: BLEDiscoveryManager
    let options: [String : AnyObject]
    lazy var centralManager: CBCentralManager = CBCentralManager(delegate: self, queue: nil, options: self.options)
    var discoverServiceUUIDs = [CBUUID]()
    var detectUnreachableDevices = false
    var shouldStartDiscoveryWhenPowerStateTurnsOn = false
    var deviceForPeripheral = [CBPeripheral : BLEDevice]()
    var restoredConnectedPeripherals: [CBPeripheral]?

    init(discovery: BLEDiscoveryManager, options: [String : AnyObject]) {
        self.discovery = discovery
        self.options = options
        super.init()
    }

    func startDiscovery(_ discoverServiceUUIDs: [CBUUID], detectUnreachableDevices: Bool) {
        self.discoverServiceUUIDs = discoverServiceUUIDs
        self.detectUnreachableDevices = detectUnreachableDevices
        self.shouldStartDiscoveryWhenPowerStateTurnsOn = true

        guard centralManager.state == .poweredOn else { return }
        startDiscovery()
    }

    func startDiscovery() {
        var options = self.options
        options[CBCentralManagerScanOptionAllowDuplicatesKey] = detectUnreachableDevices
        centralManager.scanForPeripherals(withServices: discoverServiceUUIDs, options: options)
    }

    func stopDiscovery() {
        centralManager.stopScan()
        shouldStartDiscoveryWhenPowerStateTurnsOn = false
    }

    func invalidateDevice(_ device: BLEDevice) {
        device.invalidate()
        // Remove all peripherals associated with controller (there should be only one)
        deviceForPeripheral
            .filter{ $0.1 == device }
            .forEach { deviceForPeripheral.removeValue(forKey: $0.0) }
    }

    @objc func centralManager(_ central: CBCentralManager, willRestoreState state: [String : AnyObject]) {
        //TODO: Should work on OSX as well. http://stackoverflow.com/q/33210078/543875
        #if os(iOS)
            restoredConnectedPeripherals = (state[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?.filter{ $0.state == .Connected }
        #endif
    }

    @objc func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            restoredConnectedPeripherals?.forEach{ centralManager(central, didRestorePeripheral: $0) }
            restoredConnectedPeripherals = nil
            // When bluetooth turned on and discovery start had already been triggered before, start discovery now
            shouldStartDiscoveryWhenPowerStateTurnsOn
                ? startDiscovery()
                : ()
        default:
            // Invalidate all connections as bluetooth state is .PoweredOff or below
            deviceForPeripheral.values.forEach(invalidateDevice)
        }
    }

    @objc func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : AnyObject], rssi RSSI: NSNumber) {
        // Prevent devices from being discovered multiple times. iOS devices in peripheral role are also discovered multiple times.
        var device: BLEDevice?
        if let knownDevice = deviceForPeripheral[peripheral] {
            if detectUnreachableDevices {
                device = knownDevice
            }
        }
        else if let discoveredDevice = discovery.delegate?.bleDiscoveryManager(discovery, deviceWithPeripheral: peripheral, advertisementData: advertisementData) {
            deviceForPeripheral[peripheral] = discoveredDevice
            discovery.delegate?.bleDiscoveryManager(discovery, didDiscoverDevice: discoveredDevice)
            device = discoveredDevice
        }
        device?.didAdvertise(advertisementData, RSSI: RSSI, willReceiveSuccessiveAdvertisingData: detectUnreachableDevices)
    }

    func centralManager(_ central: CBCentralManager, didRestorePeripheral peripheral: CBPeripheral) {
        guard let device = discovery.delegate?.bleDiscoveryManager(discovery, deviceWithPeripheral: peripheral, advertisementData: nil) else { return }
        deviceForPeripheral[peripheral] = device
        device.didRestore()
        discovery.delegate?.bleDiscoveryManager(discovery, didRestoreDevice: device)
    }

    @objc func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let device = self.deviceForPeripheral[peripheral] else { return }
        device.didConnect()
    }

    @objc func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: NSError?) {
        guard let device = self.deviceForPeripheral[peripheral] else { return }
        device.didFailToConnect(error)
    }

    @objc func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        guard let device = self.deviceForPeripheral[peripheral] else { return }
        device.didDisconnect(error)
        invalidateDevice(device)
    }
}
