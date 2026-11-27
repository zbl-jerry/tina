// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// Reads, saves and applies the curated macOS settings. Every write is
/// preceded by a snapshot of the current values, so the last apply can be
/// undone from the same page. No administrator rights are involved.
final class MacSettingsStore: ObservableObject {
    static let shared = MacSettingsStore()

    @Published private(set) var profiles: [MacSettingsProfile] = []
    @Published private(set) var lastAppliedBackup: MacSettingsProfile?

    private let fileURL: URL?
    private let lock = NSLock()

    init(fileURL: URL? = MacSettingsStore.defaultFileURL()) {
        self.fileURL = fileURL
        load()
    }

    static func defaultFileURL() -> URL? {
        guard let container = PrivateFileStore.containerURL else { return nil }
        return container.appendingPathComponent("mac-settings-profiles.json")
    }

    // MARK: - Reading

    func readCurrent() -> [String: MacSettingValue] {
        var current: [String: MacSettingValue] = [:]
        for setting in MacSetting.allCases {
            if let value = MacSettingsSupport.value(for: setting,
                                                    raw: Self.read(setting)) {
                current[setting.rawValue] = value
            }
        }
        return current
    }

    func capture(named name: String) -> MacSettingsProfile {
        MacSettingsProfile(name: name, values: readCurrent())
    }

    // MARK: - Profiles

    func save(_ profile: MacSettingsProfile) {
        lock.lock()
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        profiles.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        lock.unlock()
        persist()
    }

    func delete(_ id: UUID) {
        lock.lock(); profiles.removeAll { $0.id == id }; lock.unlock()
        persist()
    }

    // MARK: - Applying

    /// Writes the selected settings from the profile, after keeping the
    /// current values so `restoreLastApply()` can undo exactly this change.
    @discardableResult
    func apply(_ profile: MacSettingsProfile, settings: [MacSetting]) -> Bool {
        let current = readCurrent()
        let backup = MacSettingsProfile(name: "Before apply", values: current)
        var wroteAll = true
        for setting in settings {
            guard let value = profile.values[setting.rawValue] else { continue }
            if !Self.write(setting, value: value) { wroteAll = false }
        }
        lock.lock(); lastAppliedBackup = backup; lock.unlock()
        restart(MacSettingsSupport.components(for: settings))
        return wroteAll
    }

    @discardableResult
    func restoreLastApply() -> Bool {
        lock.lock(); let backup = lastAppliedBackup; lock.unlock()
        guard let backup else { return false }
        var wroteAll = true
        var settings: [MacSetting] = []
        for setting in MacSetting.allCases {
            guard let value = backup.values[setting.rawValue] else { continue }
            settings.append(setting)
            if !Self.write(setting, value: value) { wroteAll = false }
        }
        restart(MacSettingsSupport.components(for: settings))
        lock.lock(); lastAppliedBackup = nil; lock.unlock()
        return wroteAll
    }

    // MARK: - Preferences

    private static func read(_ setting: MacSetting) -> Any? {
        let application = setting.domain == kCFPreferencesAnyApplication as String
            ? kCFPreferencesAnyApplication
            : setting.domain as CFString
        return CFPreferencesCopyAppValue(setting.key as CFString, application)
    }

    private static func write(_ setting: MacSetting, value: MacSettingValue) -> Bool {
        let application = setting.domain == kCFPreferencesAnyApplication as String
            ? kCFPreferencesAnyApplication
            : setting.domain as CFString
        let raw: Any
        switch value {
        case .bool(let flag): raw = flag
        case .number(let number): raw = number
        case .text(let text): raw = text
        }
        CFPreferencesSetAppValue(setting.key as CFString, raw as CFTypeRef, application)
        return CFPreferencesAppSynchronize(application)
    }

    private func restart(_ components: Set<MacSetting.Component>) {
        for component in components {
            let names = component == .dock ? ["Dock"] : ["Finder"]
            for name in names {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
                process.arguments = [name]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                try? process.run()
            }
        }
    }

    // MARK: - Persistence

    private func persist() {
        lock.lock()
        let snapshot = profiles
        lock.unlock()
        guard let fileURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        _ = PrivateFileStore.createDirectory(at: fileURL.deletingLastPathComponent())
        _ = PrivateFileStore.write(data, to: fileURL)
    }

    private func load() {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([MacSettingsProfile].self, from: data)
        else { return }
        profiles = decoded
    }
}
