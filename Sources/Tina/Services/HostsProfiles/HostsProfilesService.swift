// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

/// What the managed block in `/etc/hosts` currently looks like. Derived from
/// the file on every refresh rather than from a saved flag, so the page cannot
/// report an apply that never landed.
enum HostsAppliedState: Equatable {
    case unknown
    case empty
    case notApplied
    case outdated(lineCount: Int)
    case applied(lineCount: Int)
}

struct HostsBackup: Identifiable, Equatable {
    let name: String
    let url: URL
    let modifiedAt: Date
    let reason: String

    var id: String { name }
    var wasApply: Bool { reason == "apply" }
}

enum HostsProfilesFailure: Error, Equatable {
    case invalid([HostsValidationIssue])
    case readFailed
    case unbalanced
    case backupFailed
    case writeFailed
    case busy
}

/// Owns the profile list, the backups and the one privileged write. The write
/// goes through `AdminShell`, so it is one system password prompt and no
/// resident helper; every write is preceded by a backup of the whole file.
final class HostsProfilesService: ObservableObject {
    static let shared = HostsProfilesService()

    @Published private(set) var profiles: [HostsProfile] = []
    @Published private(set) var state: HostsAppliedState = .unknown
    @Published private(set) var backups: [HostsBackup] = []
    @Published private(set) var isWorking = false
    @Published private(set) var lastFailure: HostsProfilesFailure?

    private let defaults: UserDefaults
    private let hostsURL: URL
    private let backupDirectory: URL?
    private let work = DispatchQueue(label: "com.tina.hosts-profiles")
    private var hasLoaded = false
    /// The last file read, so edits can refresh the status without hitting the
    /// disk on every keystroke.
    private var cachedHosts: String?

    init(defaults: UserDefaults = .standard,
         hostsURL: URL = URL(fileURLWithPath: "/etc/hosts"),
         backupDirectory: URL? = PrivateFileStore.containerURL?
            .appendingPathComponent("HostsBackups", isDirectory: true)) {
        self.defaults = defaults
        self.hostsURL = hostsURL
        self.backupDirectory = backupDirectory
    }

    private var strings: HostsProfilesStrings {
        FeatureStrings.hostsProfiles(L10n.shared.language)
    }

    // MARK: - Loading

    func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        if let stored = defaults.string(forKey: DefaultsKey.hostsProfilesData) {
            profiles = HostsProfilesSupport.decodeProfiles(stored)
        } else {
            // A commented example teaches the format without changing anything
            // when it is applied.
            profiles = [HostsProfile(name: strings.sampleProfileName,
                                     content: "# 127.0.0.1 api.local\n# 127.0.0.1 app.local",
                                     isEnabled: false)]
            persist()
        }
        refresh()
    }

    // MARK: - Editing

    @discardableResult
    func addProfile() -> UUID {
        load()
        let profile = HostsProfile(name: strings.newProfileName)
        profiles.append(profile)
        persist()
        recomputeState()
        return profile.id
    }

    @discardableResult
    func duplicate(_ id: UUID) -> UUID? {
        load()
        guard let source = profiles.first(where: { $0.id == id }) else { return nil }
        let copy = HostsProfile(name: "\(source.name) 2",
                                content: source.content,
                                isEnabled: false)
        let index = (profiles.firstIndex(where: { $0.id == id }) ?? profiles.count - 1) + 1
        profiles.insert(copy, at: index)
        persist()
        recomputeState()
        return copy.id
    }

    func delete(_ id: UUID) {
        load()
        profiles.removeAll { $0.id == id }
        persist()
        recomputeState()
    }

    func move(_ id: UUID, by offset: Int) {
        load()
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard profiles.indices.contains(target) else { return }
        profiles.swapAt(index, target)
        persist()
        recomputeState()
    }

    func updateName(_ id: UUID, to name: String) {
        load()
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].name = name
        persist()
        recomputeState()
    }

    func updateContent(_ id: UUID, to content: String) {
        load()
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].content = content
        persist()
        recomputeState()
    }

    func setEnabled(_ id: UUID, _ enabled: Bool) {
        load()
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].isEnabled = enabled
        persist()
        recomputeState()
    }

    func issues(for id: UUID) -> [HostsValidationIssue] {
        guard let profile = profiles.first(where: { $0.id == id }) else { return [] }
        return HostsProfilesSupport.validate(profile)
    }

    var enabledProfiles: [HostsProfile] { profiles.filter(\.isEnabled) }

    // MARK: - Reading state

    func refresh() {
        load()
        work.async {
            let current = try? String(contentsOf: self.hostsURL, encoding: .utf8)
            let backups = self.readBackups()
            DispatchQueue.main.async {
                self.cachedHosts = current
                self.backups = backups
                guard let current else {
                    self.state = .unknown
                    return
                }
                self.updateState(current: current)
            }
        }
    }

    private func recomputeState() {
        guard let cachedHosts else { return }
        updateState(current: cachedHosts)
    }

    private func updateState(current: String) {
        let expected = HostsProfilesSupport.managedBlock(for: profiles)
        guard let actual = HostsProfilesSupport.managedBlock(in: current) else {
            state = expected.isEmpty ? .empty : .notApplied
            return
        }
        let count = HostsProfilesSupport.effectiveLineCount(of: actual)
        state = actual == expected ? .applied(lineCount: count) : .outdated(lineCount: count)
    }

    // MARK: - Apply

    func apply() {
        guard !isWorking else {
            lastFailure = .busy
            return
        }
        load()
        let issues = HostsProfilesSupport.validate(profiles.filter(\.isEnabled))
        guard issues.isEmpty else {
            lastFailure = .invalid(issues)
            return
        }

        isWorking = true
        lastFailure = nil
        let profiles = self.profiles
        let prompt = strings.adminPrompt

        work.async {
            guard let current = try? String(contentsOf: self.hostsURL, encoding: .utf8) else {
                self.finish(.failure(.readFailed))
                return
            }
            let block = HostsProfilesSupport.managedBlock(for: profiles)
            guard let updated = HostsProfilesSupport.applying(block: block, to: current) else {
                self.finish(.failure(.unbalanced))
                return
            }
            if updated == current {
                DispatchQueue.main.async {
                    self.cachedHosts = current
                    self.updateState(current: current)
                    self.finish(.success(()))
                }
                return
            }
            guard self.writeBackup(current, reason: "apply") else {
                self.finish(.failure(.backupFailed))
                return
            }
            self.install(updated, prompt: prompt) { result in
                self.finish(result)
            }
        }
    }

    // MARK: - Restore

    func restore(_ backup: HostsBackup) {
        guard !isWorking else {
            lastFailure = .busy
            return
        }
        isWorking = true
        lastFailure = nil
        let prompt = strings.adminPrompt

        work.async {
            guard let restored = try? String(contentsOf: backup.url, encoding: .utf8) else {
                self.finish(.failure(.readFailed))
                return
            }
            guard let current = try? String(contentsOf: self.hostsURL, encoding: .utf8) else {
                self.finish(.failure(.readFailed))
                return
            }
            guard self.writeBackup(current, reason: "restore") else {
                self.finish(.failure(.backupFailed))
                return
            }
            self.install(restored, prompt: prompt) { result in
                self.finish(result)
            }
        }
    }

    // MARK: - Privileged write

    /// Writes through a temp file so the user's content never becomes part of
    /// a shell command. The path is generated here and single-quoted; the only
    /// shell text is the fixed `install` and `rm` command line.
    private func install(_ content: String,
                         prompt: String,
                         completion: @escaping (Result<Void, HostsProfilesFailure>) -> Void) {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("tina-hosts-\(UUID().uuidString).conf")
        do {
            try content.write(to: temp, atomically: true, encoding: .utf8)
        } catch {
            completion(.failure(.writeFailed))
            return
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o600],
                                               ofItemAtPath: temp.path)
        let quoted = Self.shellQuoted(temp.path)
        let command = "/usr/bin/install -m 0644 -o root -g wheel \(quoted) /etc/hosts"
            + " && /bin/rm -f \(quoted)"

        AdminShell.run(command, prompt: prompt) { ok in
            try? FileManager.default.removeItem(at: temp)
            guard ok,
                  let after = try? String(contentsOf: self.hostsURL, encoding: .utf8),
                  after == content
            else {
                completion(.failure(.writeFailed))
                return
            }
            completion(.success(()))
        }
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func finish(_ result: Result<Void, HostsProfilesFailure>) {
        DispatchQueue.main.async {
            self.isWorking = false
            switch result {
            case .success:
                self.lastFailure = nil
                self.refresh()
            case .failure(let failure):
                self.lastFailure = failure
            }
        }
    }

    func clearFailure() {
        lastFailure = nil
    }

    // MARK: - Backups

    private func writeBackup(_ content: String, reason: String) -> Bool {
        guard let directory = backupDirectory,
              PrivateFileStore.createDirectory(at: directory)
        else { return false }
        let name = HostsProfilesSupport.backupFileName(at: Date(), reason: reason)
        let url = directory.appendingPathComponent(name)
        guard PrivateFileStore.write(Data(content.utf8), to: url) else { return false }
        pruneBackups(in: directory)
        return true
    }

    private func readBackups() -> [HostsBackup] {
        guard let directory = backupDirectory,
              let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path)
        else { return [] }
        return names.compactMap { name -> HostsBackup? in
            guard name.hasPrefix("hosts-"), name.hasSuffix(".bak") else { return nil }
            let url = directory.appendingPathComponent(name)
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let date = attributes[.modificationDate] as? Date
            else { return nil }
            let parts = name.split(separator: "-", maxSplits: 4, omittingEmptySubsequences: false)
            let reason = parts.count == 5
                ? String(parts[4]).replacingOccurrences(of: ".bak", with: "")
                : ""
            return HostsBackup(name: name, url: url, modifiedAt: date, reason: reason)
        }
        .sorted { $0.name > $1.name }
    }

    private func pruneBackups(in directory: URL) {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path)
        else { return }
        let backups = names.filter { $0.hasPrefix("hosts-") && $0.hasSuffix(".bak") }
        for name in HostsProfilesSupport.backupsToDelete(backups,
                                                         keeping: HostsProfilesSupport.maxBackups) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    // MARK: - Persistence

    private func persist() {
        guard let encoded = HostsProfilesSupport.encodeProfiles(profiles) else { return }
        defaults.set(encoded, forKey: DefaultsKey.hostsProfilesData)
    }
}
