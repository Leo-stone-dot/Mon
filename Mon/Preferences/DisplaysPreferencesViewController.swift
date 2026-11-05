//
//  DisplaysPreferencesViewController.swift
//  Mon
//

import AppKit
import Foundation
import Silica

/// Settings pane that lists the connected displays and lets people choose the
/// layout and tiling behavior of each desktop, plus the defaults for new
/// desktops on each display.
final class DisplaysPreferencesViewController: NSViewController {
    /// Keeps scroll-view content anchored to the visual top when its intrinsic
    /// height is shorter than the viewport.
    private final class FlippedDocumentView: NSView {
        override var isFlipped: Bool { true }
    }

    private struct DisplayEntry {
        let displayID: String
        let name: String
        let resolution: String
        let desktops: [Space]
        let currentSpaceID: CGSSpaceID?
        let screenManager: ScreenManager<WindowManager<SIApplication>>?
    }

    private let stackView = NSStackView()
    private let emptyLabel = NSTextField(labelWithString: "No displays are available.")
    private var configHandlers: [AnyObject] = []
    private var spaceChangeObservers: [NSObjectProtocol] = []

    private enum Metrics {
        static let paneWidth: CGFloat = 548
        static let contentWidth: CGFloat = 500
        static let labelColumn: CGFloat = 150
        /// Minimum width that keeps the longest built-in layout name readable.
        static let minimumControlWidth: CGFloat = 180
        static let rowSpacing: CGFloat = 8
        static let sectionSpacing: CGFloat = 16
    }

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        let documentView = FlippedDocumentView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = Metrics.sectionSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stackView)

        let view = NSView(frame: NSRect(x: 0, y: 0, width: Metrics.paneWidth, height: 520))
        view.addSubview(scrollView)
        self.view = view

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            stackView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 20),
            stackView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -20)
        ])
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        reloadDisplays()
        observeSpaceChanges()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        removeSpaceChangeObservers()
    }

    private var windowManager: WindowManager<SIApplication>? {
        return (NSApplication.shared.delegate as? AppDelegate)?.windowManager
    }

    /// Keeps the desktop list current while the pane stays open.
    private func observeSpaceChanges() {
        removeSpaceChangeObservers()

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        spaceChangeObservers.append(
            workspaceCenter.addObserver(
                forName: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.reloadDisplays()
            }
        )
        spaceChangeObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.reloadDisplays()
            }
        )
        spaceChangeObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.reloadDisplays()
            }
        )
    }

    private func removeSpaceChangeObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for observer in spaceChangeObservers {
            workspaceCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
        spaceChangeObservers.removeAll()
    }

    private func reloadDisplays() {
        configHandlers.removeAll()
        stackView.arrangedSubviews.forEach { subview in
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        let entries = displayEntries()
        guard !entries.isEmpty else {
            stackView.addArrangedSubview(emptyLabel)
            return
        }

        for entry in entries {
            stackView.addArrangedSubview(displaySection(for: entry))
        }
    }

    private func displayEntries() -> [DisplayEntry] {
        return NSScreen.screens.compactMap { nsScreen -> DisplayEntry? in
            let screen = AMScreen(screen: nsScreen)
            guard let displayID = screen.screenID() else {
                return nil
            }

            let spaces = CGSpacesInfo<AXWindow>.spacesForScreen(screen) ?? []
            let currentSpace = CGSpacesInfo<AXWindow>.currentSpaceForScreen(screen)
            let resolution = "\(Int(nsScreen.frame.width)) × \(Int(nsScreen.frame.height))"

            return DisplayEntry(
                displayID: displayID,
                name: displayName(for: nsScreen),
                resolution: resolution,
                desktops: spaces.filter { $0.isUserSpace },
                currentSpaceID: currentSpace?.id,
                screenManager: windowManager?.screenManager(for: screen)
            )
        }
    }

    private func displayName(for screen: NSScreen) -> String {
        let localizedName = screen.localizedName
        return localizedName.isEmpty ? "Display" : localizedName
    }

    private func displaySection(for entry: DisplayEntry) -> NSView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 8
        section.translatesAutoresizingMaskIntoConstraints = false

        section.addArrangedSubview(displayHeader(for: entry))

        if entry.desktops.isEmpty {
            let label = NSTextField(labelWithString: "No desktops are available.")
            label.textColor = .secondaryLabelColor
            section.addArrangedSubview(label)
        } else {
            for (offset, space) in entry.desktops.enumerated() {
                section.addArrangedSubview(desktopRow(for: space, number: offset + 1, entry: entry))
            }
        }

        section.addArrangedSubview(defaultsRow(for: entry))

        return section
    }

    private func displayHeader(for entry: DisplayEntry) -> NSView {
        let title = NSTextField(labelWithString: entry.name)
        title.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)

        let subtitle = NSTextField(labelWithString: entry.resolution)
        subtitle.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        subtitle.textColor = .secondaryLabelColor

        let text = NSStackView(views: [title, subtitle])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 1

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "display", accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let header = NSStackView(views: [icon, text])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8

        return header
    }

    private func desktopRow(for space: Space, number: Int, entry: DisplayEntry) -> NSView {
        let name = NSTextField(labelWithString: "Desktop \(number)")
        name.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)

        let nameStack = NSStackView(views: [name])
        nameStack.orientation = .horizontal
        nameStack.alignment = .centerY
        nameStack.spacing = 6

        if space.id == entry.currentSpaceID {
            let current = NSTextField(labelWithString: "Current")
            current.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            current.textColor = .tertiaryLabelColor
            nameStack.addArrangedSubview(current)
        }

        let layoutPopup = layoutPopUpButton()
        if let layoutKey = entry.screenManager?.layoutKey(for: space),
           let item = layoutPopup.itemArray.first(where: { $0.representedObject as? String == layoutKey }) {
            layoutPopup.select(item)
        }

        let tilingCheckbox = NSButton(checkboxWithTitle: "Tiling", target: nil, action: nil)
        tilingCheckbox.state = (entry.screenManager?.tilingEnabled(for: space) ?? false) ? .on : .off

        let handler = SpaceConfigurationHandler(
            setLayout: { entry.screenManager?.setLayout($0, for: space) },
            setTilingEnabled: { entry.screenManager?.setTilingEnabled($0, for: space) }
        )
        handler.popup = layoutPopup
        handler.checkbox = tilingCheckbox
        layoutPopup.target = handler
        layoutPopup.action = #selector(SpaceConfigurationHandler.layoutChanged(_:))
        tilingCheckbox.target = handler
        tilingCheckbox.action = #selector(SpaceConfigurationHandler.tilingChanged(_:))
        configHandlers.append(handler)

        return controlRow(nameView: nameStack, popup: layoutPopup, checkbox: tilingCheckbox)
    }

    private func defaultsRow(for entry: DisplayEntry) -> NSView {
        let configuration = UserConfiguration.shared
        let configuredDefaults = configuration.displayDefaults(forDisplayID: entry.displayID)

        let caption = NSTextField(labelWithString: "New desktops")
        caption.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        caption.textColor = .secondaryLabelColor

        let layoutPopup = layoutPopUpButton(includeNoDefault: true)
        if let layoutKey = configuredDefaults?.layoutKey,
           let item = layoutPopup.itemArray.first(where: { $0.representedObject as? String == layoutKey }) {
            layoutPopup.select(item)
        } else {
            layoutPopup.selectItem(at: 0)
        }

        let tilingCheckbox = NSButton(checkboxWithTitle: "Tiling", target: nil, action: nil)
        tilingCheckbox.state = (configuredDefaults?.tilingEnabled ?? false) ? .on : .off

        let displayID = entry.displayID
        let changeHandler = DisplayDefaultsChangeHandler { defaults in
            configuration.setDisplayDefaults(defaults, forDisplayID: displayID)
        }
        let handler = DisplayDefaultsHandler(onChange: changeHandler.handle)

        handler.popup = layoutPopup
        handler.checkbox = tilingCheckbox
        layoutPopup.target = handler
        layoutPopup.action = #selector(DisplayDefaultsHandler.layoutChanged(_:))
        tilingCheckbox.target = handler
        tilingCheckbox.action = #selector(DisplayDefaultsHandler.tilingChanged(_:))
        configHandlers.append(handler)

        let row = controlRow(nameView: caption, popup: layoutPopup, checkbox: tilingCheckbox)
        row.setAccessibilityLabel("Defaults for new desktops")
        return row
    }

    private func controlRow(nameView: NSView, popup: NSPopUpButton, checkbox: NSButton) -> NSView {
        nameView.translatesAutoresizingMaskIntoConstraints = false
        nameView.setContentHuggingPriority(.required, for: .horizontal)
        nameView.widthAnchor.constraint(equalToConstant: Metrics.labelColumn).isActive = true

        // Let the layout popup absorb the row's spare width instead of being
        // pinned to a fixed width that clips longer layout names.
        popup.setContentHuggingPriority(.defaultLow, for: .horizontal)
        popup.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        popup.widthAnchor.constraint(greaterThanOrEqualToConstant: Metrics.minimumControlWidth).isActive = true
        popup.toolTip = popup.titleOfSelectedItem

        checkbox.setContentHuggingPriority(.required, for: .horizontal)

        let row = NSStackView(views: [nameView, popup, checkbox])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = Metrics.rowSpacing

        row.widthAnchor.constraint(equalToConstant: Metrics.contentWidth).isActive = true

        return row
    }

    private func layoutPopUpButton(includeNoDefault: Bool = false) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)

        if includeNoDefault {
            popup.addItem(withTitle: "No default")
            popup.lastItem?.representedObject = nil
        }

        for (layoutKey, layoutName) in LayoutType<AXWindow>.availableLayoutStrings() {
            popup.addItem(withTitle: layoutName)
            popup.lastItem?.representedObject = layoutKey
        }

        return popup
    }
}

/// Applies a layout or tiling change to one desktop Space.
final class SpaceConfigurationHandler: NSObject {
    private let setLayout: (String) -> Void
    private let setTilingEnabled: (Bool) -> Void
    weak var popup: NSPopUpButton?
    weak var checkbox: NSButton?

    init(setLayout: @escaping (String) -> Void, setTilingEnabled: @escaping (Bool) -> Void) {
        self.setLayout = setLayout
        self.setTilingEnabled = setTilingEnabled
    }

    @objc func layoutChanged(_ sender: NSPopUpButton) {
        sender.toolTip = sender.titleOfSelectedItem
        guard let layoutKey = sender.selectedItem?.representedObject as? String else {
            return
        }

        setLayout(layoutKey)
        // Selecting a layout enables tiling for this desktop.
        checkbox?.state = .on
    }

    @objc func tilingChanged(_ sender: NSButton) {
        setTilingEnabled(sender.state == .on)
    }
}

/// Persists defaults for desktops subsequently created on a display.
struct DisplayDefaultsChangeHandler {
    let persist: (DisplayDefaults) -> Void

    func handle(tilingEnabled: Bool, layoutKey: String?) {
        persist(DisplayDefaults(tilingEnabled: tilingEnabled, layoutKey: layoutKey))
    }
}

private final class DisplayDefaultsHandler: NSObject {
    private let onChange: (_ tilingEnabled: Bool, _ layoutKey: String?) -> Void
    weak var popup: NSPopUpButton?
    weak var checkbox: NSButton?

    init(onChange: @escaping (_ tilingEnabled: Bool, _ layoutKey: String?) -> Void) {
        self.onChange = onChange
    }

    @objc func layoutChanged(_ sender: NSPopUpButton) {
        sender.toolTip = sender.titleOfSelectedItem
        onChange(checkbox?.state == .on, sender.selectedItem?.representedObject as? String)
    }

    @objc func tilingChanged(_ sender: NSButton) {
        onChange(sender.state == .on, popup?.selectedItem?.representedObject as? String)
    }
}
