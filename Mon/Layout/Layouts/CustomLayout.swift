//
//  CustomLayout.swift
//  Mon
//
//  Created by Ian Ynda-Hummel on 7/2/21.
//  Copyright © 2021 Ian Ynda-Hummel. All rights reserved.
//

import CommonCrypto
import Foundation
import JavaScriptCore

private struct JSWindow<Window: WindowType> {
    let id: String
    let window: LayoutWindow<Window>
}

private extension JSValue {
    func finiteNumber(forProperty property: String) -> Double? {
        guard let value = objectForKeyedSubscript(property), value.isNumber else {
            return nil
        }
        let number = value.toDouble()
        return number.isFinite ? number : nil
    }
}

private enum LayoutExtension<Window: WindowType> {
    case none
    case layout(Layout<Window>)
}

class CustomLayout<Window: WindowType>: StatefulLayout<Window>, PanedLayout {
    typealias WindowID = Window.WindowID

    private enum CodingKeys: String, CodingKey {
        case key
        case fileURL
    }

    override static var layoutName: String { return "Custom" }
    override static var layoutKey: String { return "custom" }

    override var layoutKey: String {
        return key
    }

    override var layoutName: String {
        return layout?.objectForKeyedSubscript("name").toString() ?? layoutKey
    }

    var mainPaneRatio: CGFloat { return 1.0 }
    var mainPaneCount: Int { return 1 }

    private let key: String
    private let fileURL: URL
    private var capturedException: String?

    private lazy var context: JSContext? = {
        guard let context = JSContext() else {
            log.error("Failed to create JavaScript context for custom layout at \(self.fileURL.path)")
            return nil
        }

        context.exceptionHandler = { [weak self] (_: JSContext!, value: JSValue!) in
            let name = value.objectForKeyedSubscript("name").toString() ?? "JavaScriptError"
            let message = value.objectForKeyedSubscript("message").toString() ?? "Unknown JavaScript error"
            let stack = value.objectForKeyedSubscript("stack").toString() ?? ""
            let diagnostic = "\(name): \(message)\n\(stack)"
            self?.capturedException = diagnostic
            log.error(diagnostic)
        }

        context.evaluateScript("var console = { log: function(message) { _consoleLog(message) } }")

        let consoleLog: @convention(block) (String) -> Void = { message in
            log.debug(message)
        }
        context.setObject(unsafeBitCast(consoleLog, to: AnyObject.self), forKeyedSubscript: "_consoleLog" as (NSCopying & NSObjectProtocol))

        do {
            context.evaluateScript(try String(contentsOf: self.fileURL, encoding: .utf8))
        } catch {
            log.error("Failed to load custom layout at \(self.fileURL.path): \(error)")
            return nil
        }

        context.evaluateScript("""
        function sanitizeArguments(fn) {
            return function(...args) {
                const sanitizedArgs = args.map(arg => !!arg ? JSON.parse(JSON.stringify(arg)) : undefined);
                return fn(...sanitizedArgs);
            };
        }

        function monIsCallable(value) {
            return typeof value === "function";
        }

        function monIsPlainObject(value) {
            return value !== null && typeof value === "object" && !Array.isArray(value);
        }

        function monOwnKeys(value) {
            return Object.keys(value);
        }

        function normalizedLayout() {
            const l = layout();
            if (l !== null && typeof l === "object" && monIsCallable(l.getFrameAssignments)) {
                l.getFrameAssignments = sanitizeArguments(l.getFrameAssignments);
            }
            return l;
        }
        """)

        return context
    }()

    private func isCallable(_ value: JSValue) -> Bool {
        return context?.objectForKeyedSubscript("monIsCallable")?.call(withArguments: [value]).toBool() ?? false
    }

    private func isPlainObject(_ value: JSValue) -> Bool {
        return context?.objectForKeyedSubscript("monIsPlainObject")?.call(withArguments: [value]).toBool() ?? false
    }

    private lazy var layout: JSValue? = {
        capturedException = nil
        let value = self.context?.objectForKeyedSubscript("normalizedLayout")?.call(withArguments: [])
        guard capturedException == nil, let value, isPlainObject(value) else {
            return nil
        }
        return value
    }()

    var extendedLayoutKey: String? {
        guard let value = layout?.objectForKeyedSubscript("extends"), value.isString else {
            return nil
        }
        return value.toString()
    }

    /// A stable explanation when a custom layout cannot enter the catalog.
    var validationError: String? {
        guard context != nil else {
            return capturedException ?? "The JavaScript context could not be created or the file could not be read"
        }
        guard let layout else {
            return capturedException ?? "layout() must return an object"
        }
        let name = layout.objectForKeyedSubscript("name")
        if let name, !name.isUndefined, !name.isNull {
            guard name.isString, !(name.toString() ?? "").isEmpty else {
                return "name must be a non-empty string"
            }
        }
        guard let getAssignments = layout.objectForKeyedSubscript("getFrameAssignments"), isCallable(getAssignments) else {
            return "getFrameAssignments must be a function"
        }
        if let initialState = layout.objectForKeyedSubscript("initialState"),
           !initialState.isUndefined,
           !initialState.isNull,
           !isPlainObject(initialState) {
            return "initialState must be an object"
        }
        if let commands = layout.objectForKeyedSubscript("commands"),
           !commands.isUndefined,
           !commands.isNull {
            guard isPlainObject(commands),
                  let commandKeys = context?.objectForKeyedSubscript("monOwnKeys")?
                    .call(withArguments: [commands]).toArray() as? [String] else {
                return "commands must be an object"
            }
            for commandKey in commandKeys {
                guard let command = commands.objectForKeyedSubscript(commandKey), isPlainObject(command),
                      let updateState = command.objectForKeyedSubscript("updateState"), isCallable(updateState) else {
                    return "commands.\(commandKey).updateState must be a function"
                }
                if let description = command.objectForKeyedSubscript("description"),
                   !description.isUndefined,
                   !description.isNull,
                   !description.isString {
                    return "commands.\(commandKey).description must be a string"
                }
            }
        }
        for hook in ["updateWithChange", "recommendMainPaneRatio"] {
            if let value = layout.objectForKeyedSubscript(hook), !value.isUndefined, !value.isNull, !isCallable(value) {
                return "\(hook) must be a function"
            }
        }
        if let extendedKey = layout.objectForKeyedSubscript("extends"), !extendedKey.isUndefined, !extendedKey.isNull {
            guard extendedKey.isString, let value = extendedKey.toString(), !value.isEmpty, value != key else {
                return "extends must name another layout"
            }
        }
        return nil
    }

    private lazy var state: JSValue? = {
        return self.layout?.objectForKeyedSubscript("initialState")
    }()

    private lazy var commands: JSValue? = {
        return self.layout?.objectForKeyedSubscript("commands")
    }()

    private var resolvedLayoutExtension: LayoutExtension<Window> = .none

    func setResolvedExtension(_ layout: Layout<Window>?) {
        resolvedLayoutExtension = layout.map(LayoutExtension.layout) ?? .none
    }

    private func resolveExtensionIfNecessary() -> LayoutExtension<Window> {
        if case .layout = resolvedLayoutExtension {
            return resolvedLayoutExtension
        }
        guard let target = extendedLayoutKey else {
            return .none
        }
        guard case .custom = LayoutType<Window>.from(key: target) else {
            return LayoutExtension.layout(LayoutType<Window>.from(key: target).layoutClass.init())
        }
        return .none
    }

    required init() {
        fatalError("must be constructed with a file")
    }

    required init(key: String, fileURL: URL) {
        self.key = key
        self.fileURL = fileURL
        super.init()
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try values.decode(String.self, forKey: .key)
        self.fileURL = try values.decode(URL.self, forKey: .fileURL)
        super.init()
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(fileURL, forKey: .fileURL)
    }

    private func extendedFrameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        switch resolveExtensionIfNecessary() {
        case .none:
            return nil
        case .layout(let layout):
            return layout.frameAssignments(windowSet, on: screen)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        let windows = windowSet.windows

        guard !windows.isEmpty else {
            return []
        }

        let screenFrame = screen.adjustedFrame()
        guard let context = self.context, let jsScreenFrameArg = JSValue(rect: screenFrame, in: context) else {
            log.error("CustomLayout: JS context unavailable for layout \(self.key)")
            return nil
        }
        let jsWindows: [WindowID: JSWindow<Window>] = windows.reduce([:]) { partialResult, layoutWindow in
            let id = idHash(forWindowID: layoutWindow.id) ?? UUID().uuidString
            let window = JSWindow<Window>(id: id, window: layoutWindow)
            return partialResult.merging([layoutWindow.id: window]) { current, _ in return current }
        }
        let jsWindowsArg = windows.compactMap { window -> [String: Any?]? in
            guard let jsWindow = jsWindows[window.id] else {
                return nil
            }
            return [
                "id": jsWindow.id,
                "frame": JSValue(rect: jsWindow.window.frame, in: context),
                "isFocused": jsWindow.window.isFocused
            ]
        }

        let extendedFrames: [[String: Any?]]? = extendedFrameAssignments(windowSet, on: screen)?.compactMap { frameAssignmentOperation in
            let frameAssignment = frameAssignmentOperation.frameAssignment
            guard let jsWindow = jsWindows[frameAssignment.window.id] else {
                return nil
            }
            return [
                "id": jsWindow.id,
                "frame": JSValue(rect: frameAssignment.frame, in: context),
                "isFocused": jsWindow.window.isFocused
            ]
        }
        guard let undefinedValue = JSValue(undefinedIn: context) else {
            log.error("CustomLayout: failed to create undefined value for \(key)")
            return nil
        }
        let args: [Any] = [
            jsWindowsArg,
            jsScreenFrameArg,
            state ?? undefinedValue,
            extendedFrames ?? undefinedValue
        ]

        guard let getAssignments = layout?.objectForKeyedSubscript("getFrameAssignments"), isCallable(getAssignments) else {
            log.error("CustomLayout \(key): getFrameAssignments is unavailable")
            return nil
        }

        capturedException = nil
        guard let assignments = getAssignments.call(withArguments: args),
              capturedException == nil,
              isPlainObject(assignments) else {
            log.error("CustomLayout \(key): getFrameAssignments must return an object")
            return nil
        }

        let assignmentKeys = context.objectForKeyedSubscript("monOwnKeys")?
            .call(withArguments: [assignments])
            .toArray() as? [String]
        let expectedKeys = Set(jsWindows.values.map { $0.id })
        guard assignmentKeys.map(Set.init) == expectedKeys else {
            log.error("CustomLayout \(key): assignments must contain exactly the current window IDs")
            return nil
        }

        var operations: [FrameAssignmentOperation<Window>] = []
        for window in windows {
            guard let jsWindow = jsWindows[window.id],
                  let frame = assignments.objectForKeyedSubscript(jsWindow.id),
                  !frame.isUndefined,
                  !frame.isNull,
                  isPlainObject(frame),
                  let originX = frame.finiteNumber(forProperty: "x"),
                  let originY = frame.finiteNumber(forProperty: "y"),
                  let width = frame.finiteNumber(forProperty: "width"),
                  let height = frame.finiteNumber(forProperty: "height") else {
                log.error("CustomLayout \(key): every window must have a finite numeric frame")
                return nil
            }

            let roundedFrame = CGRect(
                x: round(originX),
                y: round(originY),
                width: round(width),
                height: round(height)
            )
            guard roundedFrame.width > 0, roundedFrame.height > 0 else {
                log.error("CustomLayout \(key): frame dimensions must be greater than zero")
                return nil
            }

            var unconstrainedDimension: UnconstrainedDimension = .horizontal
            if let dimension = frame.objectForKeyedSubscript("unconstrainedDimension"),
               !dimension.isUndefined,
               !dimension.isNull {
                guard dimension.isString else {
                    log.error("CustomLayout \(key): unconstrainedDimension must be a string")
                    return nil
                }
                switch dimension.toString() {
                case "horizontal":
                    unconstrainedDimension = .horizontal
                case "vertical":
                    unconstrainedDimension = .vertical
                default:
                    log.error("CustomLayout \(key): unconstrainedDimension must be horizontal or vertical")
                    return nil
                }
            }

            var isMain = true
            if let jsIsMain = frame.objectForKeyedSubscript("isMain"), !jsIsMain.isUndefined, !jsIsMain.isNull {
                guard jsIsMain.isBoolean else {
                    log.error("CustomLayout \(key): isMain must be a boolean")
                    return nil
                }
                isMain = jsIsMain.toBool()
            }

            let scaleFactor = unconstrainedDimension == .horizontal
                ? screenFrame.width / roundedFrame.width
                : screenFrame.height / roundedFrame.height
            guard scaleFactor.isFinite, scaleFactor > 0 else {
                log.error("CustomLayout \(key): scale factor must be finite and positive")
                return nil
            }

            let resizeRules = ResizeRules(
                isMain: isMain,
                unconstrainedDimension: unconstrainedDimension,
                scaleFactor: scaleFactor
            )
            let frameAssignment = FrameAssignment<Window>(
                frame: roundedFrame,
                window: jsWindow.window,
                screenFrame: screenFrame,
                resizeRules: resizeRules
            )
            operations.append(FrameAssignmentOperation(frameAssignment: frameAssignment, windowSet: windowSet))
        }
        return operations
    }

    private func acceptedState(from function: JSValue, arguments: [Any], operation: String) -> JSValue? {
        capturedException = nil
        guard let updatedState = function.call(withArguments: arguments),
              capturedException == nil,
              isPlainObject(updatedState) else {
            log.error("\(layoutKey) — \(operation): state must be an object")
            return nil
        }
        return updatedState
    }

    override func updateWithChange(_ windowChange: Change<Window>) {
        guard let updateWithChange = layout?.objectForKeyedSubscript("updateWithChange"), !updateWithChange.isNull && !updateWithChange.isUndefined else {
            return
        }

        let updateWithChangeArgs: [Any]? = state.flatMap { state in
            return [jsChange(forChange: windowChange), state]
        }

        guard let updatedState = acceptedState(
            from: updateWithChange,
            arguments: updateWithChangeArgs ?? [],
            operation: "updateWithChange"
        ) else {
            return
        }
        state = updatedState
    }

    func command1() {
        command(key: "command1")
    }

    func command2() {
        command(key: "command2")
    }

    func command3() {
        command(key: "command3")
    }

    func command4() {
        command(key: "command4")
    }

    override func nextWindowIDClockwise() -> Window.WindowID? {
        return nil
    }

    override func nextWindowIDCounterClockwise() -> Window.WindowID? {
        return nil
    }

    private func command(key: String) {
        guard let command = commands?.objectForKeyedSubscript(key), command.isObject else {
            log.debug("\(layoutKey) — \(key): no command defined")
            return
        }

        guard let updateState = command.objectForKeyedSubscript("updateState"), !updateState.isNull && !updateState.isUndefined else {
            log.debug("\(layoutKey) — \(key): no updateState function provided")
            return
        }

        let focusedWindowID = Window.currentlyFocused().flatMap { idHash(forWindowID: $0.id()) }
        let updateStateArgs: [Any]? = state.flatMap { state in
            if let id = focusedWindowID {
                return [state, id]
            } else {
                return [state]
            }
        }

        guard let updatedState = acceptedState(
            from: updateState,
            arguments: updateStateArgs ?? [],
            operation: key
        ) else {
            return
        }
        state = updatedState
    }

    private func idHash(forWindowID windowID: WindowID) -> String? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys

            let encodedID = try encoder.encode(windowID)
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            encodedID.withUnsafeBytes {
                _ = CC_SHA256($0.baseAddress, CC_LONG(encodedID.count), &hash)
            }
            return hash.map { String(format: "%02hhx", $0) }.joined()
        } catch {
            log.warning("Failed to hash window id: \(error)")
            return nil
        }
    }

    private func jsChange(forChange change: Change<Window>) -> [String: String] {
        var jsChange: [String: String] = [:]

        switch change {
        case .add(window: let window):
            jsChange["change"] = "add"
            jsChange["windowID"] = idHash(forWindowID: window.id())
        case .remove(window: let window):
            jsChange["change"] = "remove"
            jsChange["windowID"] = idHash(forWindowID: window.id())
        case .focusChanged(window: let window):
            jsChange["change"] = "focus_changed"
            jsChange["windowID"] = idHash(forWindowID: window.id())
        case .windowSwap(window: let window, otherWindow: let otherWindow):
            jsChange["change"] = "window_swap"
            jsChange["windowID"] = idHash(forWindowID: window.id())
            jsChange["otherWindowID"] = idHash(forWindowID: otherWindow.id())
        case .applicationActivate:
            jsChange["change"] = "application_activate"
        case .applicationDeactivate:
            jsChange["change"] = "application_deactivate"
        case .spaceChange:
            jsChange["change"] = "space_change"
        case .layoutChange:
            jsChange["change"] = "layout_change"
        case .tabChange:
            jsChange["change"] = "tab_change"
        case .unknown:
            jsChange["change"] = "unknown"
        case .none:
            jsChange["change"] = "none"
        }

        return jsChange
    }

    func recommendMainPaneRawRatio(rawRatio: CGFloat) {
        guard
            let recommendMainPaneRatio = layout?.objectForKeyedSubscript("recommendMainPaneRatio"),
            !recommendMainPaneRatio.isNull && !recommendMainPaneRatio.isUndefined
        else {
            return
        }

        let recommendMainPaneRatioArgs: [Any]? =  state.flatMap { [rawRatio, $0] }

        guard let updatedState = acceptedState(
            from: recommendMainPaneRatio,
            arguments: recommendMainPaneRatioArgs ?? [],
            operation: "recommendMainPaneRatio"
        ) else {
            return
        }
        state = updatedState
    }

    func increaseMainPaneCount() {
        command(key: "increaseMain")
    }

    func decreaseMainPaneCount() {
        command(key: "decreaseMain")
    }

    func shrinkMainPane() {
        command(key: "shrinkMain")
    }

    func expandMainPane() {
        command(key: "expandMain")
    }
}
