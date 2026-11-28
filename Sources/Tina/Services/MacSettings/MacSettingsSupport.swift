// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// The curated user-level settings this tool knows how to read, compare and
/// write. Everything here lives in a user preference domain: no TCC database,
/// no /Library preferences and no administrator rights.
enum MacSetting: String, CaseIterable, Codable, Identifiable {
    case dockAutoHide
    case dockOrientation
    case dockMinimizeEffect
    case finderShowHidden
    case finderShowExtensions
    case finderShowPathBar
    case keyboardRepeatRate
    case keyboardRepeatDelay
    case screenshotLocation
    case screenshotFormat

    var id: String { rawValue }

    enum Kind { case bool, number, text }
    enum Component: Hashable { case dock, finder }

    var domain: String {
        switch self {
        case .dockAutoHide, .dockOrientation, .dockMinimizeEffect: return "com.apple.dock"
        case .finderShowHidden, .finderShowPathBar: return "com.apple.finder"
        case .finderShowExtensions, .keyboardRepeatRate, .keyboardRepeatDelay:
            return kCFPreferencesAnyApplication as String
        case .screenshotLocation, .screenshotFormat: return "com.apple.screencapture"
        }
    }

    var key: String {
        switch self {
        case .dockAutoHide: return "autohide"
        case .dockOrientation: return "orientation"
        case .dockMinimizeEffect: return "mineffect"
        case .finderShowHidden: return "AppleShowAllFiles"
        case .finderShowExtensions: return "AppleShowAllExtensions"
        case .finderShowPathBar: return "ShowPathbar"
        case .keyboardRepeatRate: return "KeyRepeat"
        case .keyboardRepeatDelay: return "InitialKeyRepeat"
        case .screenshotLocation: return "location"
        case .screenshotFormat: return "type"
        }
    }

    var kind: Kind {
        switch self {
        case .dockAutoHide, .finderShowHidden, .finderShowExtensions, .finderShowPathBar:
            return .bool
        case .keyboardRepeatRate, .keyboardRepeatDelay:
            return .number
        case .dockOrientation, .dockMinimizeEffect, .screenshotLocation, .screenshotFormat:
            return .text
        }
    }

    /// The component that has to relaunch before a written value shows.
    var component: Component? {
        switch self {
        case .dockAutoHide, .dockOrientation, .dockMinimizeEffect: return .dock
        case .finderShowHidden, .finderShowExtensions, .finderShowPathBar: return .finder
        default: return nil
        }
    }

    var numberRange: ClosedRange<Int>? {
        switch self {
        case .keyboardRepeatRate: return 1...120
        case .keyboardRepeatDelay: return 5...120
        default: return nil
        }
    }

    var textChoices: [String]? {
        switch self {
        case .dockOrientation: return ["bottom", "left", "right"]
        case .dockMinimizeEffect: return ["genie", "scale"]
        case .screenshotFormat: return ["png", "jpg", "pdf", "tiff"]
        default: return nil
        }
    }
}

enum MacSettingValue: Codable, Equatable {
    case bool(Bool)
    case number(Int)
    case text(String)

    var rawPreference: Any {
        switch self {
        case .bool(let value): return value
        case .number(let value): return value
        case .text(let value): return value
        }
    }

    var displayString: String {
        switch self {
        case .bool(let value): return value ? "On" : "Off"
        case .number(let value): return String(value)
        case .text(let value): return value
        }
    }
}

struct MacSettingsProfile: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String
    /// Keyed by `MacSetting.rawValue`.
    var values: [String: MacSettingValue]
}

enum MacSettingsSupport {
    /// A single application only journals touched keys. An entry with no
    /// previous value means Undo removes the key from this exact domain.
    struct UndoEntry {
        let setting: MacSetting
        let previousValue: Any?
    }

    struct ChangeResult {
        let undo: [UndoEntry]
        let changed: [MacSetting]
        let succeeded: Bool
    }

    static func apply(_ profile: MacSettingsProfile,
                      prepare: (MacSetting) -> Bool = { _ in true },
                      read: (MacSetting) -> Any?,
                      write: (MacSetting, Any?) -> Bool) -> ChangeResult {
        var undo: [UndoEntry] = []
        var changed: [MacSetting] = []
        var succeeded = true
        for setting in MacSetting.allCases {
            guard let wanted = profile.values[setting.rawValue] else { continue }
            let raw = wanted.rawPreference
            guard value(for: setting, raw: raw) == wanted, prepare(setting) else {
                succeeded = false
                continue
            }
            let previous = read(setting)
            guard value(for: setting, raw: previous) != wanted else { continue }
            if write(setting, raw) {
                undo.append(UndoEntry(setting: setting, previousValue: previous))
                changed.append(setting)
            } else {
                succeeded = false
                // A failed synchronization may still have changed the live
                // preference cache. Roll back or leave a retriable undo.
                if !sameRawValue(previous, read(setting)), !write(setting, previous) {
                    undo.append(UndoEntry(setting: setting, previousValue: previous))
                }
            }
        }
        return ChangeResult(undo: undo, changed: changed, succeeded: succeeded)
    }

    static func restore(_ undo: [UndoEntry],
                        write: (MacSetting, Any?) -> Bool) -> ChangeResult {
        var pending: [UndoEntry] = []
        var changed: [MacSetting] = []
        for entry in undo {
            // A failed prior write may have changed the in-memory cache but
            // not disk. Always synchronize an entry until it succeeds.
            if write(entry.setting, entry.previousValue) {
                changed.append(entry.setting)
            } else {
                pending.append(entry)
            }
        }
        return ChangeResult(undo: pending, changed: changed, succeeded: pending.isEmpty)
    }

    static func sameRawValue(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case let (lhs?, rhs?):
            let lhs = lhs as CFTypeRef
            let rhs = rhs as CFTypeRef
            return CFGetTypeID(lhs) == CFGetTypeID(rhs) && CFEqual(lhs, rhs)
        default: return false
        }
    }

    /// Folds a raw preference into the typed value the setting expects, or
    /// nil when it does not fit (wrong type, out of range, unknown choice).
    static func value(for setting: MacSetting, raw: Any?) -> MacSettingValue? {
        guard let raw else { return nil }
        switch setting.kind {
        case .bool:
            if let value = raw as? Bool { return .bool(value) }
            if let value = raw as? Int { return .bool(value != 0) }
            if let value = raw as? String {
                switch value.lowercased() {
                case "yes", "true", "1": return .bool(true)
                case "no", "false", "0": return .bool(false)
                default: return nil
                }
            }
            return nil
        case .number:
            let value: Int?
            if let number = raw as? Int { value = number }
            else if let number = raw as? NSNumber { value = number.intValue }
            else if let text = raw as? String { value = Int(text) }
            else { value = nil }
            guard let value, let range = setting.numberRange, range.contains(value) else { return nil }
            return .number(value)
        case .text:
            guard let text = raw as? String else { return nil }
            if let choices = setting.textChoices, !choices.contains(text) { return nil }
            return .text(text)
        }
    }

    /// The components that must relaunch for the given settings to apply.
    static func components(for settings: [MacSetting]) -> Set<MacSetting.Component> {
        Set(settings.compactMap(\.component))
    }
}
