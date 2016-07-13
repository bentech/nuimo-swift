//
//  NuimoLEDMatrix.swift
//  Nuimo
//
//  Created by Lars Blumberg on 11/02/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

public let NuimoLEDMatrixLEDCount = 81
public let NuimoLEDMatrixLEDOffCharacters: [Character] = [" ", "0"]
public let NuimoLEDMatrixDefaultLEDOffCharacter = NuimoLEDMatrixLEDOffCharacters[0]
public let NuimoLEDMatrixDefaultLEDOnCharacter: Character = "."

public class NuimoLEDMatrix: NSObject {
    public let leds: [Bool]
    
    public init(matrix: NuimoLEDMatrix) {
        leds = matrix.leds
    }
    
    public init(string: String) {
        leds = string
            // Cut off after count of LEDs
            .substring(to: string.characters.index(string.startIndex, offsetBy: min(string.characters.count, NuimoLEDMatrixLEDCount)))
            // Right fill up to count of LEDs
            .padding(toLength: NuimoLEDMatrixLEDCount, withPad: " ", startingAt: 0)
            .characters
            .map{!NuimoLEDMatrixLEDOffCharacters.contains($0)}
    }
    
    //TODO: Have only one init(progress) method and pass presentation style as 2nd argument
    public convenience init(progressWithVerticalBar progress: Double) {
        let string = (0..<9)
            .reversed()
            .map{progress > Double($0) / 9.0 ? "   ...   " : "         "}
            .reduce("", combine: +)
        self.init(string: string)
    }
    
    public convenience init(progressWithVolumeBar progress: Double) {
        let width = Int(ceil(max(0.0, min(1.0, progress)) * 9))
        let string = (0..<9)
            .map{String(repeating: Character(" "), count: 9 - ($0 + 1)) + String(repeating: Character("."), count: $0 + 1)}
            .enumerated()
            .map{$0.element
                .substring(to: $0.element.characters.index($0.element.startIndex, offsetBy: width))
                .padding(toLength: 9, withPad: " ", startingAt: 0)}
            .reduce("", combine: +)
        self.init(string: string)
    }
}

public func ==(left: NuimoLEDMatrix, right: NuimoLEDMatrix) -> Bool {
    return left.leds == right.leds
}

public func ==(left: NuimoLEDMatrix?, right: NuimoLEDMatrix) -> Bool {
    guard let left = left else {return false}
    return left == right
}

public func ==(left: NuimoLEDMatrix, right: NuimoLEDMatrix?) -> Bool {
    guard let right = right else {return false}
    return left == right
}

public func ==(left: NuimoLEDMatrix?, right: NuimoLEDMatrix?) -> Bool {
    guard let left = left else {return right == nil}
    return left == right
}

public func !=(left: NuimoLEDMatrix, right: NuimoLEDMatrix) -> Bool {
    return !(left == right)
}

public func !=(left: NuimoLEDMatrix?, right: NuimoLEDMatrix) -> Bool {
    return !(left == right)
}

public func !=(left: NuimoLEDMatrix, right: NuimoLEDMatrix?) -> Bool {
    return !(left == right)
}

public func !=(left: NuimoLEDMatrix?, right: NuimoLEDMatrix?) -> Bool {
    return !(left == right)
}

//MARK: Predefined matrices

extension NuimoLEDMatrix {
    public static var emptyMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         " +
        "         ")}

    public static var musicNoteMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "  .....  " +
        "  .....  " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        " ..  ..  " +
        "... ...  " +
        " .   .   ")}
    
    public static var lightBulbMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "   ...   " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "   ...   " +
        "   ...   " +
        "   ...   " +
        "    .    ")}
    
    public static var powerOnMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "         " +
        "   ...   " +
        "  .....  " +
        "  .....  " +
        "  .....  " +
        "   ...   " +
        "         " +
        "         ")}
    
    public static var powerOffMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "         " +
        "   ...   " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "   ...   " +
        "         " +
        "         ")}
    
    public static var shuffleMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "         " +
        " ..   .. " +
        "   . .   " +
        "    .    " +
        "   . .   " +
        " ..   .. " +
        "         " +
        "         ")}
    
    public static var letterBMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "   ...   " +
        "   .  .  " +
        "   .  .  " +
        "   ...   " +
        "   .  .  " +
        "   .  .  " +
        "   ...   " +
        "         ")}
    
    public static var letterOMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "   ...   " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "  .   .  " +
        "   ...   " +
        "         ")}
    
    public static var letterGMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "   ...   " +
        "  .   .  " +
        "  .      " +
        "  . ...  " +
        "  .   .  " +
        "  .   .  " +
        "   ...   " +
        "         ")}
    
    public static var letterWMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        " .     . " +
        " .     . " +
        " .     . " +
        " .     . " +
        " .  .  . " +
        " .  .  . " +
        "  .. ..  " +
        "         ")}
    
    public static var letterYMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "  .   .  " +
        "  .   .  " +
        "   . .   " +
        "    .    " +
        "    .    " +
        "    .    " +
        "    .    " +
        "         ")}
    
    public static var playMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "   .     " +
        "   ..    " +
        "   ...   " +
        "   ....  " +
        "   ...   " +
        "   ..    " +
        "   .     " +
        "         ")}
    
    public static var pauseMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "  .. ..  " +
        "         ")}
    
    public static var nextMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "         " +
        "   .  .  " +
        "   .. .  " +
        "   ....  " +
        "   .. .  " +
        "   .  .  " +
        "         " +
        "         ")}
    
    public static var previousMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "         " +
        "         " +
        "  .  .   " +
        "  . ..   " +
        "  ....   " +
        "  . ..   " +
        "  .  .   " +
        "         " +
        "         ")}
    
    public static var questionMarkMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "   ...   " +
        "  .   .  " +
        " .     . " +
        "      .  " +
        "     .   " +
        "    .    " +
        "    .    " +
        "         " +
        "    .    ")}

    public static var bluetoothMatrix: NuimoLEDMatrix {return NuimoLEDMatrix(string:
        "    *    " +
        "    **   " +
        "  * * *  " +
        "   ***   " +
        "    *    " +
        "   ***   " +
        "  * * *  " +
        "    **   " +
        "    *    ")}
}

