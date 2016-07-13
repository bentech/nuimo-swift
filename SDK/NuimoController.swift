//
//  NuimoController.swift
//  Nuimo
//
//  Created by Lars Blumberg on 10/9/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

@objc public protocol NuimoController {
    var uuid: String {get}
    var delegate: NuimoControllerDelegate? {get set}

    var connectionState: NuimoConnectionState {get}
    /// Display interval in seconds
    var defaultMatrixDisplayInterval: TimeInterval {get set}
    /// Brightness 0..1 (1=max)
    var matrixBrightness: Float {get set}

    func connect() -> Bool

    func disconnect() -> Bool

    /// Writes an LED matrix for an interval with options (options is of type Int for compatibility with Objective-C)
    func writeMatrix(_ matrix: NuimoLEDMatrix, interval: TimeInterval, options: Int)
}

public extension NuimoController {
    /// Writes an LED matrix with options defaulting to ResendsSameMatrix and WithWriteResponse
    func writeMatrix(_ matrix: NuimoLEDMatrix, interval: TimeInterval) {
        writeMatrix(matrix, interval: interval, options: 0)
    }

    /// Writes an LED matrix using the default display interval and with options defaulting to ResendsSameMatrix and WithWriteResponse
    public func writeMatrix(_ matrix: NuimoLEDMatrix) {
        writeMatrix(matrix, interval: defaultMatrixDisplayInterval)
    }

    /// Writes an LED matrix for an interval and with options
    public func writeMatrix(_ matrix: NuimoLEDMatrix, interval: TimeInterval, options: NuimoLEDMatrixWriteOptions) {
        writeMatrix(matrix, interval: defaultMatrixDisplayInterval, options: options.rawValue)
    }

    /// Writes an LED matrix using the default display interval and with options defaulting to ResendsSameMatrix and WithWriteResponse
    public func writeMatrix(_ matrix: NuimoLEDMatrix, options: NuimoLEDMatrixWriteOptions) {
        writeMatrix(matrix, interval: defaultMatrixDisplayInterval, options: options)
    }
}

@objc public enum NuimoLEDMatrixWriteOption: Int {
    case ignoreDuplicates     = 1
    case withFadeTransition   = 2
    case withoutWriteResponse = 4
}

public struct NuimoLEDMatrixWriteOptions: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let IgnoreDuplicates     = NuimoLEDMatrixWriteOptions(rawValue: NuimoLEDMatrixWriteOption.ignoreDuplicates.rawValue)
    public static let WithFadeTransition   = NuimoLEDMatrixWriteOptions(rawValue: NuimoLEDMatrixWriteOption.withFadeTransition.rawValue)
    public static let WithoutWriteResponse = NuimoLEDMatrixWriteOptions(rawValue: NuimoLEDMatrixWriteOption.withoutWriteResponse.rawValue)
}

@objc public enum NuimoConnectionState: Int {
    case
    connecting,
    connected,
    disconnecting,
    disconnected,
    invalidated
}

@objc public protocol NuimoControllerDelegate {
    @objc optional func nuimoController(_ controller: NuimoController, didChangeConnectionState state: NuimoConnectionState, withError error: NSError?)
    @objc optional func nuimoController(_ controller: NuimoController, didReadFirmwareVersion firmwareVersion: String)
    @objc optional func nuimoController(_ controller: NuimoController, didUpdateBatteryLevel batteryLevel: Int)
    @objc optional func nuimoController(_ controller: NuimoController, didReceiveGestureEvent event: NuimoGestureEvent)
    @objc optional func nuimoControllerDidDisplayLEDMatrix(_ controller: NuimoController)
}
