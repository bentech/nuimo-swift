//
//  NuimoGesture.swift
//  Nuimo
//
//  Created by Lars Blumberg on 9/23/15.
//  Copyright © 2015 Senic. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license.  See the LICENSE file for details.

@objc public enum NuimoGesture : Int {
    case
    undefined = 0, // TODO: Do we really need this enum value? We don't need to handle an "undefined" gesture
    buttonPress,
    buttonDoublePress,
    buttonRelease,
    rotate,
    touchLeftDown,
    touchLeftRelease,
    touchRightDown,
    touchRightRelease,
    touchTopDown,
    touchTopRelease,
    touchBottomDown,
    touchBottomRelease,
    swipeLeft,
    swipeRight,
    swipeUp,
    swipeDown,
    flyLeft,
    flyRight,
    flyBackwards,
    flyTowards,
    flyUpDown
    
    public init?(identifier: String) {
        guard let gesture = gestureForIdentifier[identifier] else { return nil }
        self = gesture
    }
    
    public var identifier: String { return identifierForGesture[self]! }
    
    // Returns the corresponding touch down gesture if self is a touch gesture, nil if not
    public var touchDownGesture: NuimoGesture? { return touchDownGestureForTouchGesture[self] }
    
    // Returns the corresponding touch up gesture if self is a touch gesture, nil if not
    public var touchReleaseGesture: NuimoGesture? { return touchReleaseGestureForTouchGesture[self] }
    
    // Returns the corresponding swipe gesture if self is a touch gesture, nil if not
    public var swipeGesture: NuimoGesture? { return swipeGestureForTouchGesture[self] }
}

public enum NuimoGestureError: ErrorProtocol {
    case invalidIdentifier
}

private let identifierForGesture: [NuimoGesture : String] = [
    .undefined          : "Undefined",
    .buttonPress        : "ButtonPress",
    .buttonRelease      : "ButtonRelease",
    .buttonDoublePress  : "ButtonDoublePress",
    .rotate             : "Rotate",
    .touchLeftDown      : "TouchLeftDown",
    .touchLeftRelease   : "TouchLeftRelease",
    .touchRightDown     : "TouchRightDown",
    .touchRightRelease  : "TouchRightRelease",
    .touchTopDown       : "TouchTopDown",
    .touchTopRelease    : "TouchTopRelease",
    .touchBottomDown    : "TouchBottomDown",
    .touchBottomRelease : "TouchBottomRelease",
    .swipeLeft          : "SwipeLeft",
    .swipeRight         : "SwipeRight",
    .swipeUp            : "SwipeUp",
    .swipeDown          : "SwipeDown",
    .flyLeft            : "FlyLeft",
    .flyRight           : "FlyRight",
    .flyBackwards       : "FlyBackwards",
    .flyTowards         : "FlyTowards",
    .flyUpDown          : "FlyUpDown"
]

private let gestureForIdentifier: [String : NuimoGesture] = {
    var dictionary = [String : NuimoGesture]()
    for (gesture, identifier) in identifierForGesture {
        dictionary[identifier] = gesture
    }
    return dictionary
}()

private let touchDownGestureForTouchGesture: [NuimoGesture : NuimoGesture] = [
    .touchLeftDown      : .touchLeftDown,
    .touchLeftRelease   : .touchLeftDown,
    .touchRightDown     : .touchRightDown,
    .touchRightRelease  : .touchRightDown,
    .touchTopDown       : .touchTopDown,
    .touchTopRelease    : .touchTopDown,
    .touchBottomDown    : .touchBottomDown,
    .touchBottomRelease : .touchBottomDown,
    .swipeLeft          : .touchLeftDown,
    .swipeRight         : .touchRightDown,
    .swipeUp            : .touchTopDown,
    .swipeDown          : .touchBottomDown,
]

private let touchReleaseGestureForTouchGesture: [NuimoGesture : NuimoGesture] = [
    .touchLeftDown      : .touchLeftRelease,
    .touchLeftRelease   : .touchLeftRelease,
    .touchRightDown     : .touchRightRelease,
    .touchRightRelease  : .touchRightRelease,
    .touchTopDown       : .touchTopRelease,
    .touchTopRelease    : .touchTopRelease,
    .touchBottomDown    : .touchBottomRelease,
    .touchBottomRelease : .touchBottomRelease,
    .swipeLeft          : .touchLeftRelease,
    .swipeRight         : .touchRightRelease,
    .swipeUp            : .touchTopRelease,
    .swipeDown          : .touchBottomRelease,
]

private let swipeGestureForTouchGesture: [NuimoGesture : NuimoGesture] = [
    .touchLeftDown      : .swipeLeft,
    .touchLeftRelease   : .swipeLeft,
    .touchRightDown     : .swipeRight,
    .touchRightRelease  : .swipeRight,
    .touchTopDown       : .swipeUp,
    .touchTopRelease    : .swipeUp,
    .touchBottomDown    : .swipeDown,
    .touchBottomRelease : .swipeDown,
    .swipeLeft          : .swipeLeft,
    .swipeRight         : .swipeRight,
    .swipeUp            : .swipeUp,
    .swipeDown          : .swipeDown,
]
