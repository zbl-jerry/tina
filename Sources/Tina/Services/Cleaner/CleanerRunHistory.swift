// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

enum CleanerRunOrigin: String, Codable, Equatable {
    case manual, automatic
}

enum CleanerRunOutcome: String, Codable, Equatable {
    case trashed, emptied, skipped, failed
}

struct CleanerRunEntry: Codable, Equatable {
    let path: String
    let category: String
    let detail: String
    let size: Int64
    let outcome: CleanerRunOutcome
    /// Where the item went in the Trash. Nil when the move succeeded through
    /// Finder (which does not hand a path back) or when nothing moved.
    let trashPath: String?

    var name: String { (path as NSString).lastPathComponent }
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
        entries.filter { $0.outcome == .trashed || $0.outcome == .emptied }
            .reduce(0) { $0 + $1.size }
    }

    var failedCount: Int {
        entries.filter { $0.outcome == .failed }.count
    }

    var skippedCount: Int {
        entries.filter { $0.outcome == .skipped }.count
    }
}

/// The last handful of cleans, kept so a user can see what moved, where it
/// went and what stayed behind. Records hold paths and sizes only: no file
/// contents, no app data. The store is owner-only and local.
final class CleanerRunHistory: ObservableObject {
    static let shared = CleanerRunHistory()

    /// Older runs fall off the end. Twenty is enough to answer "what did the
    /// scheduled clean do last night" without growing without bound.
    static let limit = 20

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
        runs = []
        persist()
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
        guard let fileURL,
              let data = try? JSONEncoder().encode(runs)
        else { return }
        _ = PrivateFileStore.createDirectory(at: fileURL.deletingLastPathComponent())
        _ = PrivateFileStore.write(data, to: fileURL)
    }
}
