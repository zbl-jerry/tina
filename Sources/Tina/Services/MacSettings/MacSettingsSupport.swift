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
        case .finderShowHidden, .finderShowExtensions, .finderShowPathBar: return "com.apple.finder"
        case .keyboardRepeatRate, .keyboardRepeatDelay: return kCFPreferencesAnyApplication as String
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

    /// Settings whose current value differs from the profile. Missing current
    /// values count as differences.
    static func differences(between current: [String: MacSettingValue],
                            and profile: MacSettingsProfile) -> [MacSetting] {
        MacSetting.allCases.filter { setting in
            guard let wanted = profile.values[setting.rawValue] else { return false }
            return current[setting.rawValue] != wanted
        }
    }

    /// The components that must relaunch for the given settings to apply.
    static func components(for settings: [MacSetting]) -> Set<MacSetting.Component> {
        Set(settings.compactMap(\.component))
    }
}
