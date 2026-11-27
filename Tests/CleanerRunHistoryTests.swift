// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

enum CleanerRunHistoryTests {
    static func run(_ suite: TestSuite) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("tina-cleaner-history-\(UUID().uuidString)",
                                                                isDirectory: true)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let file = root.appendingPathComponent("runs.json")

        func entry(_ name: String, outcome: CleanerRunOutcome, size: Int64 = 10) -> CleanerRunEntry {
            CleanerRunEntry(path: "/tmp/\(name)", category: "caches", detail: name,
                            size: size, outcome: outcome, trashPath: "/Trash/\(name)")
        }

        func run(_ id: Int, entries: [CleanerRunEntry]) -> CleanerRun {
            CleanerRun(id: UUID(), date: Date(timeIntervalSince1970: Double(id)),
                       origin: .manual, entries: entries)
        }

        let history = CleanerRunHistory(fileURL: file)
        suite.expect(history.runs.isEmpty, "a fresh history starts empty")

        history.record(CleanerRun(id: UUID(), date: Date(), origin: .manual, entries: []))
        suite.expect(history.runs.isEmpty, "an empty run is not worth a record")

        let first = run(1, entries: [entry("a", outcome: .trashed, size: 100),
                                     entry("b", outcome: .failed, size: 50),
                                     entry("c", outcome: .skipped, size: 25)])
        history.record(first)
        suite.expect(history.runs.count == 1, "a run with entries is recorded")
        suite.expect(history.runs[0].freed == 100, "only moved items count as freed")
        suite.expect(history.runs[0].failedCount == 1 && history.runs[0].skippedCount == 1,
                     "failed and skipped items are counted apart")
        suite.expect(history.runs[0].entries[0].trashPath == "/Trash/a",
                     "the Trash destination is kept")

        // The limit keeps the newest and drops the oldest.
        for index in 2...(CleanerRunHistory.limit + 5) {
            history.record(run(index, entries: [entry("\(index)", outcome: .trashed)]))
        }
        suite.expect(history.runs.count == CleanerRunHistory.limit,
                     "the history caps at its limit")
        suite.expect(history.runs.first?.date.timeIntervalSince1970
                     == Double(CleanerRunHistory.limit + 5),
                     "the newest run leads the list")

        // Persistence: a new instance reads the same file.
        let reloaded = CleanerRunHistory(fileURL: file)
        suite.expect(reloaded.runs.count == CleanerRunHistory.limit,
                     "runs survive a relaunch")
        suite.expect(reloaded.runs.first?.entries.first?.trashPath == "/Trash/\(CleanerRunHistory.limit + 5)",
                     "destinations survive a relaunch")

        reloaded.clear()
        suite.expect(reloaded.runs.isEmpty, "clear empties the list")
        suite.expect(CleanerRunHistory(fileURL: file).runs.isEmpty,
                     "clear persists")
    }
}
