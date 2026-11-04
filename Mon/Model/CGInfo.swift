//
//  CGInfo.swift
//  Mon
//
//  Created by Ian Ynda-Hummel on 3/29/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import ApplicationServices
import Foundation
import Silica
import SwiftyJSON

struct EventPostingClient {
    let makeMouseEvent: (_ type: CGEventType, _ point: CGPoint) -> CGEvent?
    let postMouseEvent: (_ event: CGEvent) -> Void
}

extension EventPostingClient {
    static var cghid: EventPostingClient {
        return EventPostingClient(
            makeMouseEvent: { type, point in
                let event = CGEvent(
                    mouseEventSource: nil,
                    mouseType: type,
                    mouseCursorPosition: point,
                    mouseButton: .left
                )
                event?.flags = CGEventFlags(rawValue: 0)
                return event
            },
            postMouseEvent: { event in
                event.post(tap: .cghidEventTap)
            }
        )
    }
}

/// Windows info as taken from the underlying system.
struct CGWindowsInfo<Window: WindowType> {
    /// An array of dictionaries of window information
    let descriptions: [[String: AnyObject]]

    /**
     - Parameters:
     - options: Any options for getting info.
     - windowID: ID of window to find windows relative to. 0 gets all windows.
     */
    init?(options: CGWindowListOption, windowID: CGWindowID) {
        guard let cfWindowDescriptions = CGWindowListCopyWindowInfo(options, windowID) else {
            return nil
        }

        guard let windowDescriptions = cfWindowDescriptions as? [[String: AnyObject]] else {
            return nil
        }

        self.descriptions = windowDescriptions
    }

    /**
     - Returns:
     The set of windows that are currently active.
     */
    func activeIDs() -> Set<CGWindowID> {
        var ids: Set<CGWindowID> = Set()

        for windowDescription in descriptions {
            guard let windowID = windowDescription[kCGWindowNumber as String] as? NSNumber else {
                continue
            }

            ids.insert(CGWindowID(windowID.uint64Value))
        }

        return ids
    }

    static func windowIDsArray(_ window: Window) -> NSArray {
        return [NSNumber(value: window.cgID() as UInt32)] as NSArray
    }

    static func windowSpace(_ window: Window) -> Int? {
        let windowIDsArray = CGWindowsInfo.windowIDsArray(window)

        guard let cfSpaces = CGSCopySpacesForWindows(CGSMainConnectionID(), kCGSAllSpacesMask, windowIDsArray)?.takeRetainedValue() else {
            return nil
        }

        guard let spaces = cfSpaces as NSArray as? [NSNumber] else {
            return nil
        }

        guard !spaces.isEmpty else {
            return nil
        }

        return spaces.first?.intValue
    }
}

struct CGScreensInfo<Window: WindowType> {
    typealias Screen = Window.Screen

    let descriptions: [JSON]

    init?(screenTopologyClient: ScreenTopologyClient<Screen> = .system) {
        guard let descriptions = screenTopologyClient.screenDescriptions() else {
            return nil
        }

        self.descriptions = descriptions
    }

    func space(at index: Int) -> Space? {
        return CGSpacesInfo<Window>.space(fromScreenDescription: descriptions[index])
    }
}

struct ScreenTopologyClient<Screen: ScreenType> {
    let availableScreens: () -> [Screen]
    let screensHaveSeparateSpaces: () -> Bool
    let screenDescriptions: () -> [JSON]?
}

extension ScreenTopologyClient {
    static var system: ScreenTopologyClient<Screen> {
        return ScreenTopologyClient(
            availableScreens: { Screen.availableScreens },
            screensHaveSeparateSpaces: { Screen.screensHaveSeparateSpaces },
            screenDescriptions: { Screen.screenDescriptions() }
        )
    }
}

struct SpaceClient<Window: WindowType> {
    typealias Screen = Window.Screen

    let currentFocusedSpace: () -> Space?
    let spacesForAllScreens: (_ includeOnlyUserSpaces: Bool) -> [Space]?
    let currentSpaceForScreen: (_ screen: Screen) -> Space?
    let screenForSpace: (_ space: Space) -> Screen?
    let windowSpace: (_ window: Window) -> CGSSpaceID?
}

extension SpaceClient {
    static var cgs: SpaceClient<Window> {
        return SpaceClient<Window>(
            currentFocusedSpace: {
                CGSpacesInfo<Window>.currentFocusedSpace()
            },
            spacesForAllScreens: { includeOnlyUserSpaces in
                CGSpacesInfo<Window>.spacesForAllScreens(includeOnlyUserSpaces: includeOnlyUserSpaces)
            },
            currentSpaceForScreen: { screen in
                CGSpacesInfo<Window>.currentSpaceForScreen(screen)
            },
            screenForSpace: { space in
                CGSpacesInfo<Window>.screenForSpace(space: space)
            },
            windowSpace: { window in
                CGWindowsInfo<Window>.windowSpace(window)
            }
        )
    }

    static var unavailable: SpaceClient<Window> {
        return SpaceClient<Window>(
            currentFocusedSpace: { nil },
            spacesForAllScreens: { _ in nil },
            currentSpaceForScreen: { _ in nil },
            screenForSpace: { _ in nil },
            windowSpace: { _ in nil }
        )
    }
}

struct CGSpacesInfo<Window: WindowType> {
    typealias Screen = Window.Screen

    static func spacesForAllScreens(includeOnlyUserSpaces: Bool = false) -> [Space]? {
        guard let screenDescriptions = Screen.screenDescriptions() else {
            return nil
        }

        guard !screenDescriptions.isEmpty else {
            return nil
        }

        var spaces: [Space] = []
        for screenDescription in screenDescriptions {
            guard let screenSpaces = allSpaces(fromScreenDescription: screenDescription) else {
                return nil
            }
            spaces.append(contentsOf: screenSpaces)
        }

        if includeOnlyUserSpaces {
            return spaces.filter { $0.isUserSpace }
        }

        return spaces
    }

    static func spacesForScreen(_ screen: Screen, includeOnlyUserSpaces: Bool = false) -> [Space]? {
        guard let screenDescriptions = Screen.screenDescriptions() else {
            return nil
        }

        guard !screenDescriptions.isEmpty else {
            return nil
        }

        let screenID = screen.screenID()
        let spaces: [Space]?

        if Screen.screensHaveSeparateSpaces {
            spaces = screenDescriptions
                .first { $0["Display Identifier"].string == screenID }
                .flatMap { screenDescription -> [Space]? in
                    return allSpaces(fromScreenDescription: screenDescription)
                }
        } else {
            spaces = allSpaces(fromScreenDescription: screenDescriptions[0])
        }

        if includeOnlyUserSpaces {
            return spaces?.filter { $0.isUserSpace }
        }

        return spaces
    }

    static func spacesForFocusedScreen() -> [Space]? {
        guard let focusedWindow = Window.currentlyFocused(), let screen = focusedWindow.screen() else {
            return nil
        }

        return spacesForScreen(screen)
    }

    static func currentSpaceForScreen(_ screen: Screen) -> Space? {
        guard let screenDescriptions = Screen.screenDescriptions(), let screenID = screen.screenID() else {
            return nil
        }

        guard screenDescriptions.count > 0 else {
            return nil
        }

        if Screen.screensHaveSeparateSpaces {
            for screenDescription in screenDescriptions {
                guard screenDescription["Display Identifier"].string == screenID else {
                    continue
                }

                return space(fromScreenDescription: screenDescription)
            }
        } else {
            return space(fromScreenDescription: screenDescriptions[0])
        }

        return nil
    }

    static func currentFocusedSpace() -> Space? {
        guard let focusedWindow = Window.currentlyFocused(), let screen = focusedWindow.screen() else {
            return nil
        }

        return currentSpaceForScreen(screen)
    }

    static func screenForSpace(space: Space) -> Screen? {
        return Screen.availableScreens.first { spacesForScreen($0)?.contains { $0.id == space.id } ?? false }
    }

    /**
     The screen of the display that the Space with `id` belongs to.

     - Returns:
     The screen, or `nil` when no display lists the Space or when displays share their Spaces, since then a Space names no display.
     */
    static func screenForSpaceID(_ id: CGSSpaceID) -> Screen? {
        guard Screen.screensHaveSeparateSpaces, let screenDescriptions = Screen.screenDescriptions() else {
            return nil
        }

        let screenDescription = screenDescriptions.first { screenDescription in
            allSpaces(fromScreenDescription: screenDescription)?.contains { $0.id == id } ?? false
        }

        guard let screenID = screenDescription?["Display Identifier"].string else {
            return nil
        }

        return Screen.availableScreens.first { $0.screenID() == screenID }
    }

    static func space(fromScreenDescription screenDictionary: JSON) -> Space? {
        guard screenDictionary["Current Space"].exists() else {
            return nil
        }

        return space(fromSpaceDescription: screenDictionary["Current Space"])
    }

    static func space(fromSpaceDescription spaceDictionary: JSON) -> Space? {
        guard
            let id = spaceDictionary["ManagedSpaceID"].int,
            let typeRawValue = spaceDictionary["type"].uInt32,
            let uuid = spaceDictionary["uuid"].string
        else {
            return nil
        }

        let type = CGSSpaceType(rawValue: typeRawValue)
        let isFullscreen = spaceDictionary["fs_wid"].exists()
        return Space(id: id, type: type, uuid: uuid, isFullscreen: isFullscreen)
    }

    static func allSpaces(fromScreenDescription screenDictionary: JSON) -> [Space]? {
        guard let spaceDescriptions = screenDictionary["Spaces"].array else {
            return nil
        }

        var spaces: [Space] = []
        for spaceDescription in spaceDescriptions {
            guard let space = space(fromSpaceDescription: spaceDescription) else {
                return nil
            }
            spaces.append(space)
        }
        return spaces
    }
}

struct SpaceContractProbeResult: Equatable {
    let screenDescriptionsAvailable: Bool
    let spacesAvailable: Bool
    let userSpaceCount: Int
    let diagnostic: String?

    var isHealthy: Bool {
        return screenDescriptionsAvailable && spacesAvailable && userSpaceCount > 0
    }

    var description: String {
        guard isHealthy else {
            return "failed (\(diagnostic ?? "unknown reason"))"
        }

        return "ok (user Spaces: \(userSpaceCount))"
    }
}

enum SpaceContractProbe {
    static func run<Window: WindowType>(windowType: Window.Type) -> SpaceContractProbeResult {
        guard let screenDescriptions = Window.Screen.screenDescriptions(), !screenDescriptions.isEmpty else {
            return SpaceContractProbeResult(
                screenDescriptionsAvailable: false,
                spacesAvailable: false,
                userSpaceCount: 0,
                diagnostic: "screen descriptions unavailable"
            )
        }

        guard let spaces = CGSpacesInfo<Window>.spacesForAllScreens() else {
            return SpaceContractProbeResult(
                screenDescriptionsAvailable: true,
                spacesAvailable: false,
                userSpaceCount: 0,
                diagnostic: "Space dictionaries could not be decoded"
            )
        }

        let userSpaceCount = spaces.filter { $0.isUserSpace }.count
        if userSpaceCount == 0 {
            return SpaceContractProbeResult(
                screenDescriptionsAvailable: true,
                spacesAvailable: true,
                userSpaceCount: 0,
                diagnostic: "no user Spaces found"
            )
        }

        return SpaceContractProbeResult(
            screenDescriptionsAvailable: true,
            spacesAvailable: true,
            userSpaceCount: userSpaceCount,
            diagnostic: nil
        )
    }
}
