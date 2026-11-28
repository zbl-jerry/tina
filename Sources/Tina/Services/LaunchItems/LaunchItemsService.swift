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
        guard item.allows(action), !busyLabels.contains(item.label) else {
            completion(false)
            return
        }
        busyLabels.insert(item.label)
        queue.async { [weak self] in
            let home = URL(fileURLWithPath: NSHomeDirectory())
            let verified = LaunchItemsSupport.perform(action, on: item, home: home, uid: getuid(), run: Self.run)
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

    private static func enumerate() -> (items: [LaunchItem], unreadable: Bool) {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let uid = getuid()
        let overrides = LaunchItemsSupport.disabledOverrides(uid: uid, run: run)
        var unreadable = false
        var found: [LaunchItem] = []
        for root in [home.appendingPathComponent("Library/LaunchAgents"), LaunchItemsSupport.AgentFolders.standard.local,
                     URL(fileURLWithPath: "/Library/LaunchDaemons", isDirectory: true)] {
            guard let plists = LaunchItemsSupport.entries(in: root) else { unreadable = true; continue }
            for url in plists {
                guard let scope = LaunchItemsSupport.scope(for: url, home: home) else { continue }
                guard let plist = LaunchItemsSupport.readPlist(url) else { unreadable = true; continue }
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
