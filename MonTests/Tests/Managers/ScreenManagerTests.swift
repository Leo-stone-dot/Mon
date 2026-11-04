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
        describe("coding") {
            it("decodes layouts") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.setLayoutKeys(LayoutType<TestWindow>.standardLayoutClasses().map { $0.layoutKey })

                let layouts = LayoutType<TestWindow>.standardLayoutClasses().map { $0.init() }
                let encoder = JSONEncoder()
                let encodedLayouts = layouts.map { ["key": $0.layoutKey.data(using: .utf8)!, "data": try! encoder.encode($0)] }
                let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                expect(decodedLayouts.count).to(equal(layouts.count))
                expect(decodedLayouts.count).to(equal(encodedLayouts.count))
                expect(decodedLayouts.map { $0.layoutKey }).to(equal(layouts.map { $0.layoutKey }))
            }

            it("replaces incorrectly encoded layouts") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.setLayoutKeys([FullscreenLayout<TestWindow>.layoutKey, TallLayout<TestWindow>.layoutKey])

                let encoder = JSONEncoder()
                let encodedLayouts = [
                    ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(FullscreenLayout<TestWindow>())],
                    ["key": TallLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(["incorrect": "encoding"])]
                ]
                let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                expect {
                    try JSONDecoder().decode(TallLayout<TestWindow>.self, from: encodedLayouts[1]["data"]!)
                }.to(throwError())

                expect(decodedLayouts.count).to(equal(2))
                expect(decodedLayouts.map { $0.layoutKey }).to(equal(configuration.layoutKeys()))
            }

            it("replaces incorrectly keyed layouts") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.setLayoutKeys([FullscreenLayout<TestWindow>.layoutKey, TallLayout<TestWindow>.layoutKey])

                let encoder = JSONEncoder()
                let encodedLayouts = [
                    ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(FullscreenLayout<TestWindow>())],
                    ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(TallLayout<TestWindow>())]
                ]
                let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                expect(decodedLayouts.count).to(equal(2))
                expect(decodedLayouts.map { $0.layoutKey }).to(equal(configuration.layoutKeys()))
            }

            it("keeps a layout that only the Space uses") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.setLayoutKeys([TallLayout<TestWindow>.layoutKey])

                let encoder = JSONEncoder()
                let encodedLayouts = [
                    ["key": TallLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(TallLayout<TestWindow>())],
                    ["key": WideLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(WideLayout<TestWindow>())]
                ]
                let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                expect(decodedLayouts.map { $0.layoutKey }).to(equal([TallLayout<TestWindow>.layoutKey, WideLayout<TestWindow>.layoutKey]))
            }

            context("layout list changes") {
                it("maintains encoded layouts on insertions") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.setLayoutKeys([
                        FullscreenLayout<TestWindow>.layoutKey,
                        WideLayout<TestWindow>.layoutKey,
                        TallLayout<TestWindow>.layoutKey
                    ])

                    let encoder = JSONEncoder()
                    let tallLayout = TallLayout<TestWindow>()
                    tallLayout.increaseMainPaneCount()

                    expect(tallLayout.mainPaneCount).to(equal(2))

                    let encodedLayouts = [
                        ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(FullscreenLayout<TestWindow>())],
                        ["key": TallLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(tallLayout)]
                    ]
                    let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                    expect(decodedLayouts.count).to(equal(3))
                    expect(decodedLayouts.map { $0.layoutKey }).to(equal(configuration.layoutKeys()))
                    expect((decodedLayouts.last as? TallLayout<TestWindow>)?.mainPaneCount).to(equal(2))
                }

                it("maintains encoded layouts on appends") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.setLayoutKeys([
                        FullscreenLayout<TestWindow>.layoutKey,
                        TallLayout<TestWindow>.layoutKey,
                        WideLayout<TestWindow>.layoutKey
                    ])

                    let encoder = JSONEncoder()
                    let tallLayout = TallLayout<TestWindow>()
                    tallLayout.increaseMainPaneCount()

                    expect(tallLayout.mainPaneCount).to(equal(2))

                    let encodedLayouts = [
                        ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(FullscreenLayout<TestWindow>())],
                        ["key": TallLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(tallLayout)]
                    ]
                    let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                    expect(decodedLayouts.count).to(equal(3))
                    expect(decodedLayouts.map { $0.layoutKey }).to(equal(configuration.layoutKeys()))
                    expect((decodedLayouts[1] as? TallLayout<TestWindow>)?.mainPaneCount).to(equal(2))
                }

                it("maintains encoded layouts on prepends") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.setLayoutKeys([
                        WideLayout<TestWindow>.layoutKey,
                        FullscreenLayout<TestWindow>.layoutKey,
                        TallLayout<TestWindow>.layoutKey
                    ])

                    let encoder = JSONEncoder()
                    let tallLayout = TallLayout<TestWindow>()
                    tallLayout.increaseMainPaneCount()

                    expect(tallLayout.mainPaneCount).to(equal(2))

                    let encodedLayouts = [
                        ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(FullscreenLayout<TestWindow>())],
                        ["key": TallLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(tallLayout)]
                    ]
                    let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                    expect(decodedLayouts.count).to(equal(3))
                    expect(decodedLayouts.map { $0.layoutKey }).to(equal(configuration.layoutKeys()))
                    expect((decodedLayouts.last as? TallLayout<TestWindow>)?.mainPaneCount).to(equal(2))
                }

                it("maintains existing layouts on deletes") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.setLayoutKeys([
                        WideLayout<TestWindow>.layoutKey,
                        TallLayout<TestWindow>.layoutKey
                    ])

                    let encoder = JSONEncoder()
                    let wideLayout = WideLayout<TestWindow>()
                    let tallLayout = TallLayout<TestWindow>()
                    wideLayout.increaseMainPaneCount()
                    tallLayout.increaseMainPaneCount()

                    expect(wideLayout.mainPaneCount).to(equal(2))
                    expect(tallLayout.mainPaneCount).to(equal(2))

                    let encodedLayouts = [
                        ["key": WideLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(wideLayout)],
                        ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(FullscreenLayout<TestWindow>())],
                        ["key": TallLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(tallLayout)]
                    ]
                    let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                    // A layout that only the Space uses is kept at the end instead of being deleted.
                    expect(decodedLayouts.count).to(equal(3))
                    expect(decodedLayouts.map { $0.layoutKey }).to(equal([WideLayout<TestWindow>.layoutKey, TallLayout<TestWindow>.layoutKey, FullscreenLayout<TestWindow>.layoutKey]))
                    expect((decodedLayouts.first as? WideLayout<TestWindow>)?.mainPaneCount).to(equal(2))
                    expect((decodedLayouts.dropFirst().first as? TallLayout<TestWindow>)?.mainPaneCount).to(equal(2))
                }
            }
        }

        describe("restoring screen and Space layouts") {
            let space1 = Space(id: 1, type: CGSSpaceTypeUser, uuid: "space-1")
            let space2 = Space(id: 2, type: CGSSpaceTypeUser, uuid: "space-2")

            func configuration(_ keys: [String]) -> UserConfiguration {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.setLayoutKeys(keys)
                configuration.tilingEnabled = false
                return configuration
            }

            func manager(_ configuration: UserConfiguration) -> ScreenManager<TestDelegate> {
                let manager = ScreenManager(screen: TestScreen(), delegate: TestDelegate(), userConfiguration: configuration)
                manager.updateSpace(to: space1)
                return manager
            }

            func decoder(_ configuration: UserConfiguration) -> JSONDecoder {
                let decoder = JSONDecoder()
                decoder.userInfo[.screenManagerConfiguration] = configuration
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

            it("retains the chosen layout when the configured list is reordered or entries change") { @MainActor in
                let original = manager(configuration(["tall", "wide", "fullscreen"]))
                original.selectLayout("wide")
                let data = try JSONEncoder().encode(original)

                for keys in [["wide", "tall", "fullscreen"], ["column", "tall", "wide", "fullscreen"], ["wide", "fullscreen"]] {
                    let restored = try decoder(configuration(keys)).decode(ScreenManager<TestDelegate>.self, from: data)
                    restored.updateSpace(to: space1)
                    expect(restored.currentLayout?.layoutKey).to(equal("wide"))
                }
            }

            it("retains a selected layout that is no longer in the configured list") { @MainActor in
                let original = manager(configuration(["tall", "wide", "fullscreen"]))
                original.selectLayout("wide")
                original.updateSpace(to: space2)
                original.selectLayout("fullscreen")
                let data = try JSONEncoder().encode(original)
                let restored = try decoder(configuration(["tall", "fullscreen"])).decode(ScreenManager<TestDelegate>.self, from: data)

                restored.updateSpace(to: space2)
                expect(restored.currentLayout?.layoutKey).to(equal("fullscreen"))
                restored.updateSpace(to: space1)
                expect(restored.currentLayout?.layoutKey).to(equal("wide"))
                restored.updateSpace(to: space2)
                expect(restored.currentLayout?.layoutKey).to(equal("fullscreen"))
            }

            it("restores a custom layout key after its position changes") { @MainActor in
                // The factory requires an installed file. Use a unique fixture
                // and remove only that file; never alter a user's custom layout.
                let customKey = "restoration-test-\(UUID().uuidString)"
                let fileURL = try FileManager.default.layoutFile(key: customKey)
                let fixtureURL = try XCTUnwrap(Bundle.layoutFile(key: "uniform-columns"))
                try Data(contentsOf: fixtureURL).write(to: fileURL, options: .withoutOverwriting)
                defer { try? FileManager.default.removeItem(at: fileURL) }
                let original = manager(configuration(["tall", customKey, "wide"]))
                original.selectLayout(customKey)
                let data = try JSONEncoder().encode(original)
                let restored = try decoder(configuration(["wide", "tall", customKey])).decode(ScreenManager<TestDelegate>.self, from: data)

                restored.updateSpace(to: space1)
                expect(restored.currentLayout is CustomLayout<TestWindow>).to(beTrue())
                expect(restored.currentLayout?.layoutKey).to(equal(customKey))
            }

            it("switches between cached Space layout lists of different lengths") { @MainActor in
                let configuration = configuration(["tall", "wide", "fullscreen"])
                let original = manager(configuration)
                original.selectLayout("fullscreen")
                configuration.setLayoutKeys(["wide"])

                original.updateSpace(to: space2)
                expect(original.currentLayout?.layoutKey).to(equal("wide"))
                original.updateSpace(to: space1)
                expect(original.currentLayout?.layoutKey).to(equal("fullscreen"))
                original.updateSpace(to: space2)
                expect(original.currentLayout?.layoutKey).to(equal("wide"))
            }

            it("handles restoring and cycling when all layouts were removed") { @MainActor in
                let original = manager(configuration(["tall", "wide"]))
                original.selectLayout("wide")
                let data = try JSONEncoder().encode(original)
                let restored = try decoder(configuration([])).decode(ScreenManager<TestDelegate>.self, from: data)

                restored.updateSpace(to: space1)
                restored.cycleLayoutForward()
                restored.cycleLayoutBackward()
                restored.selectLayout("wide")
                restored.updateSpace(to: space2)
                expect(restored.currentLayout).to(beNil())
                expect(restored.layoutsInfo).to(beEmpty())
            }

            it("reads legacy state that has no saved selection") { @MainActor in
                let configuration = configuration(["wide", "tall"])
                let data = try JSONEncoder().encode(manager(configuration))
                var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
                json.removeValue(forKey: "currentLayoutIndexBySpaceUUID")
                let legacyData = try JSONSerialization.data(withJSONObject: json)
                let restored = try decoder(configuration).decode(ScreenManager<TestDelegate>.self, from: legacyData)

                restored.updateSpace(to: space1)
                expect(restored.currentLayout?.layoutKey).to(equal("wide"))
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

            it("uses the display's default layout for a newly tracked Space") { @MainActor in
                let configuration = configuration(["tall", "wide"])
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                configuration.setDisplayDefaults(
                    DisplayDefaults(tilingEnabled: true, layoutKey: "wide"),
                    forDisplayID: screen.screenID()!
                )
                let screenManager = ScreenManager(
                    screen: screen,
                    delegate: TestDelegate(),
                    userConfiguration: configuration,
                    spaceClient: .unavailable
                )

                screenManager.updateSpace(to: space1)

                expect(screenManager.currentLayout?.layoutKey).to(equal("wide"))
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
                expect(indices?["display:\(screen.screenID()!)"]).to(equal(1))
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
                configuration.setLayoutKeys(layoutKeys)
                let screenManager = ScreenManager<TestDelegate>(
                    screen: screen,
                    delegate: TestDelegate(),
                    userConfiguration: configuration
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
                configuration.setLayoutKeys([
                    TallLayout<TestWindow>.layoutKey,
                    WideLayout<TestWindow>.layoutKey
                ])
                configuration.tilingEnabled = false
                let delegate = TestDelegate()
                let screenManager = ScreenManager(
                    screen: screen,
                    delegate: delegate,
                    userConfiguration: configuration
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
