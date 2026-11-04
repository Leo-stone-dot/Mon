//
//  DebugInfo.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 2/24/20.
//  Copyright © 2020 Ian Ynda-Hummel. All rights reserved.
//

import ArgumentParser
import Carbon
import Cocoa
import Silica

struct Debug: ParsableCommand {
    static var configuration: CommandConfiguration = CommandConfiguration(
        abstract: "Generate diagnostic reports on system state.",
        subcommands: [Apps.self, Windows.self],
        defaultSubcommand: Windows.self
    )
}

struct DebugInfo {
    static func description(arguments: [String]) -> String {
        var infos = [
            "Version: \(version())",
            "OS version: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Runtime diagnostics:\n\(runtimeDiagnostics())",
            "Screens:\n\(screens())",
            "On-screen window bounds:\n\(onScreenWindowBounds())",
            "Configuration:\n\(config())"
        ]

        if arguments.contains("--include-apps") {
            infos.append("Manageable applications:\n\(applications())")
        }

        return infos.joined(separator: "\n\n")
    }

    static func version() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        return "\(shortVersion) (\(version))"
    }

    static func isProcessTrusted(accessibilityClient: AccessibilityClient = .system) -> Bool {
        return accessibilityClient.isProcessTrusted(false)
    }

    static func separateSpacesAreEnabled(
        appKitInitializer: () -> Void = { _ = NSApplication.shared },
        separateSpacesProvider: () -> Bool = { NSScreen.screensHaveSeparateSpaces }
    ) -> Bool {
        appKitInitializer()
        return separateSpacesProvider()
    }

    static func runtimeDiagnostics() -> String {
        return [
            "\tAccessibility trusted: \(isProcessTrusted())",
            "\tSecure Input enabled: \(IsSecureEventInputEnabled())",
            "\tSeparate Spaces: \(separateSpacesAreEnabled())",
            "\tSpace diagnostics: \(spaceDiagnostics())",
            "\tSpace contract: \(SpaceContractProbe.run(windowType: AXWindow.self).description)"
        ].joined(separator: "\n")
    }

    static func spaceDiagnostics() -> String {
        let allSpaces = CGSpacesInfo<AXWindow>.spacesForAllScreens()
        let userSpaces = CGSpacesInfo<AXWindow>.spacesForAllScreens(includeOnlyUserSpaces: true)
        let currentSpace = CGSpacesInfo<AXWindow>.currentFocusedSpace()

        let allSpacesDescription = allSpaces.map { spaces in
            let details = spaces.map { "\($0.id):\($0.type.rawValue):\($0.uuid.prefix(8))" }.joined(separator: ",")
            return "\(spaces.count) [id:type:uuid=\(details)]"
        } ?? "unavailable"
        let userSpacesDescription = userSpaces.map { "\($0.count)" } ?? "unavailable"

        let currentSpaceDescription: String
        if let currentSpace = currentSpace {
            currentSpaceDescription = "id=\(currentSpace.id), type=\(currentSpace.type.rawValue), uuid=\(currentSpace.uuid)"
        } else if !isProcessTrusted() {
            currentSpaceDescription = "unavailable (Accessibility permission is not granted, so no focused window can be resolved)"
        } else {
            currentSpaceDescription = "unavailable (no focused window)"
        }

        let perScreenDescriptions = NSScreen.screens.map { nsScreen -> String in
            let screen = AMScreen(screen: nsScreen)
            let spaces = CGSpacesInfo<AXWindow>.spacesForScreen(screen)
            let current = CGSpacesInfo<AXWindow>.currentSpaceForScreen(screen)
            let spaceDetails = spaces?.map { "\($0.id):\($0.type.rawValue)" }.joined(separator: ",") ?? "unavailable"
            let currentDetails = current.map { "\($0.id):\($0.type.rawValue)" } ?? "unavailable"
            return "screen \(screen.screenID() ?? "?") spaces=[\(spaceDetails)] current=\(currentDetails)"
        }.joined(separator: "\n\t\t")

        return "all=\(allSpacesDescription), user=\(userSpacesDescription), current=\(currentSpaceDescription)"
            + "\n\t\tper-screen:\n\t\t\(perScreenDescriptions)"
    }

    static func screens() -> String {
        return NSScreen.screens.map { "\t\($0.frame) [\($0.frameIncludingDockAndMenu())]" }.joined(separator: "\n")
    }

    static func applications() -> String {
        return NSWorkspace.shared.runningApplications
            .filter { $0.isManageable == .manageable }
            .map { "\t\($0.localizedName ?? "<unknown name>") (\($0.bundleIdentifier ?? "<unknown bundle id>"))" }
            .joined(separator: "\n")
    }

    static func onScreenWindowBounds() -> String {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return "\tunavailable"
        }

        let descriptions = windowList.compactMap { windowInfo -> String? in
            guard let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                  let boundsDictionary = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary)
            else {
                return nil
            }

            let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else {
                return nil
            }

            return "\t\(ownerName): \(bounds)"
        }

        return descriptions.isEmpty ? "\tnone" : descriptions.joined(separator: "\n")
    }

    static func config() -> String {
        return UserDefaults.standard.dictionaryRepresentation()
            .filter { ConfigurationKey(rawValue: $0.key) != nil }
            .map { "\($0): \($1)" }.joined(separator: "\n")
    }
}
