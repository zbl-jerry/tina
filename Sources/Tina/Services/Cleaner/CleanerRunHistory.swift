// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation
import Combine

enum CleanerRunOrigin: String, Codable, Equatable {
    case manual, automatic
}

enum CleanerRunOutcome: String, Codable, Equatable {
    case trashed, emptied, skipped, failed
}

struct CleanerRunEntry: Codable, Equatable {
    struct TrashIdentity: Codable, Equatable {
        let device: UInt64
        let inode: UInt64
        let createdAt: Date

        init?(at url: URL, matching expected: UninstallerSupport.FileIdentity? = nil) {
            guard !UninstallerSupport.isSymbolicLink(url),
                  let identity = UninstallerSupport.fileIdentity(at: url),
                  expected == nil || identity == expected,
                  let dates = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let createdAt = dates[.creationDate] as? Date else { return nil }
            device = identity.device
            inode = identity.inode
            self.createdAt = createdAt
        }
    }

    let path: String
    let category: String
    let detail: String
    let size: Int64
    let outcome: CleanerRunOutcome
    /// Where the item went in the Trash. Nil when the move succeeded through
    /// Finder (which does not hand a path back) or when nothing moved.
    let trashPath: String?
    /// Older histories have no fingerprint; never resolve those paths to a
    /// possibly unrelated replacement.
    var trashIdentity: TrashIdentity? = nil

    var name: String { (path as NSString).lastPathComponent }

    var revealableTrashURL: URL? {
        guard outcome == .trashed, let trashPath, let trashIdentity else { return nil }
        let url = URL(fileURLWithPath: trashPath)
        return TrashIdentity(at: url) == trashIdentity ? url : nil
    }
}

extension CleanerSupport.Category {
    /// A stable name for storage. The enum's raw value is an Int assigned by
    /// declaration order, so a new category would silently rename old records.
    var historyKey: String {
        switch self {
        case .leftovers: return "leftovers"
        case .loginItems: return "loginItems"
        case .caches: return "caches"
        case .logs: return "logs"
        case .developer: return "developer"
        case .trash: return "trash"
        case .deviceBackups: return "deviceBackups"
        case .screenshots: return "screenshots"
        }
    }
}

struct CleanerRun: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    let origin: CleanerRunOrigin
    let entries: [CleanerRunEntry]

    var freed: Int64 {
        entries.reduce(0) { $0 + ($1.outcome == .emptied ? $1.size : 0) }
    }

    var moved: Int64 {
        entries.reduce(0) { $0 + ($1.outcome == .trashed ? $1.size : 0) }
    }

    var failedCount: Int {
        entries.filter { $0.outcome == .failed }.count
    }

    var skippedCount: Int {
        entries.filter { $0.outcome == .skipped }.count
    }

    var leftBehindCount: Int { failedCount + skippedCount }
}

/// The last handful of cleans, kept so a user can see what moved, where it
/// went and what stayed behind. Records hold paths, sizes and file identities,
/// not file contents or app data. The store is owner-only and local.
final class CleanerRunHistory: ObservableObject {
    static let shared = CleanerRunHistory()

    /// Older runs fall off the end. Twenty is enough to answer "what did the
    /// scheduled clean do last night" without growing without bound.
    static let limit = 20
    private static let persistence = DispatchQueue(label: "com.tina.utils.cleaner-history")

    @Published private(set) var runs: [CleanerRun] = []

    private let fileURL: URL?

    init(fileURL: URL? = CleanerRunHistory.defaultFileURL()) {
        self.fileURL = fileURL
        load()
    }

    static func defaultFileURL() -> URL? {
        guard let container = PrivateFileStore.containerURL else { return nil }
        return container.appendingPathComponent("cleaner-runs.json")
    }

    /// Adds a run and keeps the newest `limit`. An empty run is not recorded:
    /// a scheduled pass that found nothing has no history worth keeping.
    func record(_ run: CleanerRun) {
        guard !run.entries.isEmpty else { return }
        runs.insert(run, at: 0)
        if runs.count > Self.limit {
            runs.removeLast(runs.count - Self.limit)
        }
        persist()
    }

    func clear() {
        // Do not show an empty history while a crash could still restore old
        // records. Serialize the explicit clear after all pending snapshots.
        if let fileURL, !Self.persistence.sync(execute: { Self.write([], to: fileURL) }) { return }
        runs = []
    }

    /// Normal app exit waits for the last queued write.
    static func flushPendingWrites() {
        persistence.sync {}
    }

    func delete(_ id: UUID) {
        runs.removeAll { $0.id == id }
        persist()
    }

    private func load() {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([CleanerRun].self, from: data)
        else { return }
        runs = Array(decoded.prefix(Self.limit))
    }

    private func persist() {
        guard let fileURL else { return }
        let snapshot = runs
        Self.persistence.async {
            _ = Self.write(snapshot, to: fileURL)
        }
    }

    private static func write(_ snapshot: [CleanerRun], to fileURL: URL) -> Bool {
        guard let data = try? JSONEncoder().encode(snapshot),
              PrivateFileStore.createDirectory(at: fileURL.deletingLastPathComponent()) else { return false }
        return PrivateFileStore.write(data, to: fileURL)
    }
}
