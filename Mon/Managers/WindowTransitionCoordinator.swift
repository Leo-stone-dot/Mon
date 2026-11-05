//
//  WindowTransitionCoordinator.swift
//  Mon
//
//  Created by Ian Ynda-Hummel on 3/24/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import Foundation
import Silica

enum WindowTransition<Window: WindowType> {
    typealias Screen = Window.Screen
    case switchWindows(_ window1: Window, _ window2: Window)
    case moveWindowToScreen(_ window: Window, screen: Screen)
    case moveWindowToSpaceAtIndex(_ window: Window, spaceIndex: Int, sourceSpaceIndex: Int)
    case resetFocus
}

enum SpaceCommandFailureReason: Equatable, CustomStringConvertible {
    case spaceInformationUnavailable
    case currentSpaceNotFound
    case targetSpaceOutOfRange
    case noFocusedWindow
    case focusedWindowHasNoScreen
    case noUserSpaceInDirection

    var description: String {
        switch self {
        case .spaceInformationUnavailable:
            return "Space information is unavailable"
        case .currentSpaceNotFound:
            return "Current Space is not listed in the available Spaces"
        case .targetSpaceOutOfRange:
            return "Target Space index is out of range"
        case .noFocusedWindow:
            return "No focused window is available"
        case .focusedWindowHasNoScreen:
            return "Focused window has no screen"
        case .noUserSpaceInDirection:
            return "No user Space exists in the requested direction"
        }
    }
}

enum SpaceCommandResult: Equatable {
    case executed
    case disabled(SpaceCommandFailureReason)

    var succeeded: Bool {
        switch self {
        case .executed:
            return true
        case .disabled:
            return false
        }
    }
}

enum SpaceCommandAvailability: Equatable {
    case available
    case disabled(SpaceCommandFailureReason)

    var isAvailable: Bool {
        switch self {
        case .available:
            return true
        case .disabled:
            return false
        }
    }

    var statusTitle: String? {
        switch self {
        case .available:
            return nil
        case let .disabled(reason):
            return "Space commands disabled: \(reason.description)"
        }
    }
}

protocol WindowTransitionTarget: AnyObject {
    associatedtype Application: ApplicationType
    typealias Window = Application.Window
    typealias Screen = Window.Screen

    func executeTransition(_ transition: WindowTransition<Window>)

    func isWindowFloating(_ window: Window) -> Bool
    func currentLayout() -> Layout<Application.Window>?
    func screen(at index: Int) -> Screen?
    func activeWindows(on screen: Screen) -> [Window]
    func nextScreenIndexClockwise(from screen: Screen) -> Int
    func nextScreenIndexCounterClockwise(from screen: Screen) -> Int
    func lastMainWindowForCurrentSpace() -> Window?
}

class WindowTransitionCoordinator<Target: WindowTransitionTarget> {
    typealias Window = Target.Window
    typealias Screen = Window.Screen

    weak var target: Target?
    private let spaceClient: SpaceClient<Window>

    init(spaceClient: SpaceClient<Window> = .cgs) {
        self.spaceClient = spaceClient
    }

    func swapFocusedWindowToMain() {
        guard let focusedWindow = Window.currentlyFocused(), target?.isWindowFloating(focusedWindow) == false, let screen = focusedWindow.screen() else {
            return
        }

        guard let windows = target?.activeWindows(on: screen), let focusedIndex = windows.firstIndex(of: focusedWindow) else {
            return
        }

        if windows.count <= 1 {
            return
        }

        if focusedIndex == 0 {
            guard let lastMainWindow = target?.lastMainWindowForCurrentSpace() else {
                return
            }
            target?.executeTransition(.switchWindows(lastMainWindow, focusedWindow))
            return
        }

        if focusedIndex != 0 {
            // Swap focused window with main window if other window is focused
            target?.executeTransition(.switchWindows(focusedWindow, windows[0]))
        }
    }

    func swapFocusedWindowCounterClockwise() {
        guard let focusedWindow = Window.currentlyFocused(), target?.isWindowFloating(focusedWindow) == false else {
            target?.executeTransition(.resetFocus)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let windows = target?.activeWindows(on: screen), let focusedWindowIndex = windows.firstIndex(of: focusedWindow) else {
            return
        }

        let windowToSwapWith = windows[(focusedWindowIndex == 0 ? windows.count - 1 : focusedWindowIndex - 1)]

        target?.executeTransition(.switchWindows(focusedWindow, windowToSwapWith))
    }

    func swapFocusedWindowClockwise() {
        guard let focusedWindow = Window.currentlyFocused(), target?.isWindowFloating(focusedWindow) == false else {
            target?.executeTransition(.resetFocus)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let windows = target?.activeWindows(on: screen), let focusedWindowIndex = windows.firstIndex(of: focusedWindow) else {
            return
        }

        let windowToSwapWith = windows[(focusedWindowIndex + 1) % windows.count]

        target?.executeTransition(.switchWindows(focusedWindow, windowToSwapWith))
    }

    func throwToScreenAtIndex(_ screenIndex: Int) {
        guard let screen = target?.screen(at: screenIndex), let focusedWindow = Window.currentlyFocused() else {
            return
        }

        // If the window is already on the screen do nothing.
        guard let focusedScreen = focusedWindow.screen(), focusedScreen.screenID() != screen.screenID() else {
            return
        }

        target?.executeTransition(.moveWindowToScreen(focusedWindow, screen: screen))
    }

    func swapFocusedWindowScreenClockwise() {
        guard let focusedWindow = Window.currentlyFocused(), target?.isWindowFloating(focusedWindow) == false else {
            target?.executeTransition(.resetFocus)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let nextScreenIndex = target?.nextScreenIndexClockwise(from: screen), let nextScreen = target?.screen(at: nextScreenIndex) else {
            return
        }

        target?.executeTransition(.moveWindowToScreen(focusedWindow, screen: nextScreen))
    }

    func swapFocusedWindowScreenCounterClockwise() {
        guard let focusedWindow = Window.currentlyFocused(), target?.isWindowFloating(focusedWindow) == false else {
            target?.executeTransition(.resetFocus)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let nextScreenIndex = target?.nextScreenIndexCounterClockwise(from: screen), let nextScreen = target?.screen(at: nextScreenIndex) else {
            return
        }

        target?.executeTransition(.moveWindowToScreen(focusedWindow, screen: nextScreen))
    }

    func spaceCommandAvailability() -> SpaceCommandAvailability {
        guard let spaces = spaceClient.spacesForAllScreens(false), !spaces.isEmpty else {
            return .disabled(.spaceInformationUnavailable)
        }

        // A focused window is an execution-time requirement, not a property of
        // the Space inventory. With no focused window the next command may still
        // succeed as soon as a window gains focus, so do not show a persistent
        // "Space information unavailable" status item.
        guard let currentFocusedSpace = spaceClient.currentFocusedSpace() else {
            return .available
        }

        guard spaces.contains(currentFocusedSpace) else {
            return .disabled(.currentSpaceNotFound)
        }

        return .available
    }

    @discardableResult
    func pushFocusedWindowToSpace(_ space: Int) -> SpaceCommandResult {
        guard let currentFocusedSpace = spaceClient.currentFocusedSpace(), let spaces = spaceClient.spacesForAllScreens(false) else {
            return disableSpaceCommand(.spaceInformationUnavailable)
        }

        guard let index = spaces.firstIndex(of: currentFocusedSpace), index < spaces.count else {
            return disableSpaceCommand(.currentSpaceNotFound)
        }

        guard space >= 0, space < spaces.count else {
            return disableSpaceCommand(.targetSpaceOutOfRange)
        }

        return pushFocusedWindowToSpace(space, sourceSpace: index)
    }

    @discardableResult
    func pushFocusedWindowToSpace(_ space: Int, sourceSpace: Int) -> SpaceCommandResult {
        guard let focusedWindow = Window.currentlyFocused() else {
            return disableSpaceCommand(.noFocusedWindow)
        }

        guard focusedWindow.screen() != nil else {
            return disableSpaceCommand(.focusedWindowHasNoScreen)
        }

        target?.executeTransition(.moveWindowToSpaceAtIndex(focusedWindow, spaceIndex: space, sourceSpaceIndex: sourceSpace))
        return .executed
    }

    @discardableResult
    func pushFocusedWindowToSpaceLeft() -> SpaceCommandResult {
        guard let currentFocusedSpace = spaceClient.currentFocusedSpace(), let spaces = spaceClient.spacesForAllScreens(false) else {
            return disableSpaceCommand(.spaceInformationUnavailable)
        }

        let filteredSpaces = spaces.filter { $0.isUserSpace }
        guard let index = filteredSpaces.firstIndex(of: currentFocusedSpace), index > 0 else {
            return disableSpaceCommand(.noUserSpaceInDirection)
        }

        return pushFocusedWindowToSpace(index - 1, sourceSpace: index)
    }

    @discardableResult
    func pushFocusedWindowToSpaceRight() -> SpaceCommandResult {
        guard let currentFocusedSpace = spaceClient.currentFocusedSpace(), let spaces = spaceClient.spacesForAllScreens(false) else {
            return disableSpaceCommand(.spaceInformationUnavailable)
        }

        let filteredSpaces = spaces.filter { $0.isUserSpace }
        guard let index = filteredSpaces.firstIndex(of: currentFocusedSpace), index + 1 < filteredSpaces.count else {
            return disableSpaceCommand(.noUserSpaceInDirection)
        }

        return pushFocusedWindowToSpace(index + 1, sourceSpace: index)
    }

    private func disableSpaceCommand(_ reason: SpaceCommandFailureReason) -> SpaceCommandResult {
        logSpaceCommandDisabled(reason)
        return .disabled(reason)
    }

    private func logSpaceCommandDisabled(_ reason: SpaceCommandFailureReason) {
        log.warning("Space command disabled: \(reason.description)")
    }
}
