//
//  CGSpacesInfoTests.swift
//  MonTests
//
//  Created by Don Patterson on 10/16/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

@testable import Mon
import AppKit
import Foundation
import Nimble
import Quick
import Silica
import SwiftyJSON
import XCTest

private final class SpaceClientTestApplication: ApplicationType {
    typealias Window = TestWindow

    static func == (lhs: SpaceClientTestApplication, rhs: SpaceClientTestApplication) -> Bool {
        return lhs.pid() == rhs.pid()
    }

    init(runningApplication: NSRunningApplication) {}

    func title() -> String? {
        return nil
    }

    func windows() -> [TestWindow] {
        return []
    }

    func pid() -> pid_t {
        return 0
    }

    func defaultFloatForWindow(_ window: TestWindow) -> Reliable<DefaultFloat> {
        return .reliable(.notFloating)
    }

    func dropWindowsCache() {}

    func observe(notification: String, handler: @escaping SIAXNotificationHandler) -> AXError {
        return .success
    }

    func observe(notification: String, window: TestWindow, handler: @escaping SIAXNotificationHandler) -> AXError {
        return .success
    }

    func unobserve(notification: String) {}

    func unobserve(notification: String, window: TestWindow) {}
}

private final class SpaceClientTransitionTarget: WindowTransitionTarget {
    typealias Application = SpaceClientTestApplication

    var transitions: [WindowTransition<TestWindow>] = []
    var screens: [TestScreen] = []

    func executeTransition(_ transition: WindowTransition<TestWindow>) {
        transitions.append(transition)
    }

    func isWindowFloating(_ window: TestWindow) -> Bool {
        return false
    }

    func currentLayout() -> Layout<TestWindow>? {
        return nil
    }

    func screen(at index: Int) -> TestScreen? {
        guard index >= 0, index < screens.count else {
            return nil
        }
        return screens[index]
    }

    func activeWindows(on screen: TestScreen) -> [TestWindow] {
        return []
    }

    func nextScreenIndexClockwise(from screen: TestScreen) -> Int {
        return -1
    }

    func nextScreenIndexCounterClockwise(from screen: TestScreen) -> Int {
        return -1
    }

    func lastMainWindowForCurrentSpace() -> TestWindow? {
        return nil
    }
}

class CGSpacesInfoTests: QuickSpec {
    override func spec() {
        describe("user Space classification") {
            it("accepts the legacy user type with a UUID") {
                let space = Space(id: 1, type: CGSSpaceTypeUser, uuid: "space-1")

                expect(space.isUserSpace).to(beTrue())
            }

            it("accepts the legacy user type without a UUID") {
                let space = Space(id: 1, type: CGSSpaceTypeUser, uuid: "")

                expect(space.isUserSpace).to(beTrue())
                expect(space.hasStableIdentifier).to(beFalse())
            }

            it("rejects a fullscreen Space even when its type looks like a desktop") {
                let fullscreen = Space(id: 45, type: CGSSpaceType(rawValue: 4), uuid: "space-45", isFullscreen: true)

                expect(fullscreen.isUserSpace).to(beFalse())
            }

            it("accepts the macOS 26 user desktop type") {
                let space = Space(id: 222, type: CGSSpaceType(rawValue: 4), uuid: "space-222")

                expect(space.isUserSpace).to(beTrue())
            }

            it("rejects fullscreen and system Space types") {
                let fullscreen = Space(id: 2, type: CGSSpaceType(rawValue: 1), uuid: "space-2")
                let system = Space(id: 3, type: CGSSpaceType(rawValue: 2), uuid: "space-3")

                expect(fullscreen.isUserSpace).to(beFalse())
                expect(system.isUserSpace).to(beFalse())
            }
        }

        describe("screen topology client") {
            it("supplies display topology without calling system APIs") {
                let screen = TestScreen(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000))
                let descriptions = [JSON(["Display Identifier": screen.screenID()!])]
                let client = ScreenTopologyClient<TestScreen>(
                    availableScreens: { [screen] },
                    screensHaveSeparateSpaces: { false },
                    screenDescriptions: { descriptions }
                )

                expect(client.availableScreens()).to(equal([screen]))
                expect(client.screensHaveSeparateSpaces()).to(beFalse())
                expect(client.screenDescriptions()).to(equal(descriptions))
                expect(CGScreensInfo<TestWindow>(screenTopologyClient: client)?.descriptions).to(equal(descriptions))
            }
        }

        describe("active window Space degradation") {
            let screen = TestScreen(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000))

            func activeWindow() -> TestWindow {
                let window = TestWindow(element: nil)!
                window.screenValue = screen
                return window
            }

            it("keeps active windows executable for tiling when Space data is unavailable") {
                let windows = WindowManager<SpaceClientTestApplication>.Windows(spaceClient: .unavailable)
                let window = activeWindow()
                windows.add(window: window, atFront: false)
                let windowSet = windows.windowSet(forActiveWindowsOnScreen: screen)
                let layoutWindow = try! XCTUnwrap(windowSet.windows.first)
                let assignment = FrameAssignment(
                    frame: CGRect(x: 10, y: 20, width: 300, height: 200),
                    window: layoutWindow,
                    screenFrame: screen.adjustedFrame(),
                    resizeRules: ResizeRules(isMain: true, unconstrainedDimension: .horizontal, scaleFactor: 1)
                )

                windowSet.perform(frameAssignment: assignment)

                expect(windows.activeWindows(onScreen: screen)).to(equal([window]))
                expect(window.frame()).to(equal(CGRect(x: 10, y: 20, width: 300, height: 200)))
            }

            it("continues to filter a known current Space precisely") {
                let currentSpace = Space(id: 1, type: CGSSpaceTypeUser, uuid: "current-space")
                let client = SpaceClient<TestWindow>(
                    currentFocusedSpace: { currentSpace },
                    spacesForAllScreens: { _ in [currentSpace] },
                    currentSpaceForScreen: { _ in currentSpace },
                    spacesForScreen: { _, _ in [currentSpace] },
                    screenForSpace: { _ in screen },
                    windowSpace: { _ in 2 }
                )
                let windows = WindowManager<SpaceClientTestApplication>.Windows(spaceClient: client)
                let window = activeWindow()
                windows.add(window: window, atFront: false)

                expect(windows.activeWindows(onScreen: screen)).to(beEmpty())
            }
        }

        describe("event posting client") {
            it("routes event construction and posting through injected closures") {
                var requestedType: CGEventType?
                var requestedPoint: CGPoint?
                var postedEvent = false
                let event = CGEvent(
                    mouseEventSource: nil,
                    mouseType: .mouseMoved,
                    mouseCursorPosition: .zero,
                    mouseButton: .left
                )!
                let client = EventPostingClient(
                    makeMouseEvent: { type, point in
                        requestedType = type
                        requestedPoint = point
                        return event
                    },
                    postMouseEvent: { posted in
                        postedEvent = posted === event
                    }
                )

                let created = client.makeMouseEvent(.mouseMoved, CGPoint(x: 10, y: 20))
                client.postMouseEvent(created!)

                expect(requestedType).to(equal(.mouseMoved))
                expect(requestedPoint).to(equal(CGPoint(x: 10, y: 20)))
                expect(postedEvent).to(beTrue())
            }
        }

        describe("Space contract probe") {
            let screen = TestScreen(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000))

            afterEach {
                TestScreen.descriptions = []
                TestScreen.availableScreens = []
            }

            it("reports healthy when screen and Space dictionaries decode") {
                TestScreen.availableScreens = [screen]
                TestScreen.descriptions = [
                    JSON([
                        "Display Identifier": screen.screenID()!,
                        "Current Space": ["ManagedSpaceID": 11, "type": 0, "uuid": "space-11"],
                        "Spaces": [
                            ["ManagedSpaceID": 11, "type": 0, "uuid": "space-11"],
                            ["ManagedSpaceID": 12, "type": 0, "uuid": "space-12"]
                        ]
                    ])
                ]

                let result = SpaceContractProbe.run(windowType: TestWindow.self)

                expect(result.isHealthy).to(beTrue())
                expect(result.userSpaceCount).to(equal(2))
                expect(result.description).to(contain("ok"))
            }

            it("reports unavailable screen descriptions") {
                let result = SpaceContractProbe.run(windowType: TestWindow.self)

                expect(result.screenDescriptionsAvailable).to(beFalse())
                expect(result.isHealthy).to(beFalse())
                expect(result.description).to(contain("screen descriptions unavailable"))
            }

            it("reports undecodable Space dictionaries") {
                TestScreen.availableScreens = [screen]
                TestScreen.descriptions = [
                    JSON([
                        "Display Identifier": screen.screenID()!,
                        "Current Space": ["ManagedSpaceID": 11, "type": 0, "uuid": "space-11"],
                        "Spaces": [["ManagedSpaceID": 12, "type": 0]]
                    ])
                ]

                let result = SpaceContractProbe.run(windowType: TestWindow.self)

                expect(result.spacesAvailable).to(beFalse())
                expect(result.isHealthy).to(beFalse())
                expect(result.description).to(contain("could not be decoded"))
            }

            it("reports when no user Spaces exist") {
                TestScreen.availableScreens = [screen]
                TestScreen.descriptions = [
                    JSON([
                        "Display Identifier": screen.screenID()!,
                        "Current Space": ["ManagedSpaceID": 21, "type": 1, "uuid": "space-21"],
                        "Spaces": [["ManagedSpaceID": 21, "type": 1, "uuid": "space-21"]]
                    ])
                ]

                let result = SpaceContractProbe.run(windowType: TestWindow.self)

                expect(result.spacesAvailable).to(beTrue())
                expect(result.userSpaceCount).to(equal(0))
                expect(result.isHealthy).to(beFalse())
                expect(result.description).to(contain("no user Spaces found"))
            }
        }

        describe("the screen for a Space") {
            let first = TestScreen(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000))
            let second = TestScreen(frame: CGRect(x: 1000, y: 0, width: 1000, height: 1000))

            func description(of screen: TestScreen, spaces: [Int]) -> JSON {
                return JSON([
                    "Display Identifier": screen.screenID()!,
                    "Current Space": ["ManagedSpaceID": spaces[0], "type": 0, "uuid": "space-\(spaces[0])"],
                    "Spaces": spaces.map { ["ManagedSpaceID": $0, "type": 0, "uuid": "space-\($0)"] }
                ])
            }

            beforeEach {
                TestScreen.screensHaveSeparateSpaces = true
                TestScreen.availableScreens = [first, second]
                TestScreen.descriptions = [description(of: first, spaces: [11, 12]), description(of: second, spaces: [21, 22])]
            }

            afterEach {
                TestScreen.screensHaveSeparateSpaces = true
                TestScreen.availableScreens = []
                TestScreen.descriptions = []
            }

            it("is the screen of the display that lists the Space") {
                expect(CGSpacesInfo<TestWindow>.screenForSpaceID(12)).to(equal(first))
                expect(CGSpacesInfo<TestWindow>.screenForSpaceID(21)).to(equal(second))
            }

            it("is unknown for a Space no display lists") {
                expect(CGSpacesInfo<TestWindow>.screenForSpaceID(99)).to(beNil())
            }

            it("is unknown when displays share their Spaces") {
                TestScreen.screensHaveSeparateSpaces = false
                expect(CGSpacesInfo<TestWindow>.screenForSpaceID(12)).to(beNil())
            }

            it("does not decode a Space without a managed identifier") {
                let space = CGSpacesInfo<TestWindow>.space(fromSpaceDescription: JSON(["type": 0, "uuid": "missing-id"]))

                expect(space).to(beNil())
            }

            it("does not decode a Space without a type") {
                let space = CGSpacesInfo<TestWindow>.space(fromSpaceDescription: JSON(["ManagedSpaceID": 12, "uuid": "missing-type"]))

                expect(space).to(beNil())
            }

            it("does not decode a Space without a UUID") {
                let space = CGSpacesInfo<TestWindow>.space(fromSpaceDescription: JSON(["ManagedSpaceID": 12, "type": 0]))

                expect(space).to(beNil())
            }

            it("does not invent a current Space when the screen description is missing it") {
                let description = JSON(["Display Identifier": first.screenID()!])

                expect(CGSpacesInfo<TestWindow>.space(fromScreenDescription: description)).to(beNil())
            }

            it("does not report all Spaces when a Space dictionary is malformed") {
                TestScreen.descriptions = [
                    JSON([
                        "Display Identifier": first.screenID()!,
                        "Current Space": ["ManagedSpaceID": 11, "type": 0, "uuid": "space-11"],
                        "Spaces": [
                            ["ManagedSpaceID": 11, "type": 0, "uuid": "space-11"],
                            ["ManagedSpaceID": 12, "type": 0]
                        ]
                    ])
                ]

                expect(CGSpacesInfo<TestWindow>.spacesForAllScreens()).to(beNil())
            }

            it("keeps core window add distribution enabled when Space lookup is unavailable") {
                expect(shouldDistributeWindowAdd(windowSpace: nil, currentSpaceID: 11)).to(beTrue())
                expect(shouldDistributeWindowAdd(windowSpace: 11, currentSpaceID: nil)).to(beTrue())
                expect(shouldDistributeWindowAdd(windowSpace: nil, currentSpaceID: nil)).to(beTrue())
            }

            it("skips window add distribution only when both Space IDs are known and different") {
                expect(shouldDistributeWindowAdd(windowSpace: 11, currentSpaceID: 11)).to(beTrue())
                expect(shouldDistributeWindowAdd(windowSpace: 12, currentSpaceID: 11)).to(beFalse())
            }
        }

        describe("Space client command degradation") {
            let screen = TestScreen(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000))
            let currentSpace = Space(id: 11, type: CGSSpaceTypeUser, uuid: "space-11")
            let targetSpace = Space(id: 12, type: CGSSpaceTypeUser, uuid: "space-12")
            var window: TestWindow!
            var target: SpaceClientTransitionTarget!

            beforeEach {
                window = TestWindow(element: nil)
                window.screenValue = screen
                TestWindow.focused = window
                TestScreen.availableScreens = [screen]
                target = SpaceClientTransitionTarget()
                target.screens = [screen]
            }

            afterEach {
                TestWindow.focused = nil
                TestScreen.availableScreens = []
            }

            it("does not execute a throw-to-space command when Space APIs are unavailable") {
                let coordinator = WindowTransitionCoordinator<SpaceClientTransitionTarget>(spaceClient: .unavailable)
                coordinator.target = target

                let result = coordinator.pushFocusedWindowToSpace(1)

                expect(result).to(equal(.disabled(.spaceInformationUnavailable)))
                expect(target.transitions).to(beEmpty())
            }

            it("reports unavailable Space command availability with a status title") {
                let coordinator = WindowTransitionCoordinator<SpaceClientTransitionTarget>(spaceClient: .unavailable)
                let availability = coordinator.spaceCommandAvailability()

                expect(availability).to(equal(.disabled(.spaceInformationUnavailable)))
                expect(availability.statusTitle).to(contain("Space commands disabled"))
                expect(availability.isAvailable).to(beFalse())
            }

            it("does not report Space inventory failure when no window is focused") {
                TestWindow.focused = nil
                let spaceClient = SpaceClient<TestWindow>(
                    currentFocusedSpace: { nil },
                    spacesForAllScreens: { _ in [currentSpace, targetSpace] },
                    currentSpaceForScreen: { _ in currentSpace },
                    spacesForScreen: { _, _ in [currentSpace] },
                    screenForSpace: { _ in screen },
                    windowSpace: { _ in currentSpace.id }
                )
                let coordinator = WindowTransitionCoordinator<SpaceClientTransitionTarget>(spaceClient: spaceClient)

                let availability = coordinator.spaceCommandAvailability()

                expect(availability).to(equal(.available))
                expect(availability.statusTitle).to(beNil())
            }

            it("reports available Space command availability without a status title") {
                let spaceClient = SpaceClient<TestWindow>(
                    currentFocusedSpace: { currentSpace },
                    spacesForAllScreens: { _ in [currentSpace, targetSpace] },
                    currentSpaceForScreen: { _ in currentSpace },
                    spacesForScreen: { _, _ in [currentSpace] },
                    screenForSpace: { _ in screen },
                    windowSpace: { _ in currentSpace.id }
                )
                let coordinator = WindowTransitionCoordinator<SpaceClientTransitionTarget>(spaceClient: spaceClient)
                let availability = coordinator.spaceCommandAvailability()

                expect(availability).to(equal(.available))
                expect(availability.statusTitle).to(beNil())
                expect(availability.isAvailable).to(beTrue())
            }

            it("executes a throw-to-space command when Space APIs provide a valid source and target") {
                let spaceClient = SpaceClient<TestWindow>(
                    currentFocusedSpace: { currentSpace },
                    spacesForAllScreens: { _ in [currentSpace, targetSpace] },
                    currentSpaceForScreen: { _ in currentSpace },
                    spacesForScreen: { _, _ in [currentSpace] },
                    screenForSpace: { _ in screen },
                    windowSpace: { _ in currentSpace.id }
                )
                let coordinator = WindowTransitionCoordinator<SpaceClientTransitionTarget>(spaceClient: spaceClient)
                coordinator.target = target

                coordinator.pushFocusedWindowToSpace(1)

                expect(target.transitions.count).to(equal(1))
                guard case let .moveWindowToSpaceAtIndex(movedWindow, spaceIndex, sourceSpaceIndex) = target.transitions.first else {
                    fail("Expected moveWindowToSpaceAtIndex")
                    return
                }
                expect(movedWindow).to(equal(window))
                expect(spaceIndex).to(equal(1))
                expect(sourceSpaceIndex).to(equal(0))
            }

            it("does not execute a throw-to-space command when the target Space index is out of range") {
                let spaceClient = SpaceClient<TestWindow>(
                    currentFocusedSpace: { currentSpace },
                    spacesForAllScreens: { _ in [currentSpace, targetSpace] },
                    currentSpaceForScreen: { _ in currentSpace },
                    spacesForScreen: { _, _ in [currentSpace] },
                    screenForSpace: { _ in screen },
                    windowSpace: { _ in currentSpace.id }
                )
                let coordinator = WindowTransitionCoordinator<SpaceClientTransitionTarget>(spaceClient: spaceClient)
                coordinator.target = target

                let result = coordinator.pushFocusedWindowToSpace(2)

                expect(result).to(equal(.disabled(.targetSpaceOutOfRange)))
                expect(target.transitions).to(beEmpty())
            }

            it("does not execute a throw-to-space command when no focused window is available") {
                TestWindow.focused = nil
                let coordinator = WindowTransitionCoordinator<SpaceClientTransitionTarget>(spaceClient: .unavailable)
                coordinator.target = target

                let result = coordinator.pushFocusedWindowToSpace(1, sourceSpace: 0)

                expect(result).to(equal(.disabled(.noFocusedWindow)))
                expect(target.transitions).to(beEmpty())
            }

            it("does not execute a throw-to-space command when the focused window has no screen") {
                window.screenValue = nil
                let coordinator = WindowTransitionCoordinator<SpaceClientTransitionTarget>(spaceClient: .unavailable)
                coordinator.target = target

                let result = coordinator.pushFocusedWindowToSpace(1, sourceSpace: 0)

                expect(result).to(equal(.disabled(.focusedWindowHasNoScreen)))
                expect(target.transitions).to(beEmpty())
            }

            it("provides readable Space command disabled reasons") {
                expect(SpaceCommandFailureReason.spaceInformationUnavailable.description).to(equal("Space information is unavailable"))
                expect(SpaceCommandFailureReason.targetSpaceOutOfRange.description).to(equal("Target Space index is out of range"))
            }

            it("reports unavailable Space movement without moving the window") {
                let result = SpaceMoveClient<TestWindow>.unavailable.moveWindow(
                    window,
                    toSpaceAtIndex: 1,
                    sourceSpaceIndex: 0,
                    followWindow: false
                )

                expect(result).to(equal(.failed(.unavailable)))
                expect(window.movedToSpaceIndexes).to(beEmpty())
            }

            it("passes target, source, and follow-window state through custom Space movement clients") {
                var requestedSpaceIndex: Int?
                var requestedSourceSpaceIndex: Int?
                var requestedFollowWindow: Bool?
                let client = SpaceMoveClient<TestWindow> { movedWindow, spaceIndex, sourceSpaceIndex, followWindow in
                    movedWindow.move(toSpaceAtIndex: UInt(spaceIndex + 1))
                    requestedSpaceIndex = spaceIndex
                    requestedSourceSpaceIndex = sourceSpaceIndex
                    requestedFollowWindow = followWindow
                    return .moved
                }

                let result = client.moveWindow(window, toSpaceAtIndex: 2, sourceSpaceIndex: 1, followWindow: true)

                expect(result).to(equal(.moved))
                expect(window.movedToSpaceIndexes).to(equal([3]))
                expect(requestedSpaceIndex).to(equal(2))
                expect(requestedSourceSpaceIndex).to(equal(1))
                expect(requestedFollowWindow).to(beTrue())
            }

            it("posts mouse up exactly once after the scheduled Space switch") {
                var postedMouseEvents: [SpaceDragMouseEventKind] = []
                var switchedSpaces: [UInt] = []
                var scheduledBlocks: [(TimeInterval, () -> Void)] = []
                let eventClient = SpaceDragEventClient(
                    isSecureInputEnabled: { false },
                    makeMouseEvent: { kind, point in
                        return CGEvent(
                            mouseEventSource: nil,
                            mouseType: kind.eventType,
                            mouseCursorPosition: point,
                            mouseButton: .left
                        )
                    },
                    postMouseEvent: { kind, _ in
                        postedMouseEvents.append(kind)
                    },
                    switchToSpace: { space in
                        switchedSpaces.append(space)
                    }
                )
                let scheduler = SpaceDragScheduler { delay, block in
                    scheduledBlocks.append((delay, block))
                }
                let transaction = SpaceDragTransaction(
                    eventClient: eventClient,
                    scheduler: scheduler,
                    grabDelay: 0.1,
                    releaseDelay: 0.2,
                    cleanupTimeout: 1.0
                )

                let result = transaction.moveWindow(from: CGPoint(x: 10, y: 20), toSpaceAtIndex: 2)

                expect(result).to(equal(.moved))
                expect(postedMouseEvents).to(equal([.move, .down, .drag]))
                expect(scheduledBlocks.map { $0.0 }).to(equal([1.0, 0.1]))

                scheduledBlocks[1].1()
                expect(switchedSpaces).to(equal([3]))
                expect(scheduledBlocks.map { $0.0 }).to(equal([1.0, 0.1, 0.2]))

                scheduledBlocks[2].1()
                scheduledBlocks[0].1()
                expect(postedMouseEvents).to(equal([.move, .down, .drag, .release]))
            }

            it("posts mouse up from the failsafe timeout if the Space switch path does not release") {
                var postedMouseEvents: [SpaceDragMouseEventKind] = []
                var scheduledBlocks: [(TimeInterval, () -> Void)] = []
                let eventClient = SpaceDragEventClient(
                    isSecureInputEnabled: { false },
                    makeMouseEvent: { kind, point in
                        return CGEvent(
                            mouseEventSource: nil,
                            mouseType: kind.eventType,
                            mouseCursorPosition: point,
                            mouseButton: .left
                        )
                    },
                    postMouseEvent: { kind, _ in
                        postedMouseEvents.append(kind)
                    },
                    switchToSpace: { _ in }
                )
                let scheduler = SpaceDragScheduler { delay, block in
                    scheduledBlocks.append((delay, block))
                }
                let transaction = SpaceDragTransaction(
                    eventClient: eventClient,
                    scheduler: scheduler,
                    grabDelay: 0.1,
                    releaseDelay: 0.2,
                    cleanupTimeout: 1.0
                )

                expect(transaction.moveWindow(from: CGPoint(x: 10, y: 20), toSpaceAtIndex: 2)).to(equal(.moved))

                scheduledBlocks[0].1()
                expect(postedMouseEvents).to(equal([.move, .down, .drag, .release]))

                scheduledBlocks[1].1()
                scheduledBlocks[2].1()
                expect(postedMouseEvents).to(equal([.move, .down, .drag, .release]))
            }

            it("does not start a drag when mouse-up cleanup cannot be created") {
                var postedMouseEvents: [SpaceDragMouseEventKind] = []
                let eventClient = SpaceDragEventClient(
                    isSecureInputEnabled: { false },
                    makeMouseEvent: { kind, point in
                        guard kind != .release else {
                            return nil
                        }
                        return CGEvent(
                            mouseEventSource: nil,
                            mouseType: kind.eventType,
                            mouseCursorPosition: point,
                            mouseButton: .left
                        )
                    },
                    postMouseEvent: { kind, _ in
                        postedMouseEvents.append(kind)
                    },
                    switchToSpace: { _ in }
                )
                let transaction = SpaceDragTransaction(
                    eventClient: eventClient,
                    scheduler: SpaceDragScheduler { _, _ in }
                )

                let result = transaction.moveWindow(from: CGPoint(x: 10, y: 20), toSpaceAtIndex: 2)

                expect(result).to(equal(.failed(.eventCreationFailed)))
                expect(postedMouseEvents).to(beEmpty())
            }

            it("does not create or post drag events while Secure Input is enabled") {
                var createdMouseEvents: [SpaceDragMouseEventKind] = []
                var postedMouseEvents: [SpaceDragMouseEventKind] = []
                var scheduledBlocks: [(TimeInterval, () -> Void)] = []
                let eventClient = SpaceDragEventClient(
                    isSecureInputEnabled: { true },
                    makeMouseEvent: { kind, point in
                        createdMouseEvents.append(kind)
                        return CGEvent(
                            mouseEventSource: nil,
                            mouseType: kind.eventType,
                            mouseCursorPosition: point,
                            mouseButton: .left
                        )
                    },
                    postMouseEvent: { kind, _ in
                        postedMouseEvents.append(kind)
                    },
                    switchToSpace: { _ in }
                )
                let transaction = SpaceDragTransaction(
                    eventClient: eventClient,
                    scheduler: SpaceDragScheduler { delay, block in
                        scheduledBlocks.append((delay, block))
                    }
                )

                let result = transaction.moveWindow(from: CGPoint(x: 10, y: 20), toSpaceAtIndex: 2)

                expect(result).to(equal(.failed(.secureInputEnabled)))
                expect(createdMouseEvents).to(beEmpty())
                expect(postedMouseEvents).to(beEmpty())
                expect(scheduledBlocks).to(beEmpty())
            }
        }

        describe("the screen containing a frame") {
            let first = TestScreen(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000))
            let second = TestScreen(frame: CGRect(x: 1000, y: 0, width: 1000, height: 1000))

            beforeEach {
                TestScreen.availableScreens = [first, second]
            }

            afterEach {
                TestScreen.availableScreens = []
            }

            it("is the screen whose display holds the whole frame") {
                expect(TestScreen.screen(containing: CGRect(x: 100, y: 100, width: 200, height: 200))).to(equal(first))
                expect(TestScreen.screen(containing: CGRect(x: 1200, y: 100, width: 100, height: 100))).to(equal(second))
            }

            it("is unknown for a frame straddling two displays") {
                expect(TestScreen.screen(containing: CGRect(x: 900, y: 100, width: 200, height: 200))).to(beNil())
            }

            it("is unknown for a frame outside every display or with no frame at all") {
                expect(TestScreen.screen(containing: CGRect(x: 5000, y: 100, width: 100, height: 100))).to(beNil())
                expect(TestScreen.screen(containing: CGRect.null)).to(beNil())
            }
        }
    }
}
