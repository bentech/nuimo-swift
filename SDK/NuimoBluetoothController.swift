//
//  NuimoController.swift
//  Nuimo
//
//  Created by Lars Blumberg on 9/23/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

import CoreBluetooth

// Represents a bluetooth low energy (BLE) Nuimo controller
//TODO: Internalize CBPeripheralDelegate implementation
public class NuimoBluetoothController: BLEDevice, NuimoController {
    public override class var connectionTimeoutInterval: TimeInterval { return 5.0 }
    public override class var maxAdvertisingPackageInterval: TimeInterval? { return 5.0 }

    public var delegate: NuimoControllerDelegate?
    public private(set) dynamic var connectionState = NuimoConnectionState.disconnected
    public var defaultMatrixDisplayInterval: TimeInterval = 2.0
    public var matrixBrightness: Float = 1.0 { didSet { matrixWriter?.brightness = self.matrixBrightness } }

    public override var serviceUUIDs: [CBUUID] { get { return nuimoServiceUUIDs } }
    public override var charactericUUIDsForServiceUUID: [CBUUID : [CBUUID]] { get { return nuimoCharactericUUIDsForServiceUUID } }
    public override var notificationCharacteristicUUIDs: [CBUUID] { get { return nuimoNotificationCharacteristicnUUIDs } }

    private var matrixWriter: LEDMatrixWriter?
    private var connectTimeoutTimer: Timer?

    public required init(centralManager: CBCentralManager, uuid: String, peripheral: CBPeripheral) {
        super.init(centralManager: centralManager, uuid: uuid, peripheral: peripheral)
        reconnectsWhenFirstConnectionAttemptFails = true
    }

    public override func connect() -> Bool {
        guard super.connect() else { return false }
        setConnectionState(.connecting)
        return true
    }

    public override func didConnect() {
        matrixWriter = nil
        super.didConnect()
        //TODO: When the matrix characteristic is being found, didConnect() is fired. But if matrix characteristic is not found, didFailToConnect() should be fired instead!
    }

    public override func didFailToConnect(_ error: NSError?) {
        super.didFailToConnect(error)
        setConnectionState(.disconnected, withError: error)
    }

    public override func disconnect() -> Bool {
        guard super.disconnect() else { return false }
        setConnectionState(.disconnecting)
        return true
    }

    public override func didDisconnect(_ error: NSError?) {
        super.didDisconnect(error)
        matrixWriter = nil
        setConnectionState(.disconnected, withError: error)
    }

    public override func didInvalidate() {
        super.didInvalidate()
        setConnectionState(.invalidated)
    }

    private func setConnectionState(_ state: NuimoConnectionState, withError error: NSError? = nil) {
        guard state != connectionState else { return }
        connectionState = state
        delegate?.nuimoController?(self, didChangeConnectionState: connectionState, withError: error)
    }

    //TODO: Rename to displayMatrix
    public func writeMatrix(_ matrix: NuimoLEDMatrix, interval: TimeInterval, options: Int) {
        matrixWriter?.writeMatrix(matrix, interval: interval, options: options)
    }
}

extension NuimoBluetoothController /* CBPeripheralDelegate */ {
    public override func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: NSError?) {
        super.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: error)
        service.characteristics?.forEach{ characteristic in
            switch characteristic.uuid {
            case kFirmwareVersionCharacteristicUUID:
                peripheral.readValue(for: characteristic)
            case kBatteryCharacteristicUUID:
                peripheral.readValue(for: characteristic)
            case kLEDMatrixCharacteristicUUID:
                matrixWriter = LEDMatrixWriter(peripheral: peripheral, matrixCharacteristic: characteristic, brightness: matrixBrightness)
                setConnectionState(.connected)
            default:
                break
            }
        }
    }

    public override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: NSError?) {
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)

        guard let data = characteristic.value else { return }

        switch characteristic.uuid {
        case kFirmwareVersionCharacteristicUUID:
            if let firmwareVersion = String(data: data, encoding: String.Encoding.utf8) {
                delegate?.nuimoController?(self, didReadFirmwareVersion: firmwareVersion)
            }
        case kBatteryCharacteristicUUID:
            delegate?.nuimoController?(self, didUpdateBatteryLevel: Int(UnsafePointer<UInt8>((data as NSData).bytes).pointee))
        default:
            if let event = characteristic.nuimoGestureEvent() {
                delegate?.nuimoController?(self, didReceiveGestureEvent: event)
            }
        }
    }

    public override func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: NSError?) {
        super.peripheral(peripheral, didWriteValueFor: characteristic, error: error)
        if characteristic.uuid == kLEDMatrixCharacteristicUUID {
            matrixWriter?.didRetrieveMatrixWriteResponse()
            delegate?.nuimoControllerDidDisplayLEDMatrix?(self)
        }
    }
}

//MARK: - LED matrix writing

private class LEDMatrixWriter {
    let peripheral: CBPeripheral
    let matrixCharacteristic: CBCharacteristic
    var brightness: Float

    private var currentMatrix: NuimoLEDMatrix?
    private var currentMatrixDisplayInterval: TimeInterval = 0.0
    private var currentMatrixWithFadeTransition = false
    private var lastWrittenMatrix: NuimoLEDMatrix?
    private var lastWrittenMatrixDate = Date(timeIntervalSince1970: 0.0)
    private var lastWrittenMatrixDisplayInterval: TimeInterval = 0.0
    private var isWaitingForMatrixWriteResponse = false
    private var writeMatrixOnWriteResponseReceived = false
    private var writeMatrixResponseTimeoutTimer: Timer?

    init(peripheral: CBPeripheral, matrixCharacteristic: CBCharacteristic, brightness: Float) {
        self.peripheral = peripheral
        self.matrixCharacteristic = matrixCharacteristic
        self.brightness = brightness
    }

    func writeMatrix(_ matrix: NuimoLEDMatrix, interval: TimeInterval, options: Int) {
        let resendsSameMatrix  = options & NuimoLEDMatrixWriteOption.ignoreDuplicates.rawValue     == 0
        let withFadeTransition = options & NuimoLEDMatrixWriteOption.withFadeTransition.rawValue   != 0
        let withWriteResponse  = options & NuimoLEDMatrixWriteOption.withoutWriteResponse.rawValue == 0

        guard
            resendsSameMatrix ||
            lastWrittenMatrix != matrix ||
            (lastWrittenMatrixDisplayInterval > 0 && -lastWrittenMatrixDate.timeIntervalSinceNow >= lastWrittenMatrixDisplayInterval)
            else { return }

        currentMatrix                   = matrix
        currentMatrixDisplayInterval    = interval
        currentMatrixWithFadeTransition = withFadeTransition

        if withWriteResponse && isWaitingForMatrixWriteResponse {
            writeMatrixOnWriteResponseReceived = true
        }
        else {
            writeMatrixNow(withWriteResponse)
        }
    }

    private func writeMatrixNow(_ withWriteResponse: Bool) {
        guard var matrixBytes = currentMatrix?.matrixBytes where matrixBytes.count == 11 && !(withWriteResponse && isWaitingForMatrixWriteResponse) else { fatalError("Invalid matrix write request") }

        matrixBytes[10] = matrixBytes[10] + (currentMatrixWithFadeTransition ? UInt8(1 << 4) : 0)
        matrixBytes += [UInt8(min(max(brightness, 0.0), 1.0) * 255), UInt8(currentMatrixDisplayInterval * 10.0)]
        peripheral.writeValue(Data(bytes: UnsafePointer<UInt8>(matrixBytes), count: matrixBytes.count), for: matrixCharacteristic, type: withWriteResponse ? .withResponse : .withoutResponse)

        isWaitingForMatrixWriteResponse  = withWriteResponse
        lastWrittenMatrix                = currentMatrix
        lastWrittenMatrixDate            = Date()
        lastWrittenMatrixDisplayInterval = currentMatrixDisplayInterval

        if withWriteResponse {
            // When the matrix write response is not retrieved within 500ms we assume the response to have timed out
            DispatchQueue.main.async {
                self.writeMatrixResponseTimeoutTimer?.invalidate()
                self.writeMatrixResponseTimeoutTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.didRetrieveMatrixWriteResponse), userInfo: nil, repeats: false)
            }
        }
    }

    @objc func didRetrieveMatrixWriteResponse() {
        guard isWaitingForMatrixWriteResponse else { return }
        isWaitingForMatrixWriteResponse = false
        DispatchQueue.main.async {
            self.writeMatrixResponseTimeoutTimer?.invalidate()
        }

        // Write next matrix if any
        if writeMatrixOnWriteResponseReceived {
            writeMatrixOnWriteResponseReceived = false
            writeMatrixNow(true)
        }
    }
}

//MARK: Nuimo BLE GATT service and characteristic UUIDs

private let kBatteryServiceUUID                  = CBUUID(string: "180F")
private let kBatteryCharacteristicUUID           = CBUUID(string: "2A19")
private let kDeviceInformationServiceUUID        = CBUUID(string: "180A")
private let kFirmwareVersionCharacteristicUUID   = CBUUID(string: "2A26")
private let kLEDMatrixServiceUUID                = CBUUID(string: "F29B1523-CB19-40F3-BE5C-7241ECB82FD1")
private let kLEDMatrixCharacteristicUUID         = CBUUID(string: "F29B1524-CB19-40F3-BE5C-7241ECB82FD1")
private let kSensorServiceUUID                   = CBUUID(string: "F29B1525-CB19-40F3-BE5C-7241ECB82FD2")
private let kSensorFlyCharacteristicUUID         = CBUUID(string: "F29B1526-CB19-40F3-BE5C-7241ECB82FD2")
private let kSensorTouchCharacteristicUUID       = CBUUID(string: "F29B1527-CB19-40F3-BE5C-7241ECB82FD2")
private let kSensorRotationCharacteristicUUID    = CBUUID(string: "F29B1528-CB19-40F3-BE5C-7241ECB82FD2")
private let kSensorButtonCharacteristicUUID      = CBUUID(string: "F29B1529-CB19-40F3-BE5C-7241ECB82FD2")

internal let nuimoServiceUUIDs: [CBUUID] = [
    kBatteryServiceUUID,
    kDeviceInformationServiceUUID,
    kLEDMatrixServiceUUID,
    kSensorServiceUUID
]

private let nuimoCharactericUUIDsForServiceUUID = [
    kBatteryServiceUUID: [kBatteryCharacteristicUUID],
    kDeviceInformationServiceUUID: [kFirmwareVersionCharacteristicUUID],
    kLEDMatrixServiceUUID: [kLEDMatrixCharacteristicUUID],
    kSensorServiceUUID: [
        kSensorFlyCharacteristicUUID,
        kSensorTouchCharacteristicUUID,
        kSensorRotationCharacteristicUUID,
        kSensorButtonCharacteristicUUID
    ]
]

private let nuimoNotificationCharacteristicnUUIDs = [
    kBatteryCharacteristicUUID,
    kSensorFlyCharacteristicUUID,
    kSensorTouchCharacteristicUUID,
    kSensorRotationCharacteristicUUID,
    kSensorButtonCharacteristicUUID
]

//MARK: - Private extensions

//MARK: Initializers for NuimoGestureEvents from BLE GATT data

private extension NuimoGestureEvent {
    convenience init(gattFlyData data: Data) {
        let bytes = UnsafePointer<UInt8>((data as NSData).bytes)
        let directionByte = bytes.pointee
        let speedByte = bytes.advanced(by: 1).pointee
        print("direction byte: \(directionByte)")
        print("speed byte: \(speedByte)")
        //TODO: When firmware bug is fixed fallback to .Undefined gesture
        let gesture: NuimoGesture = [0 : .flyLeft, 1 : .flyRight, 2 : .flyBackwards, 3 : .flyTowards, 4 : .flyUpDown][directionByte] ?? .flyRight //.Undefined
        self.init(gesture: gesture, value: gesture == .flyUpDown ? Int(speedByte) : nil)
    }

    convenience init(gattTouchData data: Data) {
        let bytes = UnsafePointer<UInt8>((data as NSData).bytes)
        let gesture: NuimoGesture = {
            if data.count == 1 {
                return [0 : .swipeLeft, 1 : .swipeRight, 2 : .swipeUp, 3 : .swipeDown][bytes.pointee] ?? .undefined
            }
            else {
                //TODO: This is for the previous firmware version. Remove when we have no devices anymore running the old firmware.
                let bytes = UnsafePointer<Int16>((data as NSData).bytes)
                let buttonByte = bytes.pointee
                let eventByte = bytes.advanced(by: 1).pointee
                for i: Int16 in 0...7 where (1 << i) & buttonByte != 0 {
                    let touchDownGesture: NuimoGesture = [.touchLeftDown, .touchTopDown, .touchRightDown, .touchBottomDown][Int(i / 2)]
                    if let eventGesture: NuimoGesture = {
                            switch eventByte {
                            case 1:  return touchDownGesture.self
                            case 2:  return touchDownGesture.touchReleaseGesture //TODO: Move this method here as a private extension method
                            case 3:  return nil //TODO: Do we need to handle double touch gestures here as well?
                            case 4:  return touchDownGesture.swipeGesture
                            default: return nil}}() {
                        return eventGesture
                    }
                }
                return .undefined
            }
        }()

        self.init(gesture: gesture, value: nil)
    }

    convenience init(gattRotationData data: Data) {
        let value = Int(UnsafePointer<Int16>((data as NSData).bytes).pointee)
        self.init(gesture: .rotate, value: value)
    }

    convenience init(gattButtonData data: Data) {
        let value = Int(UnsafePointer<UInt8>((data as NSData).bytes).pointee)
        //TODO: Evaluate double press events
        self.init(gesture: value == 1 ? .buttonPress : .buttonRelease, value: value)
    }
}

//MARK: Matrix string to byte array conversion

private extension NuimoLEDMatrix {
    var matrixBytes: [UInt8] {
        return leds
            .chunk(8)
            .map{ $0
                .enumerated()
                .map{(i: Int, b: Bool) -> Int in return b ? 1 << i : 0}
                .reduce(UInt8(0), combine: {(s: UInt8, v: Int) -> UInt8 in s + UInt8(v)})
        }
    }
}

private extension Sequence {
    func chunk(_ n: Int) -> [[Iterator.Element]] {
        var chunks: [[Iterator.Element]] = []
        var chunk: [Iterator.Element] = []
        chunk.reserveCapacity(n)
        chunks.reserveCapacity(underestimatedCount / n)
        var i = n
        self.forEach {
            chunk.append($0)
            i -= 1
            if i == 0 {
                chunks.append(chunk)
                chunk.removeAll(keepingCapacity: true)
                i = n
            }
        }
        if !chunk.isEmpty { chunks.append(chunk) }
        return chunks
    }
}

//MARK: Extension methods for CoreBluetooth

private extension CBCharacteristic {
    func nuimoGestureEvent() -> NuimoGestureEvent? {
        guard let data = value else { return nil }

        switch uuid {
        case kSensorFlyCharacteristicUUID:      return NuimoGestureEvent(gattFlyData: data)
        case kSensorTouchCharacteristicUUID:    return NuimoGestureEvent(gattTouchData: data)
        case kSensorRotationCharacteristicUUID: return NuimoGestureEvent(gattRotationData: data)
        case kSensorButtonCharacteristicUUID:   return NuimoGestureEvent(gattButtonData: data)
        default: return nil
        }
    }
}
