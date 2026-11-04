//
//  AppDelegate.swift
//  Mon
//
//  Created by Ian Ynda-Hummel on 5/8/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import RxCocoa
import RxSwift
import ServiceManagement
import Silica
import SwiftyBeaver

struct LoginItemPresentation: Equatable {
    let title: String
    let state: NSControl.StateValue
    let isEnabled: Bool
    let guidance: String?

    init(status: SMAppService.Status) {
        switch status {
        case .enabled:
            self.init(title: "Start Mon on Login", state: .on, isEnabled: true, guidance: nil)
        case .notRegistered:
            self.init(title: "Start Mon on Login", state: .off, isEnabled: true, guidance: nil)
        case .requiresApproval:
            self.init(
                title: "Start Mon on Login (Approve in System Settings…)",
                state: .mixed,
                isEnabled: true,
                guidance: "macOS needs explicit approval. Open System Settings → General → Login Items and enable Amethyst."
            )
        case .notFound:
            self.init(
                title: "Start Mon on Login (Add in System Settings…)",
                state: .off,
                isEnabled: true,
                guidance: "macOS cannot register this copy of Mon automatically. Open System Settings → General → Login Items and add Mon manually."
            )
        @unknown default:
            self.init(
                title: "Start Mon on Login (Unknown Status)",
                state: .off,
                isEnabled: true,
                guidance: "macOS reported an unknown Login Items status. Check System Settings → General → Login Items."
            )
        }
    }

    private init(title: String, state: NSControl.StateValue, isEnabled: Bool, guidance: String?) {
        self.title = title
        self.state = state
        self.isEnabled = isEnabled
        self.guidance = guidance
    }

    var needsManualAction: Bool {
        return guidance != nil
    }
}

private struct StateEnvelope<State: Codable>: Codable {
    let version: Int
    let state: State
}

enum VersionedStateCodec {
    static let currentVersion = 1

    enum DecodeError: Error, Equatable {
        case unsupportedVersion(Int)
    }

    static func encode<State: Codable>(_ state: State, encoder: JSONEncoder = JSONEncoder()) throws -> Data {
        try encoder.encode(StateEnvelope(version: currentVersion, state: state))
    }

    static func decode<State: Codable>(_ type: State.Type, from data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> State {
        if let envelope = try? decoder.decode(StateEnvelope<State>.self, from: data) {
            guard envelope.version == currentVersion else {
                throw DecodeError.unsupportedVersion(envelope.version)
            }
            return envelope.state
        }

        return try decoder.decode(type, from: data)
    }
}

struct VersionedStatePersistence {
    let stateKey: String
    let backupKey: String

    func restore<State: Codable>(_ type: State.Type, from defaults: UserDefaults = .standard) throws -> State? {
        guard let data = defaults.data(forKey: stateKey) else {
            return nil
        }

        return try VersionedStateCodec.decode(type, from: data)
    }

    func save<State: Codable>(_ state: State, to defaults: UserDefaults = .standard) throws {
        if defaults.data(forKey: backupKey) == nil,
           let previousState = defaults.data(forKey: stateKey) {
            defaults.set(previousState, forKey: backupKey)
        }

        let encodedState = try VersionedStateCodec.encode(state)
        defaults.set(encodedState, forKey: stateKey)
    }

    func reset(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: stateKey)
        defaults.removeObject(forKey: backupKey)
    }
}

struct LoginItemMigrationNotice {
    let defaultsKey: String

    func shouldPresent(in defaults: UserDefaults = .standard) -> Bool {
        return !defaults.bool(forKey: defaultsKey)
    }

    func markPresented(in defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: defaultsKey)
    }
}

enum RuntimeStatusPresentation {
    static func degradedStatusTitles(
        accessibilityTrusted: Bool,
        spaceAvailability: SpaceCommandAvailability,
        layoutStateRestoreFailed: Bool = false,
        secureInputEnabled: Bool = false
    ) -> [String] {
        var titles: [String] = []

        if !accessibilityTrusted {
            titles.append("Accessibility permission is required for window management")
        }

        if let spaceStatusTitle = spaceAvailability.statusTitle {
            titles.append(spaceStatusTitle)
        }
        if layoutStateRestoreFailed {
            titles.append(LayoutStateRestorePresentation.failureTitle)
        }
        if secureInputEnabled {
            titles.append(SecureInputPresentation.statusTitle)
        }

        return titles
    }
}

enum LayoutStateRestorePresentation {
    static let failureTitle = "Saved layout state could not be restored; using default layouts"
}

struct CurrentSpaceTilingPresentation: Equatable {
    let title: String
    let isEnabled: Bool
    let isVisible: Bool

    init(isTilingEnabled: Bool?) {
        guard let isTilingEnabled = isTilingEnabled else {
            title = ""
            isEnabled = false
            isVisible = false
            return
        }

        if isTilingEnabled {
            title = "Disable Tiling for This Display & Space"
            isEnabled = true
            isVisible = true
        } else {
            title = "Enable Tiling for This Display & Space"
            isEnabled = true
            isVisible = true
        }
    }
}

enum SecureInputPresentation {
    static let statusTitle = "Secure Input is enabled; throw-to-Space is unavailable"
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static let windowManagerEncodingKey = "EncodedWindowManager"
    static let windowManagerEncodingBackupKey = "EncodedWindowManagerBackup"
    static let loginItemMigrationNoticeKey = "did-show-smappservice-migration-notice"
    static let windowManagerStatePersistence = VersionedStatePersistence(
        stateKey: windowManagerEncodingKey,
        backupKey: windowManagerEncodingBackupKey
    )
    static let loginItemMigrationNotice = LoginItemMigrationNotice(
        defaultsKey: loginItemMigrationNoticeKey
    )

    @IBOutlet var preferencesWindowController: PreferencesWindowController?

    var windowManager: WindowManager<SIApplication>?
    private var hotKeyManager: HotKeyManager<SIApplication>?
    fileprivate var statusItem: NSStatusItem?
    @IBOutlet var statusItemMenu: NSMenu?
    @IBOutlet var versionMenuItem: NSMenuItem?
    @IBOutlet var startAtLoginMenuItem: NSMenuItem?
    @IBOutlet var toggleGlobalTilingMenuItem: NSMenuItem?
    @IBOutlet var toggleCurrentSpaceTilingMenuItem: NSMenuItem?

    private var isFirstLaunch = true
    private var layoutStateRestoreFailed = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
            log.addDestination(ConsoleDestination())
        #endif

        if CommandLine.arguments.contains("--log") {
            let destination = ConsoleDestination()
            destination.useNSLog = true
            log.addDestination(destination)
        }

        log.info("Logging is enabled")
        log.debug("Debug logging is enabled")

        UserConfiguration.shared.delegate = self
        UserConfiguration.shared.load()
        UserConfiguration.shared.tilingEnabled = !UserConfiguration.shared.startWithTilingDisabled()

        presentLoginItemMigrationNoticeIfNecessary()

        preferencesWindowController?.window?.level = .floating

        if UserDefaults.standard.data(forKey: AppDelegate.windowManagerEncodingKey) != nil, UserConfiguration.shared.restoreLayoutsOnLaunch() {
            do {
                windowManager = try AppDelegate.windowManagerStatePersistence.restore(WindowManager<SIApplication>.self)
            } catch {
                layoutStateRestoreFailed = true
                log.error("Failed to restore layout state from UserDefaults key \(AppDelegate.windowManagerEncodingKey): \(error). Using default layouts without deleting saved state.")
            }
        }

        let resolvedWindowManager = windowManager ?? WindowManager(userConfiguration: UserConfiguration.shared)
        windowManager = resolvedWindowManager
        configureLayoutStatePersistence(for: resolvedWindowManager)
        hotKeyManager = HotKeyManager(userConfiguration: UserConfiguration.shared)

        hotKeyManager?.setUpWithWindowManager(resolvedWindowManager, configuration: UserConfiguration.shared, appDelegate: self)
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let version = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "unknown"
        let shortVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        let statusItemImage = NSImage(named: "icon-statusitem")
        statusItemImage?.isTemplate = true

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = statusItemImage
        statusItem?.menu = statusItemMenu

        let hideMenuBarIcon: Bool = UserConfiguration.shared.hideMenuBarIcon()
        statusItem?.isVisible = !hideMenuBarIcon

        versionMenuItem?.title = "Version \(shortVersion) (\(version))"
        toggleGlobalTilingMenuItem?.title = "Disable"

        refreshStartAtLoginMenuItem()
        refreshCurrentSpaceTilingMenuItem()

        // Set up status item menu delegate to refresh layouts when main menu is opened
        statusItemMenu?.delegate = self
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard !isFirstLaunch else {
            isFirstLaunch = false
            return
        }

        showPreferencesWindow(self)
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard let windowManager = windowManager else {
            return
        }

        do {
            try AppDelegate.windowManagerStatePersistence.save(windowManager)
        } catch {
            log.error("Failed to encode window manager: \(error)")
        }
    }

    @IBAction func toggleStartAtLogin(_ sender: AnyObject) {
        let service = SMAppService.mainApp

        do {
            switch service.status {
            case .enabled:
                try service.unregister()
            case .notRegistered:
                try service.register()
                if service.status == .requiresApproval {
                    presentLoginItemGuidance(for: LoginItemPresentation(status: service.status))
                }
            case .requiresApproval, .notFound:
                presentLoginItemGuidance(for: LoginItemPresentation(status: service.status))
            @unknown default:
                presentLoginItemGuidance(for: LoginItemPresentation(status: service.status))
            }
        } catch {
            log.error("Failed to change Start at Login registration: \(error)")
            presentLoginItemRegistrationFailure(error)
        }

        refreshStartAtLoginMenuItem()
    }

    private func presentLoginItemGuidance(for presentation: LoginItemPresentation) {
        guard let guidance = presentation.guidance else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = presentation.title
        alert.informativeText = guidance
        alert.addButton(withTitle: "Open Login Items")
        alert.addButton(withTitle: "Done")

        if alert.runModal() == .alertFirstButtonReturn {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private func presentLoginItemRegistrationFailure(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could not change Start at Login"
        alert.informativeText = """
        \(error.localizedDescription)

        You can add Mon manually in System Settings → General → Login Items.
        """
        alert.addButton(withTitle: "Open Login Items")
        alert.addButton(withTitle: "Done")

        if alert.runModal() == .alertFirstButtonReturn {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    @IBAction func toggleGlobalTiling(_ sender: AnyObject) {
        UserConfiguration.shared.tilingEnabled = !UserConfiguration.shared.tilingEnabled
        windowManager?.markAllScreensForReflow()
    }

    @IBAction func toggleCurrentSpaceTiling(_ sender: AnyObject) {
        screenManagerForMenuAction()?.toggleTilingForCurrentSpace()
        refreshCurrentSpaceTilingMenuItem()
    }

    @IBAction func resetLayouts(_ sender: AnyObject) {
        AppDelegate.windowManagerStatePersistence.reset()
        layoutStateRestoreFailed = false
        windowManager?.reset()
    }

    @IBAction func relaunch(_ sender: AnyObject) {
        AppManager.relaunch()
    }

    private func configureLayoutStatePersistence(for windowManager: WindowManager<SIApplication>) {
        windowManager.setPersistentStateChangeHandler { [weak windowManager] in
            guard let windowManager = windowManager else {
                return
            }

            do {
                try AppDelegate.windowManagerStatePersistence.save(windowManager)
            } catch {
                log.error("Failed to persist selected layout state: \(error)")
            }
        }
    }

    @IBAction func showPreferencesWindow(_ sender: AnyObject) {
        guard let isVisible = preferencesWindowController?.window?.isVisible, !isVisible else {
            return
        }

        preferencesWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)

        presentDotfileWarningIfNecessary()
    }

    private func refreshStartAtLoginMenuItem() {
        guard let menuItem = startAtLoginMenuItem else {
            return
        }

        let presentation = LoginItemPresentation(status: SMAppService.mainApp.status)
        menuItem.title = presentation.title
        menuItem.state = presentation.state
        menuItem.isEnabled = presentation.isEnabled
        menuItem.toolTip = presentation.guidance
    }

    private func refreshCurrentSpaceTilingMenuItem() {
        guard let menuItem = toggleCurrentSpaceTilingMenuItem else {
            return
        }

        let presentation = CurrentSpaceTilingPresentation(
            isTilingEnabled: screenManagerForMenuAction()?.currentSpaceTilingEnabled
        )
        menuItem.isHidden = !presentation.isVisible
        guard presentation.isVisible else {
            return
        }
        menuItem.title = presentation.title
        menuItem.isEnabled = presentation.isEnabled
    }

    private func presentLoginItemMigrationNoticeIfNecessary() {
        let notice = AppDelegate.loginItemMigrationNotice
        guard notice.shouldPresent() else {
            return
        }

        notice.markPresented()

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Start at Login must be enabled again"
        alert.informativeText = """
        Mon now uses the macOS Login Items service. Previous login item settings are not migrated.
        Enable Mon explicitly in the status menu or System Settings if you want it to start at login.
        """
        alert.addButton(withTitle: "Open Login Items")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private func presentDotfileWarningIfNecessary() {
        let shouldWarn = !UserDefaults.standard.bool(forKey: "disable-dotfile-conflict-warning")
        if shouldWarn && UserConfiguration.shared.hasCustomConfiguration() {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Warning"
            alert.informativeText = "You have a .amethyst file, which can override in-app preferences. You may encounter unexpected behavior."
            alert.showsSuppressionButton = true
            alert.runModal()

            if alert.suppressionButton?.state == .on {
                UserDefaults.standard.set(true, forKey: "disable-dotfile-conflict-warning")
            }
        }
    }

    /// Resolves the screen manager used by status-menu actions.
    ///
    /// The focused window may be unavailable (no Accessibility permission, or no
    /// focused window at all). In that case fall back to the screen under the
    /// mouse cursor, which is the screen the user clicked the menu bar on.
    private func screenManagerForMenuAction() -> ScreenManager<WindowManager<SIApplication>>? {
        guard let windowManager = windowManager else {
            return nil
        }

        if let focusedScreenManager = windowManager.focusedScreenManager() {
            return focusedScreenManager
        }

        let mouseLocation = NSEvent.mouseLocation
        if let nsScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return windowManager.screenManager(for: AMScreen(screen: nsScreen))
        }

        return nil
    }

    private static let runtimeStatusItemIdentifier = NSUserInterfaceItemIdentifier("runtime-status")

    private func updateRuntimeStatusItems() {
        guard let menu = statusItemMenu else {
            return
        }

        for existingItem in menu.items where existingItem.identifier == AppDelegate.runtimeStatusItemIdentifier {
            menu.removeItem(existingItem)
        }

        let spaceAvailability = windowManager?.windowTransitionCoordinator.spaceCommandAvailability() ?? .available
        let titles = RuntimeStatusPresentation.degradedStatusTitles(
            accessibilityTrusted: DebugInfo.isProcessTrusted(),
            spaceAvailability: spaceAvailability,
            layoutStateRestoreFailed: layoutStateRestoreFailed,
            secureInputEnabled: SpaceDragEventClient.cghid.isSecureInputEnabled()
        )

        for (index, title) in titles.enumerated() {
            let statusMenuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            statusMenuItem.identifier = AppDelegate.runtimeStatusItemIdentifier
            statusMenuItem.isEnabled = false
            menu.insertItem(statusMenuItem, at: index)
        }
    }

}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        windowManager?.preferencesDidClose()
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Refresh layouts menu when main status item menu is about to open
        if menu == statusItemMenu {
            updateRuntimeStatusItems()
            refreshCurrentSpaceTilingMenuItem()
            refreshStartAtLoginMenuItem()
        }
    }
}

extension AppDelegate: UserConfigurationDelegate {
    func configurationGlobalTilingDidChange(_ userConfiguration: UserConfiguration) {
        var statusItemImage: NSImage?
        if UserConfiguration.shared.tilingEnabled == true {
            statusItemImage = NSImage(named: "icon-statusitem")
            toggleGlobalTilingMenuItem?.title = "Disable Tiling"
        } else {
            statusItemImage = NSImage(named: "icon-statusitem-disabled")
            toggleGlobalTilingMenuItem?.title = "Enable Tiling"
        }
        statusItemImage?.isTemplate = true
        statusItem?.button?.image = statusItemImage
    }

    func configurationAccessibilityPermissionsDidChange(_ userConfiguration: UserConfiguration) {
        windowManager?.reevaluateWindows()
    }
}
