// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// Lists launchd's login agents and daemons and can stop or start the ones
/// this user owns. Reading is read-only everywhere; the system folders are
/// never modified. Nothing is deleted here — removing a plist stays with the
/// Cleaner's reviewed leftovers.
final class LaunchItemsService: ObservableObject {
    static let shared = LaunchItemsService()

    enum Phase: Equatable {
        case idle, loading, loaded
    }

    @Published private(set) var items: [LaunchItem] = []
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var hasUnreadableFolders = false
    @Published private(set) var busyLabels: Set<String> = []

    private let queue = DispatchQueue(label: "com.tina.utils.launch-items", qos: .userInitiated)
    private var generation = 0

    private init() {}

    func refresh() {
        generation += 1
        let current = generation
        phase = .loading
        queue.async { [weak self] in
            let result = Self.enumerate()
            DispatchQueue.main.async {
                guard let self, self.generation == current else { return }
                self.items = result.items
                self.hasUnreadableFolders = result.unreadable
                self.phase = .loaded
            }
        }
    }

    /// Revalidates the plist, runs the requested user-agent action, and reads
    /// launchd's same GUI domain to verify its effect.
    func perform(_ action: LaunchItemsSupport.Action, on item: LaunchItem,
                 completion: @escaping (Bool) -> Void) {
        guard item.allows(action), let identity = item.plistIdentity,
              !busyLabels.contains(item.label) else {
            completion(false)
            return
        }
        busyLabels.insert(item.label)
        queue.async { [weak self] in
            let uid = getuid()
            let home = URL(fileURLWithPath: NSHomeDirectory())
            let isCurrent = {
                LaunchItemsSupport.ownedPlistIdentity(item.url, home: home, uid: uid) == identity
                    && Self.readPlist(item.url)?.label == item.label
            }
            let fresh = LaunchItemsSupport.ownedPlistIdentity(item.url, home: home, uid: uid) == identity
                ? Self.readPlist(item.url) : nil
            let changesLogin = action == .enableAtLogin || action == .disableAtLogin
            let verified = fresh.map { plist in
                plist.label == item.label
                    && (!changesLogin || Self.userOwnsLabel(item.label, at: item.url, home: home))
                    && LaunchItemsSupport.perform(action, uid: uid, label: item.label, plist: item.url,
                                                  defaultDisabled: plist.disabled, run: Self.run,
                                                  isCurrent: isCurrent)
            } ?? false
            DispatchQueue.main.async {
                guard let self else { return }
                self.busyLabels.remove(item.label)
                // Refresh even if the command changed something but the
                // subsequent verification was inconclusive.
                self.refresh()
                completion(verified)
            }
        }
    }

    // MARK: - Reading

    private static func readPlist(_ url: URL) -> (label: String, program: String?, disabled: Bool)? {
        var info = stat()
        guard lstat(url.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              let data = try? Data(contentsOf: url) else { return nil }
        return LaunchItemsSupport.parse(data)
    }

    private static func entries(in folder: URL) -> [URL]? {
        do {
            return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "plist" }
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        } catch {
            return nil
        }
    }

    private static let localAgents = URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true)
    private static let systemAgents = URL(fileURLWithPath: "/System/Library/LaunchAgents", isDirectory: true)

    private static func userOwnsLabel(_ label: String, at selected: URL, home: URL) -> Bool {
        for root in [home.appendingPathComponent("Library/LaunchAgents"), localAgents, systemAgents] {
            guard let plists = entries(in: root) else { return false }
            for other in plists where other.standardizedFileURL != selected.standardizedFileURL {
                guard let peer = readPlist(other), peer.label != label else { return false }
            }
        }
        return true
    }

    private static func enumerate() -> (items: [LaunchItem], unreadable: Bool) {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let uid = getuid()
        let overrides = LaunchItemsSupport.disabledOverrides(uid: uid, run: run)
        var unreadable = false
        var found: [LaunchItem] = []
        for root in [home.appendingPathComponent("Library/LaunchAgents"), localAgents,
                     URL(fileURLWithPath: "/Library/LaunchDaemons", isDirectory: true)] {
            guard let plists = entries(in: root) else { unreadable = true; continue }
            for url in plists {
                guard let scope = LaunchItemsSupport.scope(for: url, home: home) else { continue }
                guard let plist = readPlist(url) else { unreadable = true; continue }
                let state = scope.isWritable
                    ? LaunchItemsSupport.serviceState(uid: uid, label: plist.label, run: run)
                    : .unknown
                found.append(LaunchItem(
                    url: url, label: plist.label, program: plist.program, scope: scope, state: state,
                    disabledAtLogin: scope.isWritable ? overrides.map { $0[plist.label] ?? plist.disabled } : nil,
                    plistIdentity: scope.isWritable
                        ? LaunchItemsSupport.ownedPlistIdentity(url, home: home, uid: uid) : nil))
            }
        }
        return (found.sorted { lhs, rhs in
            lhs.scope == rhs.scope ? lhs.label.localizedStandardCompare(rhs.label) == .orderedAscending
                : lhs.scope.rawValue < rhs.scope.rawValue
        }, unreadable)
    }

    // MARK: - Process

    @discardableResult
    private static func run(_ arguments: [String]) -> LaunchItemsSupport.CommandResult {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(["LC_ALL": "C"]) { _, new in new }
        process.standardOutput = output
        process.standardError = output
        do {
            try process.run()
        } catch {
            return LaunchItemsSupport.CommandResult(status: -1, output: Data())
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return LaunchItemsSupport.CommandResult(
            status: process.terminationReason == .exit ? process.terminationStatus : -1, output: data)
    }
}
