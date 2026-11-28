// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// Reads, saves and applies the curated macOS settings. Undo retains the
/// exact previous values of the last apply's touched keys.
final class MacSettingsStore: ObservableObject {
    static let shared = MacSettingsStore()

    @Published private(set) var profiles: [MacSettingsProfile] = []
    @Published private(set) var canUndoLastApply = false

    private let fileURL: URL?
    private let lock = NSLock()
    private var lastApply: [MacSettingsSupport.UndoEntry] = []

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
        for settings in Dictionary(grouping: MacSetting.allCases, by: \.domain).values {
            guard let first = settings.first, Self.synchronize(first) else { continue }
            for setting in settings {
                current[setting.rawValue] = MacSettingsSupport.value(for: setting, raw: Self.read(setting))
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

    /// Rechecks the live settings at the time of the write, not the view's
    /// cached snapshot. A no-op does not replace an existing Undo.
    @discardableResult
    func apply(_ profile: MacSettingsProfile) -> Bool {
        let result = MacSettingsSupport.apply(profile, prepare: Self.synchronize,
                                              read: Self.read, write: Self.write)
        if !result.undo.isEmpty {
            lastApply = result.undo
            canUndoLastApply = true
        }
        restart(MacSettingsSupport.components(for: result.changed))
        return result.succeeded
    }

    @discardableResult
    func restoreLastApply() -> Bool {
        guard !lastApply.isEmpty else { return false }
        let result = MacSettingsSupport.restore(lastApply, write: Self.write)
        lastApply = result.undo
        canUndoLastApply = !lastApply.isEmpty
        restart(MacSettingsSupport.components(for: result.changed))
        return result.succeeded
    }

    // MARK: - Preferences

    private static func read(_ setting: MacSetting) -> Any? {
        CFPreferencesCopyValue(setting.key as CFString, applicationDomain(for: setting),
                               kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    private static func applicationDomain(for setting: MacSetting) -> CFString {
        setting.domain == kCFPreferencesAnyApplication as String
            ? kCFPreferencesAnyApplication
            : setting.domain as CFString
    }

    private static func write(_ setting: MacSetting, _ value: Any?) -> Bool {
        CFPreferencesSetValue(setting.key as CFString, value.map { $0 as CFTypeRef }, applicationDomain(for: setting),
                              kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return synchronize(setting) && MacSettingsSupport.sameRawValue(read(setting), value)
    }

    private static func synchronize(_ setting: MacSetting) -> Bool {
        CFPreferencesSynchronize(applicationDomain(for: setting), kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
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
