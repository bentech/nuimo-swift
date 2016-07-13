//
//  BluetoothDevice.swift
//  Nuimo
//
//  Created by Lars Blumberg on 12/10/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

import Foundation
import CoreBluetooth

/**
    Represents a bluetooth low energy (BLE) device.
    - Automatically discovers its services when connected
    - Automatically discovers its characteristics
    - Automatically subscribes for characteristic change notifications
*/
public class BLEDevice: NSObject {
    /// Maximum interval between two advertising packages. If the OS doesn't receive a successive advertisement package after that interval the device is assumed to be unreachable and thus will invalidates. If not overridden, this interval defaults to `nil`, meaning that the device will never be assumed invalid, even in case the OS doesn't receive any more advertising packages.
    public class var maxAdvertisingPackageInterval: TimeInterval? { get { return nil } }
    /// Interval after that a connection attempt will be considered timed out. If a connection attempt times out, `didFailToConnect` will be called.
    public class var connectionTimeoutInterval: TimeInterval { return 5.0 }

    public let uuid: String
    public var serviceUUIDs: [CBUUID] { get { return [] } }
    public var charactericUUIDsForServiceUUID: [CBUUID : [CBUUID]] { get { return [:] } }
    public var notificationCharacteristicUUIDs: [CBUUID] { get { return [] } }
    public let peripheral: CBPeripheral
    public let centralManager: CBCentralManager
    public var reconnectsWhenFirstConnectionAttemptFails = false

    private var discoveryManager: BLEDiscoveryManager?
    private var advertisingTimeoutTimer: Timer?
    private var connectionTimeoutTimer: Timer?
    private var reconnectOnConnectionFailure = false

    /// Convenience initializer that takes a BLEDiscoveryManager instead of a CBCentralManager. This initializer allows to detect that the device has disappeared by checking if the OS didn't receive any more advertising packages.
    public convenience init(discoveryManager: BLEDiscoveryManager, uuid: String, peripheral: CBPeripheral) {
        self.init(centralManager: discoveryManager.centralManager, uuid: uuid, peripheral: peripheral)
        self.discoveryManager = discoveryManager
    }

    public required init(centralManager: CBCentralManager, uuid: String, peripheral: CBPeripheral) {
        self.centralManager = centralManager
        self.uuid = uuid
        self.peripheral = peripheral
        super.init()
    }

    public func didAdvertise(_ advertisementData: [String: AnyObject], RSSI: NSNumber, willReceiveSuccessiveAdvertisingData: Bool) {
        // Invalidate device if it stops advertising after a given interval of not sending any other advertising packages. Works only if `discoveryManager` known.
        advertisingTimeoutTimer?.invalidate()
        if let maxAdvertisingPackageInterval = self.dynamicType.maxAdvertisingPackageInterval where peripheral.state == .disconnected && willReceiveSuccessiveAdvertisingData {
            advertisingTimeoutTimer = Timer.scheduledTimer(timeInterval: maxAdvertisingPackageInterval, target: self, selector: #selector(didDisappear), userInfo: nil, repeats: false)
        }
    }

    public func didDisappear() {
        discoveryManager?.invalidateDevice(self)
    }

    public func connect() -> Bool {
        guard peripheral.state == .disconnected else { return false }
        advertisingTimeoutTimer?.invalidate()
        centralManager.connect(peripheral, options: nil)
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = Timer.scheduledTimer(timeInterval: self.dynamicType.connectionTimeoutInterval, target: self, selector: #selector(self.didConnectTimeout), userInfo: nil, repeats: false)
        reconnectOnConnectionFailure = reconnectsWhenFirstConnectionAttemptFails
        return true
    }

    public func didConnect() {
        connectionTimeoutTimer?.invalidate()
        peripheral.delegate = self
        peripheral.discoverServices(serviceUUIDs)
    }

    public func didConnectTimeout() {
        centralManager.cancelPeripheralConnection(peripheral)
        // CoreBluetooth doesn't call didFailToConnectPeripheral delegate method – that's why we call it here
        centralManager.delegate?.centralManager?(centralManager, didFailToConnect: peripheral, error: NSError(domain: "BLEDevice", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to connect to peripheral", NSLocalizedFailureReasonErrorKey: "Connection attempt timed out"]))
    }

    public func didFailToConnect(_ error: NSError?) {
        if reconnectsWhenFirstConnectionAttemptFails && reconnectOnConnectionFailure {
            connect()
            reconnectOnConnectionFailure = false
        }
    }

    public func didRestore() {
        //TODO: We might want to check first if re-discovering services is not necessary, this is when all services and characteristics and notification subscriptions are present
        peripheral.discoverServices(serviceUUIDs)
    }

    public func disconnect() -> Bool {
        guard peripheral.state == .connected else { return false }
        centralManager.cancelPeripheralConnection(peripheral)
        return true
    }

    public func didDisconnect(_ error: NSError?) {
    }

    @objc internal func invalidate() {
        advertisingTimeoutTimer?.invalidate()
        if peripheral.delegate === self {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        didInvalidate()
    }

    public func didInvalidate() {
    }
}

extension BLEDevice: CBPeripheralDelegate {
    @objc public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        peripheral.services?
            .flatMap{ ($0, charactericUUIDsForServiceUUID[$0.uuid]) }
            .forEach{ peripheral.discoverCharacteristics($0.1, for: $0.0) }
    }

    @objc public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: NSError?) {
        service.characteristics?.forEach{ characteristic in
            if notificationCharacteristicUUIDs.contains(characteristic.uuid) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    @objc public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: NSError?) {
    }

    @objc public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: NSError?) {
    }

    @objc public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: NSError?) {
    }
}
