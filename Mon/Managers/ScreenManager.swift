//
//  ScreenManager.swift
//  Mon
//
//  Created by Ian Ynda-Hummel on 12/23/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

extension CodingUserInfoKey {
    static let screenManagerConfiguration = CodingUserInfoKey(rawValue: "screenManagerConfiguration")!
    static let screenManagerLayoutProvider = CodingUserInfoKey(rawValue: "screenManagerLayoutProvider")!
}

enum SpaceReflowPolicy {
    static func isUnknownLegacySpace(_ space: Space) -> Bool {
        return space.type.rawValue == CGSSpaceTypeUser.rawValue && space.uuid.isEmpty
    }

    static func canReflow(tilingEnabled: Bool, trackedSpace: Space?, currentSpace: Space?) -> Bool {
        guard tilingEnabled else {
            return false
        }

        // A known fullscreen or system Space is never tiled, even before the
        // desktop Space has been tracked.
        if let currentSpace = currentSpace,
           !currentSpace.isUserSpace,
           !isUnknownLegacySpace(currentSpace) {
            return false
        }

        guard let trackedSpace = trackedSpace else {
            // Space discovery is private API. Its absence must not prevent the
            // public Accessibility window-management path from tiling.
            return true
        }

        guard trackedSpace.isUserSpace || isUnknownLegacySpace(trackedSpace) else {
            return false
        }

        // A known mismatch means a rapid Space transition is still in flight;
        // an unavailable query is a degradation, not evidence of a mismatch.
        guard let currentSpace = currentSpace else {
            return true
        }
        if isUnknownLegacySpace(currentSpace) {
            return true
        }

        return currentSpace.id == trackedSpace.id
    }
}

/// Information about a layout for display in menus
struct LayoutMenuItemInfo {
    let key: String
    let name: String
    let isSelected: Bool
}

protocol ScreenManagerDelegate: AnyObject {
    associatedtype Window: WindowType
    func applyWindowLimit(forScreenManager screenManager: ScreenManager<Self>, minimizingIn range: (_ windowCount: Int) -> Range<Int>)
    func activeWindowSet(forScreenManager screenManager: ScreenManager<Self>, on screen: Window.Screen) -> WindowSet<Window>
    func onReflowInitiation()
    func onReflowCompletion()
    func screenManagerPersistentStateDidChange(_ screenManager: ScreenManager<Self>)
}

extension ScreenManagerDelegate {
    func screenManagerPersistentStateDidChange(_ screenManager: ScreenManager<Self>) {}
}

final class ScreenManager<Delegate: ScreenManagerDelegate>: NSObject, Codable {
    typealias Window = Delegate.Window
    typealias Screen = Window.Screen

    enum CodingKeys: String, CodingKey {
        case layoutsBySpaceUUID
        case currentLayoutIndexBySpaceUUID
        case tilingEnabledBySpaceUUID
    }

    weak var delegate: Delegate?

    private(set) var screen: Screen?
    private(set) var space: Space?

    /// The last window that has been focused on the screen. This value is updated by the notification observations in
    /// `ObserveApplicationNotifications`.
    private(set) var lastFocusedWindow: Window?
    private let userConfiguration: UserConfiguration
    private let spaceClient: SpaceClient<Window>
    private let layoutProvider: () -> [Layout<Window>]

    private let reflowOperationDispatchQueue = DispatchQueue(
        label: "ScreenManager.reflowOperationQueue",
        qos: .utility,
        attributes: [],
        autoreleaseFrequency: .inherit,
        target: nil
    )
    private let reflowOperationQueue = OperationQueue()

    private var layouts: [Layout<Window>] = []
    private var currentLayoutIndexBySpaceUUID: [String: Int] = [:]
    private var tilingEnabledBySpaceUUID: [String: Bool] = [:]
    private var layoutsBySpaceUUID: [String: [Layout<Window>]] = [:]
    private var currentLayoutIndex: Int = 0
    var currentLayout: Layout<Window>? {
        guard layouts.indices.contains(currentLayoutIndex) else {
            return nil
        }
        return layouts[currentLayoutIndex]
    }

    /// Returns layout info for all layouts in this screen manager, including selection state
    var layoutsInfo: [LayoutMenuItemInfo] {
        return layouts.enumerated().map { index, layout in
            LayoutMenuItemInfo(
                key: layout.layoutKey,
                name: layout.layoutName,
                isSelected: index == currentLayoutIndex
            )
        }
    }

    private let layoutNameWindowController: LayoutNameWindowController

    init(
        screen: Screen,
        delegate: Delegate,
        userConfiguration: UserConfiguration,
        spaceClient: SpaceClient<Window> = .cgs,
        layoutProvider: @escaping () -> [Layout<Window>] = { LayoutType.availableLayouts() }
    ) {
        self.screen = screen
        self.delegate = delegate
        self.userConfiguration = userConfiguration
        self.spaceClient = spaceClient
        self.layoutProvider = layoutProvider

        layoutNameWindowController = LayoutNameWindowController(windowNibName: "LayoutNameWindow")

        super.init()

        layouts = layoutProvider()

        reflowOperationQueue.underlyingQueue = reflowOperationDispatchQueue
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let layoutsBySpaceUUID = try values.decode([String: [[String: Data]]].self, forKey: .layoutsBySpaceUUID)

        let configuration = decoder.userInfo[.screenManagerConfiguration] as? UserConfiguration ?? UserConfiguration.shared
        let injectedLayoutProvider = decoder.userInfo[.screenManagerLayoutProvider] as? () -> [Layout<Window>]
        let layoutProvider = injectedLayoutProvider ?? { LayoutType.availableLayouts() }
        self.userConfiguration = configuration
        self.spaceClient = .cgs
        self.layoutProvider = layoutProvider
        let decodedLayouts = try layoutsBySpaceUUID.mapValues { keyedLayouts -> [Layout<Window>] in
            return try ScreenManager<Delegate>.decodedLayouts(
                from: keyedLayouts,
                userConfiguration: configuration,
                availableLayouts: layoutProvider()
            )
        }
        self.layoutsBySpaceUUID = decodedLayouts
        let encodedIndices = try values.decodeIfPresent(
            [String: Int].self,
            forKey: .currentLayoutIndexBySpaceUUID
        ) ?? [:]
        // Indices belong to the saved list. Resolve through its key before
        // applying the current configuration's ordering and enabled layouts.
        self.currentLayoutIndexBySpaceUUID = encodedIndices.reduce(into: [:]) { indices, entry in
            let (spaceUUID, savedIndex) = entry
            guard let savedLayouts = layoutsBySpaceUUID[spaceUUID],
                  savedLayouts.indices.contains(savedIndex),
                  let keyData = savedLayouts[savedIndex]["key"],
                  let key = String(data: keyData, encoding: .utf8),
                  let index = decodedLayouts[spaceUUID]?.firstIndex(where: { $0.layoutKey == key }) else {
                return
            }
            indices[spaceUUID] = index
        }
        self.tilingEnabledBySpaceUUID = try values.decodeIfPresent(
            [String: Bool].self,
            forKey: .tilingEnabledBySpaceUUID
        ) ?? [:]

        layoutNameWindowController = LayoutNameWindowController(windowNibName: "LayoutNameWindow")
        super.init()
        reflowOperationQueue.underlyingQueue = reflowOperationDispatchQueue
    }

    /**
     Restores a Space's state into the current deterministic layout catalog.

     Built-in layout state is recovered by key. Custom layouts are reconstructed
     from their currently validated files instead of trusting an encoded path.

     - Parameters:
        - encodedLayouts: The previously encoded layout states.
        - userConfiguration: The configuration used by restored layout instances.
        - availableLayouts: The current catalog in cycle order.
     */
    static func decodedLayouts(
        from encodedLayouts: [[String: Data]],
        userConfiguration: UserConfiguration,
        availableLayouts: [Layout<Window>] = LayoutType.availableLayouts()
    ) throws -> [Layout<Window>] {
        _ = userConfiguration
        let availableKeys = Set(availableLayouts.map { $0.layoutKey })
        var decodedByKey: [String: Layout<Window>] = [:]

        for layout in encodedLayouts {
            guard let keyData = layout["key"],
                  let key = String(data: keyData, encoding: .utf8),
                  availableKeys.contains(key),
                  decodedByKey[key] == nil,
                  let data = layout["data"] else {
                continue
            }

            // Custom layouts are rebound to the current validated catalog file.
            // Their encoded absolute file URL is not trusted during migration.
            if case .custom = LayoutType<Window>.from(key: key) {
                continue
            }

            do {
                decodedByKey[key] = try LayoutType<Window>.decoded(data: data, key: key)
            } catch {
                log.error("Failed to decode layout state for \(key); using a fresh layout")
            }
        }

        return availableLayouts.map { decodedByKey[$0.layoutKey] ?? $0 }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        let layoutsBySpaceUUID = try self.layoutsBySpaceUUID.mapValues { layouts in
            return try layouts.map { layout -> [String: Data] in
                let layoutKey = layout.layoutKey.data(using: .utf8)!
                let encodedLayout = try LayoutType.encoded(layout: layout)
                return ["key": layoutKey, "data": encodedLayout]
            }
        }
        try values.encode(layoutsBySpaceUUID, forKey: .layoutsBySpaceUUID)
        try values.encode(currentLayoutIndexBySpaceUUID, forKey: .currentLayoutIndexBySpaceUUID)
        try values.encode(tilingEnabledBySpaceUUID, forKey: .tilingEnabledBySpaceUUID)
    }

    func updateScreen(to screen: Screen) {
        self.screen = screen
    }

    /// The key used to persist this Space's layout and tiling state.
    ///
    /// macOS 26 can report a desktop without a UUID (the main display's desktop
    /// on some machines). Those descriptors still name a real desktop, so they
    /// are tracked with a display-scoped key instead of being discarded.
    private func stateKey(for space: Space) -> String {
        if space.hasStableIdentifier {
            return space.uuid
        }

        return "display:\(screen?.screenID() ?? "unknown")"
    }

    private var displayDefaults: DisplayDefaults? {
        guard let displayID = screen?.screenID() else {
            return nil
        }

        return userConfiguration.displayDefaults(forDisplayID: displayID)
    }

    private func defaultTilingEnabled() -> Bool {
        return displayDefaults?.tilingEnabled ?? false
    }

    private func defaultLayoutIndex(in layouts: [Layout<Window>]) -> Int {
        guard let layoutKey = displayDefaults?.layoutKey,
              let index = layouts.firstIndex(where: { $0.layoutKey == layoutKey }) else {
            return 0
        }

        return index
    }

    func updateSpace(to space: Space) {
        // Fullscreen and system Spaces are not tiled desktops. Keep tracking the
        // last user desktop so its layout and tiling state survive the detour.
        guard space.isUserSpace else {
            return
        }

        if let previousSpace = self.space {
            currentLayoutIndexBySpaceUUID[stateKey(for: previousSpace)] = currentLayoutIndex
        }

        self.space = space
        let key = stateKey(for: space)

        if tilingEnabledBySpaceUUID[key] == nil {
            tilingEnabledBySpaceUUID[key] = defaultTilingEnabled()
        }

        if let layouts = layoutsBySpaceUUID[key] {
            self.layouts = layouts
        } else {
            let layouts = layoutProvider()
            self.layouts = layouts
            layoutsBySpaceUUID[key] = layouts
            if currentLayoutIndexBySpaceUUID[key] == nil {
                currentLayoutIndexBySpaceUUID[key] = defaultLayoutIndex(in: layouts)
            }
        }

        // A decoded manager starts with an empty active list. Load the target
        // Space's layouts before validating and restoring its selection.
        currentLayoutIndex = 0
        let index = currentLayoutIndexBySpaceUUID[key] ?? 0
        setCurrentLayoutIndex(layouts.indices.contains(index) ? index : 0, changingSpace: true)
    }

    func distributeEvent(_ change: Change<Window>) {
        switch change {
        case let .add(window: window):
            lastFocusedWindow = window
        case let .focusChanged(window):
            lastFocusedWindow = window
        case let .remove(window):
            if lastFocusedWindow == window {
                lastFocusedWindow = nil
            }
        case .windowSwap, .applicationActivate, .applicationDeactivate, .spaceChange, .layoutChange, .tabChange, .none, .unknown:
            break
        }

        log.debug("Screen: \(screen?.screenID() ?? "unknown") reflow -- Window Change: \(change)")

        let layouts = space.flatMap { layoutsBySpaceUUID[stateKey(for: $0)] } ?? layouts

        for layout in layouts {
            if let layout = layout as? StatefulLayout {
                layout.updateWithChange(change)
            }
        }
    }

    func setNeedsReflow() {
        reflowOperationQueue.cancelAllOperations()

        log.debug("Screen: \(screen?.screenID() ?? "unknown") reflow")

        DispatchQueue.main.async {
            self.minimizeWindows()
            self.reflow()
        }
    }

    private func minimizeWindows() {
        let mainPaneCount = (currentLayout as? PanedLayout)?.mainPaneCount ?? 0

        guard tilingEnabledForCurrentTarget, let windowLimit = userConfiguration.windowMaxCount() else {
            return
        }
        let shouldInsertAtFront = userConfiguration.sendNewWindowsToMainPane()
        delegate?.applyWindowLimit(forScreenManager: self, minimizingIn: { windowCount in
            if windowLimit > windowCount {
                // Not enough windows to minimize.
                return 0 ..< 0
            }
            if !(currentLayout is PanedLayout) {
                // Minimize from the back, for layouts like floating/fullscreen.
                if shouldInsertAtFront {
                    return windowLimit ..< windowCount
                } else {
                    return 0 ..< windowCount - windowLimit
                }
            }
            if windowLimit <= mainPaneCount {
                // Don't minimize main panes. This allowing varying main pane count to pin windows.
                guard windowCount >= mainPaneCount else {return 0 ..< 0}
                return mainPaneCount ..< windowCount
            }
            // Minimize the oldest non-main panes.
            if shouldInsertAtFront {
                return windowLimit ..< windowCount
            } else {
                return mainPaneCount ..< windowCount + mainPaneCount - windowLimit
            }
        })
    }

    private func reflow() {
        guard let screen = screen else {
            return
        }

        // The Space change notification can be missed while the app launches or
        // while a fullscreen Space is active. Adopt the desktop reported by the
        // private API so per-display defaults and saved state stay attached to
        // the Space that is actually visible.
        let currentSpace = spaceClient.currentSpaceForScreen(screen)
        if let currentSpace = currentSpace,
           currentSpace.isUserSpace,
           currentSpace.id != space?.id {
            updateSpace(to: currentSpace)
        }

        // During rapid Space transitions, activation/focus notifications can arrive before
        // this screen manager updates its tracked Space. A positive mismatch skips reflow;
        // unavailable private Space data keeps the public tiling path available.
        guard SpaceReflowPolicy.canReflow(
            tilingEnabled: tilingEnabledForCurrentTarget,
            trackedSpace: space,
            currentSpace: currentSpace
        ) else {
            return
        }

        guard let windows = delegate?.activeWindowSet(forScreenManager: self, on: screen) else {
            return
        }

        guard let layout = currentLayout, let frameAssignments = layout.frameAssignments(windows, on: screen) else {
            return
        }

        // TODO: fix mff
//        let mouseFollowsFocus = userConfiguration.mouseFollowsFocus()

        let completeOperation = BlockOperation()

        // The complete operation should execute the completion delegate call
        completeOperation.addExecutionBlock { [unowned completeOperation, weak self] in
            if completeOperation.isCancelled {
                return
            }

            DispatchQueue.main.async {
                self?.delegate?.onReflowCompletion()
                // TODO: fix mff
//                if mouseFollowsFocus {
//                    if case .windowSwap(let window, _) = event {
//                        window.focus()
//                    }
//                }
            }
        }

        // The completion should be dependent on all assignments finishing
        frameAssignments.forEach { completeOperation.addDependency($0) }

        // Start the operation
        delegate?.onReflowInitiation()
        reflowOperationQueue.addOperations(frameAssignments, waitUntilFinished: false)
        reflowOperationQueue.addOperation(completeOperation)
    }

    func updateCurrentLayout(_ updater: (Layout<Window>) -> Void) {
        guard let layout = currentLayout else {
            return
        }
        updater(layout)
        delegate?.screenManagerPersistentStateDidChange(self)
        setNeedsReflow()
    }

    var currentSpaceTilingEnabled: Bool? {
        guard let space = space else {
            return nil
        }
        return tilingEnabledBySpaceUUID[stateKey(for: space)] ?? true
    }

    var currentDisplayTilingEnabled: Bool? {
        guard screen != nil else {
            return nil
        }

        let states = userSpacesForCurrentDisplay().map { tilingEnabled(for: $0) }
        if !states.isEmpty {
            return states.contains(true)
        }

        guard let space = space else {
            return displayDefaults?.tilingEnabled
        }
        return tilingEnabledBySpaceUUID[stateKey(for: space)] ?? defaultTilingEnabled()
    }

    /// The layout key currently applied to the tracked Space.
    var currentLayoutKey: String? {
        return currentLayout?.layoutKey
    }

    /// The layout key configured for any Space of this display.
    func layoutKey(for space: Space) -> String? {
        let key = stateKey(for: space)
        guard let layouts = layoutsBySpaceUUID[key],
              let index = currentLayoutIndexBySpaceUUID[key],
              layouts.indices.contains(index) else {
            if let layoutKey = displayDefaults?.layoutKey {
                return layoutKey
            }

            return layoutProvider().first?.layoutKey
        }

        return layouts[index].layoutKey
    }

    /// The tiling switch configured for any Space of this display.
    func tilingEnabled(for space: Space) -> Bool {
        return tilingEnabledBySpaceUUID[stateKey(for: space)] ?? defaultTilingEnabled()
    }

    /// Selects a layout for a Space even when another Space is currently tracked.
    func setLayout(_ layoutKey: String, for space: Space) {
        let key = stateKey(for: space)
        var layouts = layoutsBySpaceUUID[key] ?? []

        if layouts.isEmpty {
            layouts = layoutProvider()
        }

        if !layouts.contains(where: { $0.layoutKey == layoutKey }) {
            guard let layout = LayoutType<Window>.layoutForKey(layoutKey) else {
                return
            }
            layouts.append(layout)
        }

        guard let index = layouts.firstIndex(where: { $0.layoutKey == layoutKey }) else {
            return
        }

        layoutsBySpaceUUID[key] = layouts
        currentLayoutIndexBySpaceUUID[key] = index
        // Selecting a layout implies tiling: keep the switch in sync so a
        // newly added window is laid out instead of silently ignored.
        tilingEnabledBySpaceUUID[key] = true

        if space == self.space {
            self.layouts = layouts
            setCurrentLayoutIndex(index)
            setNeedsReflow()
        }

        delegate?.screenManagerPersistentStateDidChange(self)
    }

    /// Sets the tiling switch for a Space even when another Space is tracked.
    func setTilingEnabled(_ enabled: Bool, for space: Space) {
        let key = stateKey(for: space)
        tilingEnabledBySpaceUUID[key] = enabled

        if space == self.space {
            setNeedsReflow()
        }

        delegate?.screenManagerPersistentStateDidChange(self)
    }

    func toggleTilingForCurrentDisplay() {
        guard let enabled = currentDisplayTilingEnabled else {
            return
        }

        setTilingEnabledForCurrentDisplay(!enabled)
    }

    func setTilingEnabledForCurrentDisplay(_ enabled: Bool) {
        let userSpaces = userSpacesForCurrentDisplay()
        if userSpaces.isEmpty, let space = space {
            tilingEnabledBySpaceUUID[stateKey(for: space)] = enabled
        } else {
            for space in userSpaces {
                tilingEnabledBySpaceUUID[stateKey(for: space)] = enabled
            }
        }

        if let displayID = screen?.screenID() {
            let defaults = displayDefaults
            userConfiguration.setDisplayDefaults(
                DisplayDefaults(tilingEnabled: enabled, layoutKey: defaults?.layoutKey),
                forDisplayID: displayID
            )
        }

        delegate?.screenManagerPersistentStateDidChange(self)
        setNeedsReflow()
    }

    private func userSpacesForCurrentDisplay() -> [Space] {
        guard let screen = screen else {
            return []
        }

        return spaceClient.spacesForScreen(screen, true) ?? []
    }

    /// Applies a display's configured defaults to the tracked Space.
    func applyDisplayDefaults(_ defaults: DisplayDefaults) {
        guard let space = space else {
            return
        }

        if let layoutKey = defaults.layoutKey {
            selectLayout(layoutKey)
        }

        tilingEnabledBySpaceUUID[stateKey(for: space)] = defaults.tilingEnabled
        delegate?.screenManagerPersistentStateDidChange(self)
        setNeedsReflow()
    }

    private var tilingEnabledForCurrentTarget: Bool {
        guard let space = space else {
            return userConfiguration.tilingEnabled
        }
        return userConfiguration.tilingEnabled && (tilingEnabledBySpaceUUID[stateKey(for: space)] ?? true)
    }

    func cycleLayoutForward() {
        guard !layouts.isEmpty else { return }
        setCurrentLayoutIndex((currentLayoutIndex + 1) % layouts.count)
        setNeedsReflow()
    }

    func cycleLayoutBackward() {
        guard !layouts.isEmpty else { return }
        setCurrentLayoutIndex((currentLayoutIndex == 0 ? layouts.count : currentLayoutIndex) - 1)
        setNeedsReflow()
    }

    func selectLayout(_ layoutString: String) {
        guard let layoutIndex = layouts.firstIndex(where: { $0.layoutKey == layoutString }) else {
            return
        }

        guard layoutIndex != currentLayoutIndex else {
            return
        }

        setCurrentLayoutIndex(layoutIndex)
        setNeedsReflow()
    }

    private func setCurrentLayoutIndex(_ index: Int, changingSpace: Bool = false) {
        guard (0..<layouts.count).contains(index) else {
            return
        }

        currentLayoutIndex = index

        if !changingSpace, let space = space {
            currentLayoutIndexBySpaceUUID[stateKey(for: space)] = index
            delegate?.screenManagerPersistentStateDidChange(self)
        }

        guard !changingSpace || userConfiguration.enablesLayoutHUDOnSpaceChange() else {
            return
        }

        DispatchQueue.main.async {
            self.displayLayoutHUD()
        }
    }

    func shrinkMainPane() {
        guard let panedLayout = currentLayout as? PanedLayout else {
            return
        }
        panedLayout.shrinkMainPane()
    }

    func expandMainPane() {
        guard let panedLayout = currentLayout as? PanedLayout else {
            return
        }
        panedLayout.expandMainPane()
    }

    func nextWindowIDCounterClockwise() -> Window.WindowID? {
        guard let layout = currentLayout as? StatefulLayout else {
            return nil
        }

        return layout.nextWindowIDCounterClockwise()
    }

    func nextWindowIDClockwise() -> Window.WindowID? {
        guard let statefulLayout = currentLayout as? StatefulLayout else {
            return nil
        }

        return statefulLayout.nextWindowIDClockwise()
    }

    func displayLayoutHUD() {
        guard userConfiguration.enablesLayoutHUD(), space?.isUserSpace == true else {
            return
        }

        let currentLayoutName = currentLayout.flatMap({ $0.layoutName }) ?? "None"
        let currentLayoutDescription = currentLayout?.layoutDescription ?? ""

        displayCustomHUD(title: currentLayoutName, description: currentLayoutDescription)
    }

    @objc func hideLayoutHUD(_ sender: AnyObject) {
        layoutNameWindowController.close()
    }

    func displayCustomHUD(title: String, description: String = "") {
        guard let screen = screen else {
            return
        }

        guard space?.isUserSpace == true else {
            return
        }

        defer {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideLayoutHUD(_:)), object: nil)
            perform(#selector(hideLayoutHUD(_:)), with: nil, afterDelay: 0.6)
        }

        guard let layoutNameWindow = layoutNameWindowController.window as? LayoutNameWindow else {
            return
        }

        // Use new displayNotification method with dynamic sizing
        layoutNameWindow.displayNotification(title: title, description: description)

        // Center the window after resizing
        let screenFrame = screen.frame()
        let screenCenter = CGPoint(x: screenFrame.midX, y: screenFrame.midY)
        let windowOrigin = CGPoint(
            x: screenCenter.x - layoutNameWindow.frame.width / 2.0,
            y: screenCenter.y - layoutNameWindow.frame.height / 2.0
        )
        layoutNameWindow.setFrameOrigin(NSPointFromCGPoint(windowOrigin))

        layoutNameWindowController.showWindow(self)
    }
}

extension ScreenManager: Comparable {
    static func < (lhs: ScreenManager<Delegate>, rhs: ScreenManager<Delegate>) -> Bool {
        guard let lhsScreen = lhs.screen, let rhsScreen = rhs.screen else {
            return false
        }

        let originX1 = lhsScreen.frameWithoutDockOrMenu().origin.x
        let originX2 = rhsScreen.frameWithoutDockOrMenu().origin.x

        return originX1 < originX2
    }
}
