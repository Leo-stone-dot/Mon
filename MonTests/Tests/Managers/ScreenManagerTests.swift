//
//  ScreenManagerTests.swift
//  MonTests
//
//  Created by Ian Ynda-Hummel on 2/11/20.
//  Copyright © 2020 Ian Ynda-Hummel. All rights reserved.
//

@testable import Mon
import Nimble
import Quick
import Silica
import XCTest

private final class TestDelegate: ScreenManagerDelegate {
    typealias Window = TestWindow
    private(set) var persistentStateChangeCount = 0

    func applyWindowLimit(forScreenManager screenManager: ScreenManager<TestDelegate>, minimizingIn range: (Int) -> Range<Int>) {
        fatalError()
    }
    func activeWindowSet(forScreenManager screenManager: ScreenManager<TestDelegate>, on screen: TestScreen) -> WindowSet<TestWindow> {
        fatalError()
    }
    func onReflowInitiation() {
        fatalError()
    }
    func onReflowCompletion() {
        fatalError()
    }

    func screenManagerPersistentStateDidChange(_ screenManager: ScreenManager<TestDelegate>) {
        persistentStateChangeCount += 1
    }
}

class ScreenManagerTests: QuickSpec {
    override func spec() {
        describe("layout catalog coding") {
            it("always exposes every built-in layout in a unique stable order") {
                let keys = LayoutType<TestWindow>.standardLayoutClasses().map { $0.layoutKey }

                expect(keys.count).to(equal(17))
                expect(Set(keys).count).to(equal(keys.count))
                expect(keys.first).to(equal(TallLayout<TestWindow>.layoutKey))
                expect(keys.last).to(equal(BinarySpacePartitioningLayout<TestWindow>.layoutKey))
            }

            it("appends valid custom layouts in stable key order and rejects invalid ones") {
                let directory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("mon-layout-catalog-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: directory) }
                let script = #"function layout(){return{name:"Valid",initialState:{},getFrameAssignments:function(){return {}}}}"#
                try script.write(to: directory.appendingPathComponent("zeta.js"), atomically: true, encoding: .utf8)
                try script.write(to: directory.appendingPathComponent("alpha.js"), atomically: true, encoding: .utf8)
                try #"function layout(){return{name:"Invalid"}}"#
                    .write(to: directory.appendingPathComponent("broken.js"), atomically: true, encoding: .utf8)
                let missingExtension = #"function layout(){return{name:"Missing",extends:"absent",initialState:{},getFrameAssignments:function(){return {}}}}"#
                try missingExtension.write(
                    to: directory.appendingPathComponent("missing-extension.js"),
                    atomically: true,
                    encoding: .utf8
                )
                let cycleA = #"function layout(){return{name:"Cycle A",extends:"cycle-b",initialState:{},getFrameAssignments:function(){return {}}}}"#
                let cycleB = #"function layout(){return{name:"Cycle B",extends:"cycle-a",initialState:{},getFrameAssignments:function(){return {}}}}"#
                try cycleA.write(to: directory.appendingPathComponent("cycle-a.js"), atomically: true, encoding: .utf8)
                try cycleB.write(to: directory.appendingPathComponent("cycle-b.js"), atomically: true, encoding: .utf8)

                let keys = LayoutType<TestWindow>.availableLayouts(layoutsDirectory: directory).map { $0.layoutKey }

                expect(Array(keys.suffix(2))).to(equal(["alpha", "zeta"]))
                expect(keys).toNot(contain("broken"))
                expect(keys).toNot(contain("missing-extension"))
                expect(keys).toNot(contain("cycle-a"))
                expect(keys).toNot(contain("cycle-b"))
            }

            it("keeps every available layout in deterministic order while restoring state") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                let tall = TallLayout<TestWindow>()
                tall.increaseMainPaneCount()
                let encodedLayouts = [
                    ["key": TallLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! JSONEncoder().encode(tall)]
                ]
                let available: [Layout<TestWindow>] = [
                    TallLayout<TestWindow>(),
                    WideLayout<TestWindow>(),
                    FullscreenLayout<TestWindow>()
                ]

                let decoded = try! ScreenManager<TestDelegate>.decodedLayouts(
                    from: encodedLayouts,
                    userConfiguration: configuration,
                    availableLayouts: available
                )

                expect(decoded.map { $0.layoutKey }).to(equal(["tall", "wide", "fullscreen"]))
                expect((decoded.first as? TallLayout<TestWindow>)?.mainPaneCount).to(equal(2))
            }

            it("uses a fresh layout when encoded state is invalid") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                let encodedLayouts = [[
                    "key": TallLayout<TestWindow>.layoutKey.data(using: .utf8)!,
                    "data": try! JSONEncoder().encode(["incorrect": "encoding"])
                ]]
                let available: [Layout<TestWindow>] = [TallLayout<TestWindow>(), WideLayout<TestWindow>()]

                let decoded = try! ScreenManager<TestDelegate>.decodedLayouts(
                    from: encodedLayouts,
                    userConfiguration: configuration,
                    availableLayouts: available
                )

                expect(decoded.map { $0.layoutKey }).to(equal(["tall", "wide"]))
                expect((decoded.first as? TallLayout<TestWindow>)?.mainPaneCount).to(equal(1))
            }
        }

        describe("restoring screen and Space layouts") {
            let space1 = Space(id: 1, type: CGSSpaceTypeUser, uuid: "space-1")
            let space2 = Space(id: 2, type: CGSSpaceTypeUser, uuid: "space-2")

            func configuration(_ keys: [String] = []) -> UserConfiguration {
                _ = keys
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.tilingEnabled = false
                return configuration
            }

            func testLayouts() -> [Layout<TestWindow>] {
                return [TallLayout(), WideLayout(), FullscreenLayout(), ColumnLayout()]
            }

            func manager(_ configuration: UserConfiguration) -> ScreenManager<TestDelegate> {
                let manager = ScreenManager(
                    screen: TestScreen(),
                    delegate: TestDelegate(),
                    userConfiguration: configuration,
                    layoutProvider: testLayouts
                )
                manager.updateSpace(to: space1)
                return manager
            }

            func decoder(_ configuration: UserConfiguration) -> JSONDecoder {
                let decoder = JSONDecoder()
                decoder.userInfo[.screenManagerConfiguration] = configuration
                decoder.userInfo[.screenManagerLayoutProvider] = testLayouts as () -> [Layout<TestWindow>]
                return decoder
            }

            it("restores independent choices and pane state for two screens sharing Space UUIDs") { @MainActor in
                let configuration = configuration(["tall", "wide", "fullscreen"])
                let first = manager(configuration)
                let second = manager(configuration)
                first.selectLayout("wide")
                (first.currentLayout as? WideLayout<TestWindow>)?.increaseMainPaneCount()
                first.updateSpace(to: space2)
                first.selectLayout("fullscreen")
                second.updateSpace(to: space2)
                second.selectLayout("wide")

                // Screens persists managers in a dictionary keyed by display identifier.
                let data = try JSONEncoder().encode(["display-1": first, "display-2": second])
                let restored = try decoder(configuration).decode([String: ScreenManager<TestDelegate>].self, from: data)
                let restoredFirst = try XCTUnwrap(restored["display-1"])
                let restoredSecond = try XCTUnwrap(restored["display-2"])

                restoredFirst.updateSpace(to: space1)
                restoredSecond.updateSpace(to: space1)
                expect(restoredFirst.currentLayout?.layoutKey).to(equal("wide"))
                expect((restoredFirst.currentLayout as? WideLayout<TestWindow>)?.mainPaneCount).to(equal(2))
                expect(restoredSecond.currentLayout?.layoutKey).to(equal("tall"))

                restoredFirst.updateSpace(to: space2)
                restoredSecond.updateSpace(to: space2)
                expect(restoredFirst.currentLayout?.layoutKey).to(equal("fullscreen"))
                expect(restoredSecond.currentLayout?.layoutKey).to(equal("wide"))
            }

            it("reads legacy state that has no saved selection") { @MainActor in
                let configuration = configuration(["wide", "tall"])
                let data = try JSONEncoder().encode(manager(configuration))
                var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
                json.removeValue(forKey: "currentLayoutIndexBySpaceUUID")
                let legacyData = try JSONSerialization.data(withJSONObject: json)
                let restored = try decoder(configuration).decode(ScreenManager<TestDelegate>.self, from: legacyData)

                restored.updateSpace(to: space1)
                expect(restored.currentLayout?.layoutKey).to(equal("tall"))
            }

            it("falls back for invalid indices instead of inheriting the previous Space selection") { @MainActor in
                let configuration = configuration(["tall", "wide"])
                let original = manager(configuration)
                original.updateSpace(to: space2)
                original.selectLayout("wide")
                let data = try JSONEncoder().encode(original)

                for invalidIndex in [-1, 99] {
                    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
                    json["currentLayoutIndexBySpaceUUID"] = ["space-1": invalidIndex, "space-2": 1]
                    let invalidData = try JSONSerialization.data(withJSONObject: json)
                    let restored = try decoder(configuration).decode(ScreenManager<TestDelegate>.self, from: invalidData)
                    restored.updateSpace(to: space2)
                    restored.selectLayout("wide")
                    restored.updateSpace(to: space1)
                    expect(restored.currentLayout?.layoutKey).to(equal("tall"))
                }
            }

            it("uses a display default outside the former global layout list") { @MainActor in
                let configuration = configuration(["tall", "wide"])
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                configuration.setDisplayDefaults(
                    DisplayDefaults(tilingEnabled: true, layoutKey: "row"),
                    forDisplayID: screen.screenID()!
                )
                let screenManager = ScreenManager(
                    screen: screen,
                    delegate: TestDelegate(),
                    userConfiguration: configuration,
                    spaceClient: .unavailable,
                    layoutProvider: {
                        [TallLayout<TestWindow>(), RowLayout<TestWindow>(), WideLayout<TestWindow>()]
                    }
                )

                screenManager.updateSpace(to: space1)

                expect(screenManager.currentLayout?.layoutKey).to(equal("row"))
                expect(screenManager.currentSpaceTilingEnabled).to(beTrue())
            }

            it("tracks a Space without a UUID with a display-scoped key") { @MainActor in
                let configuration = configuration(["tall", "wide"])
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                let screenManager = ScreenManager(
                    screen: screen,
                    delegate: TestDelegate(),
                    userConfiguration: configuration
                )
                let uuidlessSpace = Space(id: 1, type: CGSSpaceTypeUser, uuid: "")

                screenManager.updateSpace(to: uuidlessSpace)
                screenManager.selectLayout("wide")
                screenManager.updateSpace(to: space1)
                screenManager.updateSpace(to: uuidlessSpace)

                expect(screenManager.currentLayout?.layoutKey).to(equal("wide"))
                expect(screenManager.currentSpaceTilingEnabled).to(beFalse())
            }

            it("persists a selected layout for a Space without a UUID under its display key") { @MainActor in
                let configuration = configuration(["tall", "wide"])
                let screen = TestScreen()
                let screenManager = ScreenManager(
                    screen: screen,
                    delegate: TestDelegate(),
                    userConfiguration: configuration
                )

                screenManager.updateSpace(to: Space(id: 1, type: CGSSpaceTypeUser, uuid: ""))
                screenManager.selectLayout("wide")

                let data = try JSONEncoder().encode(screenManager)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let indices = json?["currentLayoutIndexBySpaceUUID"] as? [String: Int]
                let wideIndex = LayoutType<TestWindow>.standardLayoutClasses()
                    .firstIndex { $0.layoutKey == WideLayout<TestWindow>.layoutKey }
                expect(indices?["display:\(screen.screenID()!)"]).to(equal(wideIndex))
            }

            it("enables tiling when a layout is selected for a desktop") { @MainActor in
                let configuration = configuration(["tall", "wide"])
                let screenManager = ScreenManager(
                    screen: TestScreen(),
                    delegate: TestDelegate(),
                    userConfiguration: configuration
                )

                screenManager.updateSpace(to: space1)
                expect(screenManager.currentSpaceTilingEnabled).to(beFalse())

                screenManager.setLayout("wide", for: space1)

                expect(screenManager.currentSpaceTilingEnabled).to(beTrue())
                expect(screenManager.currentLayout?.layoutKey).to(equal("wide"))
            }

            it("configures a desktop that is not currently tracked") { @MainActor in
                let configuration = configuration(["tall", "wide"])
                let screenManager = ScreenManager(
                    screen: TestScreen(),
                    delegate: TestDelegate(),
                    userConfiguration: configuration
                )

                screenManager.updateSpace(to: space1)
                screenManager.updateSpace(to: space2)
                screenManager.setLayout("wide", for: space1)
                screenManager.setTilingEnabled(true, for: space1)

                screenManager.updateSpace(to: space1)

                expect(screenManager.currentLayout?.layoutKey).to(equal("wide"))
                expect(screenManager.currentSpaceTilingEnabled).to(beTrue())
            }

            it("keeps the tracked desktop when a fullscreen Space becomes current") { @MainActor in
                let configuration = configuration(["tall", "wide"])
                let screen = TestScreen()
                configuration.setDisplayDefaults(
                    DisplayDefaults(tilingEnabled: true, layoutKey: "wide"),
                    forDisplayID: screen.screenID()!
                )
                let screenManager = ScreenManager(
                    screen: screen,
                    delegate: TestDelegate(),
                    userConfiguration: configuration
                )
                let fullscreenSpace = Space(id: 45, type: CGSSpaceType(rawValue: 4), uuid: "fullscreen", isFullscreen: true)

                screenManager.updateSpace(to: space1)
                screenManager.updateSpace(to: fullscreenSpace)

                expect(screenManager.space?.id).to(equal(space1.id))
                expect(screenManager.currentLayout?.layoutKey).to(equal("wide"))
            }

            it("keeps tiling enabled state independent for each Space") { @MainActor in
                let configuration = configuration(["tall", "wide"])
                let screen = TestScreen()
                configuration.setDisplayDefaults(
                    DisplayDefaults(tilingEnabled: true, layoutKey: nil),
                    forDisplayID: screen.screenID()!
                )
                let delegate = TestDelegate()
                let screenManager = ScreenManager(
                    screen: screen,
                    delegate: delegate,
                    userConfiguration: configuration
                )

                screenManager.updateSpace(to: space1)
                expect(screenManager.currentSpaceTilingEnabled).to(beTrue())
                screenManager.toggleTilingForCurrentSpace()
                expect(screenManager.currentSpaceTilingEnabled).to(beFalse())

                screenManager.updateSpace(to: space2)
                expect(screenManager.currentSpaceTilingEnabled).to(beTrue())

                screenManager.updateSpace(to: space1)
                expect(screenManager.currentSpaceTilingEnabled).to(beFalse())
                expect(delegate.persistentStateChangeCount).to(equal(1))

                let data = try JSONEncoder().encode(screenManager)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                expect(json?["tilingEnabledBySpaceUUID"] as? [String: Bool])
                    .to(equal(["space-1": false, "space-2": true]))
            }
        }

        describe("Space reflow policy") {
            let userSpace = Space(id: 1, type: CGSSpaceTypeUser, uuid: "user-space")
            let nextUserSpace = Space(id: 2, type: CGSSpaceTypeUser, uuid: "next-user-space")
            let fullscreenSpace = Space(id: 3, type: CGSSpaceType(rawValue: 1), uuid: "fullscreen-space")
            let unknownLegacySpace = Space(id: 1, type: CGSSpaceTypeUser, uuid: "")

            it("keeps core tiling available when no Space can be discovered") {
                expect(
                    SpaceReflowPolicy.canReflow(
                        tilingEnabled: true,
                        trackedSpace: nil,
                        currentSpace: nil
                    )
                ).to(beTrue())
            }

            it("keeps core tiling available when a tracked user Space cannot be queried") {
                expect(
                    SpaceReflowPolicy.canReflow(
                        tilingEnabled: true,
                        trackedSpace: userSpace,
                        currentSpace: nil
                    )
                ).to(beTrue())
            }

            it("treats an empty-UUID legacy Space descriptor as unavailable data") {
                expect(SpaceReflowPolicy.isUnknownLegacySpace(unknownLegacySpace)).to(beTrue())
                expect(
                    SpaceReflowPolicy.canReflow(
                        tilingEnabled: true,
                        trackedSpace: userSpace,
                        currentSpace: unknownLegacySpace
                    )
                ).to(beTrue())
            }

            it("skips a known stale Space transition") {
                expect(
                    SpaceReflowPolicy.canReflow(
                        tilingEnabled: true,
                        trackedSpace: userSpace,
                        currentSpace: nextUserSpace
                    )
                ).to(beFalse())
            }

            it("does not tile fullscreen or system Spaces") {
                expect(
                    SpaceReflowPolicy.canReflow(
                        tilingEnabled: true,
                        trackedSpace: fullscreenSpace,
                        currentSpace: fullscreenSpace
                    )
                ).to(beFalse())
            }

            it("does not tile a fullscreen Space while the desktop is untracked") {
                let macFullscreenSpace = Space(id: 45, type: CGSSpaceType(rawValue: 4), uuid: "fs-45", isFullscreen: true)

                expect(
                    SpaceReflowPolicy.canReflow(
                        tilingEnabled: true,
                        trackedSpace: nil,
                        currentSpace: macFullscreenSpace
                    )
                ).to(beFalse())
            }

            it("honors global tiling disablement before any Space decision") {
                expect(
                    SpaceReflowPolicy.canReflow(
                        tilingEnabled: false,
                        trackedSpace: nil,
                        currentSpace: nil
                    )
                ).to(beFalse())
            }
        }

        describe("layout selection") {
            let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))

            func makeScreenManager(layoutKeys: [String]) -> ScreenManager<TestDelegate> {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                let screenManager = ScreenManager<TestDelegate>(
                    screen: screen,
                    delegate: TestDelegate(),
                    userConfiguration: configuration,
                    layoutProvider: {
                        layoutKeys.compactMap { LayoutType<TestWindow>.layoutForKey($0) }
                    }
                )
                screenManager.updateSpace(to: Space(id: 1, type: CGSSpaceTypeUser, uuid: "space-1"))
                return screenManager
            }

            afterEach {
                TestScreen.descriptions = []
                TestScreen.availableScreens = []
            }

            it("selects the requested layout") {
                let screenManager = makeScreenManager(layoutKeys: [
                    TallLayout<TestWindow>.layoutKey,
                    WideLayout<TestWindow>.layoutKey
                ])

                screenManager.selectLayout(WideLayout<TestWindow>.layoutKey)

                expect(screenManager.layoutsInfo.first { $0.isSelected }?.key)
                    .to(equal(WideLayout<TestWindow>.layoutKey))
            }

            it("ignores an unknown layout key") {
                let screenManager = makeScreenManager(layoutKeys: [
                    TallLayout<TestWindow>.layoutKey,
                    WideLayout<TestWindow>.layoutKey
                ])
                let initiallySelected = screenManager.layoutsInfo.first { $0.isSelected }?.key

                screenManager.selectLayout("not-a-layout")

                expect(screenManager.layoutsInfo.first { $0.isSelected }?.key).to(equal(initiallySelected))
            }

            it("keeps the selected layout when selecting it again") {
                let screenManager = makeScreenManager(layoutKeys: [
                    TallLayout<TestWindow>.layoutKey,
                    WideLayout<TestWindow>.layoutKey
                ])
                let wideKey = WideLayout<TestWindow>.layoutKey

                screenManager.selectLayout(wideKey)
                screenManager.selectLayout(wideKey)

                expect(screenManager.layoutsInfo.first { $0.isSelected }?.key).to(equal(wideKey))
            }

            it("encodes the current layout index for the space") {
                let screenManager = makeScreenManager(layoutKeys: [
                    TallLayout<TestWindow>.layoutKey,
                    WideLayout<TestWindow>.layoutKey
                ])
                screenManager.selectLayout(WideLayout<TestWindow>.layoutKey)

                let data = try JSONEncoder().encode(screenManager)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                expect(json?["currentLayoutIndexBySpaceUUID"] as? [String: Int])
                    .to(equal(["space-1": 1]))
            }

            it("notifies its owner immediately when a Space layout changes") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.tilingEnabled = false
                let delegate = TestDelegate()
                let screenManager = ScreenManager(
                    screen: screen,
                    delegate: delegate,
                    userConfiguration: configuration,
                    layoutProvider: { [TallLayout<TestWindow>(), WideLayout<TestWindow>()] }
                )
                screenManager.updateSpace(to: Space(id: 1, type: CGSSpaceTypeUser, uuid: "space-1"))

                screenManager.selectLayout(WideLayout<TestWindow>.layoutKey)

                expect(delegate.persistentStateChangeCount).to(equal(1))
            }

            it("keeps a separate layout index per space") {
                let screenManager = makeScreenManager(layoutKeys: [
                    TallLayout<TestWindow>.layoutKey,
                    WideLayout<TestWindow>.layoutKey,
                    FullscreenLayout<TestWindow>.layoutKey
                ])
                let space2 = Space(id: 2, type: CGSSpaceTypeUser, uuid: "space-2")

                screenManager.selectLayout(WideLayout<TestWindow>.layoutKey)
                screenManager.updateSpace(to: space2)

                expect(screenManager.layoutsInfo.first { $0.isSelected }?.key)
                    .to(equal(TallLayout<TestWindow>.layoutKey))

                screenManager.selectLayout(FullscreenLayout<TestWindow>.layoutKey)
                screenManager.updateSpace(to: Space(id: 1, type: CGSSpaceTypeUser, uuid: "space-1"))

                expect(screenManager.layoutsInfo.first { $0.isSelected }?.key)
                    .to(equal(WideLayout<TestWindow>.layoutKey))

                screenManager.updateSpace(to: space2)

                expect(screenManager.layoutsInfo.first { $0.isSelected }?.key)
                    .to(equal(FullscreenLayout<TestWindow>.layoutKey))
            }

            it("encodes layout indices for multiple spaces") {
                let screenManager = makeScreenManager(layoutKeys: [
                    TallLayout<TestWindow>.layoutKey,
                    WideLayout<TestWindow>.layoutKey,
                    FullscreenLayout<TestWindow>.layoutKey
                ])
                let space2 = Space(id: 2, type: CGSSpaceTypeUser, uuid: "space-2")

                screenManager.selectLayout(WideLayout<TestWindow>.layoutKey)
                screenManager.updateSpace(to: space2)
                screenManager.selectLayout(FullscreenLayout<TestWindow>.layoutKey)

                let data = try JSONEncoder().encode(screenManager)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                expect(json?["currentLayoutIndexBySpaceUUID"] as? [String: Int])
                    .to(equal(["space-1": 1, "space-2": 2]))
            }
        }
    }
}
