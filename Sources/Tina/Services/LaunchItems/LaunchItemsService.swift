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
        case idle, loading, loaded, failed
    }

    @Published private(set) var items: [LaunchItem] = []
    @Published private(set) var phase: Phase = .idle
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
                switch result {
                case let .success(items):
                    self.items = items
                    self.phase = .loaded
                case .failure:
                    self.items = []
                    self.phase = .failed
                }
            }
        }
    }

    /// Stops or starts one user agent. The answer is verified by asking
    /// launchd again, so a refused command is reported instead of guessed.
    func setEnabled(_ item: LaunchItem, _ enabled: Bool,
                    completion: @escaping (Bool) -> Void) {
        guard item.canToggle, !busyLabels.contains(item.label) else {
            completion(false)
            return
        }
        busyLabels.insert(item.label)
        queue.async { [weak self] in
            let uid = getuid()
            let result: Bool
            if enabled {
                result = Self.run("/bin/launchctl",
                                  LaunchItemsSupport.bootstrapArguments(uid: uid, url: item.url)).status == 0
            } else {
                result = Self.run("/bin/launchctl",
                                  LaunchItemsSupport.bootoutArguments(uid: uid, label: item.label)).status == 0
            }
            let verified = result && Self.isLoaded(label: item.label)
            DispatchQueue.main.async {
                guard let self else { return }
                self.busyLabels.remove(item.label)
                if verified {
                    self.setDisabled(enabled ? false : true, label: item.label)
                }
                completion(verified)
            }
        }
    }

    // MARK: - Reading

    private static func enumerate() -> Result<[LaunchItem], Error> {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let loaded = loadedLabels()
        let disabled = Set(UserDefaults.standard
            .stringArray(forKey: DefaultsKey.launchItemsDisabledLabels) ?? [])
        var found: [LaunchItem] = []
        for root in [home.appendingPathComponent("Library/LaunchAgents", isDirectory: true),
                     URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true),
                     URL(fileURLWithPath: "/Library/LaunchDaemons", isDirectory: true)] {
            guard let entries = try? FileManager.default.contentsOfDirectory(at: root,
                                                                             includingPropertiesForKeys: nil)
            else { continue }
            for url in entries where url.pathExtension == "plist" {
                guard let scope = LaunchItemsSupport.scope(for: url, home: home),
                      let data = try? Data(contentsOf: url),
                      let parsed = LaunchItemsSupport.parse(data)
                else { continue }
                found.append(LaunchItem(url: url,
                                        label: parsed.label,
                                        program: parsed.program,
                                        scope: scope,
                                        loaded: scope == .userAgent && loaded.contains(parsed.label),
                                        disabledByTina: disabled.contains(parsed.label)))
            }
        }
        found.sort { lhs, rhs in
            lhs.scope == rhs.scope ? lhs.label.localizedStandardCompare(rhs.label) == .orderedAscending
                : lhs.scope.rawValue < rhs.scope.rawValue
        }
        return .success(found)
    }

    private static func loadedLabels() -> Set<String> {
        let result = run("/bin/launchctl", ["list"])
        guard result.status == 0,
              let text = String(data: result.output, encoding: .utf8)
        else { return [] }
        return LaunchItemsSupport.loadedLabels(from: text)
    }

    private static func isLoaded(label: String) -> Bool {
        loadedLabels().contains(label)
    }

    private func setDisabled(_ disabled: Bool, label: String) {
        var labels = Set(UserDefaults.standard
            .stringArray(forKey: DefaultsKey.launchItemsDisabledLabels) ?? [])
        if disabled { labels.insert(label) } else { labels.remove(label) }
        UserDefaults.standard.set(Array(labels).sorted(),
                                  forKey: DefaultsKey.launchItemsDisabledLabels)
        refresh()
    }

    // MARK: - Process

    struct CommandResult {
        let status: Int32
        let output: Data
    }

    @discardableResult
    static func run(_ executable: String, _ arguments: [String]) -> CommandResult {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return CommandResult(status: -1, output: Data())
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandResult(status: process.terminationStatus, output: data)
    }
}
