//
//  Space.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 9/9/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

struct Space: Equatable {
    /// macOS 26 reports user desktop Spaces with type 4, while older releases used 0.
    static let macOS26UserSpaceTypeRawValue: UInt32 = 4

    let id: CGSSpaceID
    let type: CGSSpaceType
    let uuid: String

    /// `true` when the Space hosts a fullscreen window.
    ///
    /// The private Space dictionaries mark fullscreen Spaces with an `fs_wid`
    /// entry. The Space type alone is not reliable for this distinction:
    /// macOS 26 reports the main display's desktop as type 0 with an empty
    /// UUID while reporting fullscreen Spaces as type 4.
    let isFullscreen: Bool

    init(id: CGSSpaceID, type: CGSSpaceType, uuid: String, isFullscreen: Bool = false) {
        self.id = id
        self.type = type
        self.uuid = uuid
        self.isFullscreen = isFullscreen
    }

    var isUserSpace: Bool {
        if isFullscreen {
            return false
        }

        if type.rawValue == Space.macOS26UserSpaceTypeRawValue {
            return true
        }

        return type.rawValue == CGSSpaceTypeUser.rawValue
    }

    /// Whether a Space descriptor has no stable identifier.
    ///
    /// macOS 26 reports the main display's desktop with an empty UUID. Such a
    /// descriptor is a real desktop, so it must be tracked rather than ignored,
    /// but its persisted state needs a display-scoped key.
    var hasStableIdentifier: Bool {
        return !uuid.isEmpty
    }
}
