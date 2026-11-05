//
//  LayoutManager.swift
//  Mon
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation

extension FileManager {
    func layoutsDirectory() throws -> URL {
        let applicationSupportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let layoutsDirectory = applicationSupportDirectory
            .appendingPathComponent("Mon", isDirectory: true)
            .appendingPathComponent("Layouts", isDirectory: true)

        if !FileManager.default.fileExists(atPath: layoutsDirectory.path, isDirectory: nil) {
            try FileManager.default.createDirectory(
                at: layoutsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        return layoutsDirectory
    }

    func layoutFile(key: String) throws -> URL {
        let layoutsDirectory = try self.layoutsDirectory()
        return layoutsDirectory.appendingPathComponent("\(key).js")
    }
}

enum LayoutType<Window: WindowType> {
    enum Error: Swift.Error {
        case unknownLayout
    }

    case tall
    case tallRight
    case wide
    case twoPane
    case twoPaneRight
    case threeColumnLeft
    case threeColumnMiddle
    case threeColumnRight
    case fourColumnLeft
    case fourColumnRight
    case fullscreen
    case column
    case row
    case floating
    case widescreenTallLeft
    case widescreenTallRight
    case binarySpacePartitioning

    case custom(key: String)

    static var standardLayouts: [LayoutType<Window>] {
        return [
            .tall,
            .tallRight,
            .wide,
            .twoPane,
            .twoPaneRight,
            .threeColumnLeft,
            .threeColumnMiddle,
            .threeColumnRight,
            .fourColumnLeft,
            .fourColumnRight,
            .fullscreen,
            .column,
            .row,
            .floating,
            .widescreenTallLeft,
            .widescreenTallRight,
            .binarySpacePartitioning
        ]
    }

    var key: String {
        switch self {
        case .tall:
            return "tall"
        case .tallRight:
            return "tall-right"
        case .wide:
            return "wide"
        case .twoPane:
            return "two-pane"
        case .twoPaneRight:
            return "two-pane-right"
        case .threeColumnLeft:
            return "3column-left"
        case .threeColumnMiddle:
            return "middle-wide"
        case .threeColumnRight:
            return "3column-right"
        case .fourColumnLeft:
            return "4column-left"
        case .fourColumnRight:
            return "4column-right"
        case .fullscreen:
            return "fullscreen"
        case .column:
            return "column"
        case .row:
            return "row"
        case .floating:
            return "floating"
        case .widescreenTallLeft:
            return "widescreen-tall"
        case .widescreenTallRight:
            return "widescreen-tall-right"
        case .binarySpacePartitioning:
            return "bsp"
        case .custom(let key):
            return key
        }
    }

    var layoutClass: Layout<Window>.Type {
        switch self {
        case .tall:
            return TallLayout<Window>.self
        case .tallRight:
            return TallRightLayout<Window>.self
        case .wide:
            return WideLayout<Window>.self
        case .twoPane:
            return TwoPaneLayout<Window>.self
        case .twoPaneRight:
            return TwoPaneRightLayout<Window>.self
        case .threeColumnLeft:
            return ThreeColumnLeftLayout<Window>.self
        case .threeColumnMiddle:
            return ThreeColumnMiddleLayout<Window>.self
        case .threeColumnRight:
            return ThreeColumnRightLayout<Window>.self
        case .fourColumnLeft:
            return FourColumnLeftLayout<Window>.self
        case .fourColumnRight:
            return FourColumnRightLayout<Window>.self
        case .fullscreen:
            return FullscreenLayout<Window>.self
        case .column:
            return ColumnLayout<Window>.self
        case .row:
            return RowLayout<Window>.self
        case .floating:
            return FloatingLayout<Window>.self
        case .widescreenTallLeft:
            return WidescreenTallLayoutLeft<Window>.self
        case .widescreenTallRight:
            return WidescreenTallLayoutRight<Window>.self
        case .binarySpacePartitioning:
            return BinarySpacePartitioningLayout<Window>.self
        case .custom:
            return CustomLayout<Window>.self
        }
    }

    static func from(key: String) -> LayoutType<Window> {
        switch key {
        case "tall":
            return .tall
        case "tall-right":
            return .tallRight
        case "wide":
            return .wide
        case "two-pane":
            return .twoPane
        case "two-pane-right":
            return .twoPaneRight
        case "3column-left":
            return .threeColumnLeft
        case "middle-wide":
            return .threeColumnMiddle
        case "3column-right":
            return .threeColumnRight
        case "4column-left":
            return .fourColumnLeft
        case "4column-right":
            return .fourColumnRight
        case "fullscreen":
            return .fullscreen
        case "column":
            return .column
        case "row":
            return .row
        case "floating":
            return .floating
        case "widescreen-tall":
            return .widescreenTallLeft
        case "widescreen-tall-right":
            return .widescreenTallRight
        case "bsp":
            return .binarySpacePartitioning
        default:
            return .custom(key: key)
        }
    }

    static func layoutForKey(_ layoutKey: String, layoutsDirectory: URL? = nil) -> Layout<Window>? {
        let type = LayoutType<Window>.from(key: layoutKey)

        guard case .custom = type else {
            return type.layoutClass.init()
        }

        do {
            let directory = try layoutsDirectory ?? FileManager.default.layoutsDirectory()
            let layoutFile = directory.appendingPathComponent("\(layoutKey).js")
            guard FileManager.default.fileExists(atPath: layoutFile.path) else {
                return nil
            }

            let layout = CustomLayout<Window>(key: layoutKey, fileURL: layoutFile)
            guard layout.validationError == nil else {
                log.error("Invalid custom layout \(layoutKey): \(layout.validationError ?? "unknown error")")
                return nil
            }
            return layout
        } catch {
            log.error("Failed to load custom layout \(layoutKey): \(error)")
            return nil
        }
    }

    static func layoutNameForKey(_ layoutKey: String, layoutsDirectory: URL? = nil) -> String? {
        let type = LayoutType<Window>.from(key: layoutKey)

        guard case .custom = type else {
            return type.layoutClass.layoutName
        }

        return layoutForKey(layoutKey, layoutsDirectory: layoutsDirectory)?.layoutName
    }

    static func standardLayoutClasses() -> [Layout<Window>.Type] {
        return standardLayouts.map { $0.layoutClass }
    }

    /// All layouts available to every desktop. Built-ins keep their declared
    /// order; valid custom layouts follow in stable key order.
    static func availableLayouts(layoutsDirectory: URL? = nil) -> [Layout<Window>] {
        var layouts = standardLayouts.map { $0.layoutClass.init() }
        let builtInKeys = Set(layouts.map { $0.layoutKey })

        do {
            let directory = try layoutsDirectory ?? FileManager.default.layoutsDirectory()
            let customKeys = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: []
            )
            .filter { $0.pathExtension == "js" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { !builtInKeys.contains($0) }
            .sorted()

            let customLayouts = customKeys.compactMap {
                layoutForKey($0, layoutsDirectory: directory) as? CustomLayout<Window>
            }
            let customByKey = Dictionary(uniqueKeysWithValues: customLayouts.map { ($0.layoutKey, $0) })
            let allKeys = builtInKeys.union(customByKey.keys)
            var invalidExtensionKeys: Set<String> = []

            func validateExtensionChain(from key: String, path: [String]) -> Bool {
                guard let layout = customByKey[key], let target = layout.extendedLayoutKey else {
                    return true
                }
                guard allKeys.contains(target), !path.contains(target) else {
                    return false
                }
                guard customByKey[target] != nil else {
                    return true
                }
                return validateExtensionChain(from: target, path: path + [target])
            }

            for layout in customLayouts where !validateExtensionChain(from: layout.layoutKey, path: [layout.layoutKey]) {
                invalidExtensionKeys.insert(layout.layoutKey)
                log.error("Invalid custom layout extension chain for \(layout.layoutKey)")
            }

            let acceptedCustomLayouts = customLayouts.filter { !invalidExtensionKeys.contains($0.layoutKey) }
            let acceptedByKey = Dictionary(uniqueKeysWithValues: acceptedCustomLayouts.map { ($0.layoutKey, $0) })
            let builtInsByKey = Dictionary(uniqueKeysWithValues: layouts.map { ($0.layoutKey, $0) })
            for layout in acceptedCustomLayouts {
                if let target = layout.extendedLayoutKey {
                    layout.setResolvedExtension(builtInsByKey[target] ?? acceptedByKey[target])
                }
            }
            layouts.append(contentsOf: acceptedCustomLayouts)
        } catch {
            log.error("Failed to enumerate custom layouts: \(error)")
        }

        return layouts
    }

    static func availableLayoutStrings(layoutsDirectory: URL? = nil) -> [(key: String, name: String)] {
        return availableLayouts(layoutsDirectory: layoutsDirectory).map { ($0.layoutKey, $0.layoutName) }
    }

    static func encoded(layout: Layout<Window>) throws -> Data {
        return try JSONEncoder().encode(layout)
    }

    static func decoded(data: Data, key: String) throws -> Layout<Window> {
        let layoutType = LayoutType<Window>.from(key: key)
        let decoder = JSONDecoder()
        return try decoder.decode(layoutType.layoutClass, from: data)
    }
}
