// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

enum SystemDataSummaryTests {
    static func run(_ suite: TestSuite) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("tina-system-data-\(UUID().uuidString)",
                                                                isDirectory: true)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        func write(_ relative: String, bytes: Int) {
            let url = root.appendingPathComponent(relative)
            try? fm.createDirectory(at: url.deletingLastPathComponent(),
                                    withIntermediateDirectories: true)
            fm.createFile(atPath: url.path, contents: Data(repeating: 7, count: bytes))
        }

        write("Small/a.bin", bytes: 1_024)
        write("Large/b.bin", bytes: 64 * 1_024)
        write("Large/nested/c.bin", bytes: 32 * 1_024)
        write("Medium/d.bin", bytes: 8 * 1_024)
        try? fm.createSymbolicLink(at: root.appendingPathComponent("LargeLink"),
                                   withDestinationURL: root.appendingPathComponent("Large"))

        let group = SystemDataSummaryBuilder.group(category: .applicationSupport,
                                                   root: root,
                                                   fileManager: fm,
                                                   topLimit: 2)
        suite.expect(group.itemCount == 3, "the symlink is not counted as a child, got \(group.itemCount)")
        suite.expect(group.top.count == 2, "the top list honours its limit")
        let topNames = group.top.map(\.name)
        suite.expect(topNames == ["Large", "Medium"],
                     "children are ordered by size, got \(topNames)")
        let expectedMinimum: Int64 = 105 * 1_024
        suite.expect(group.bytes >= expectedMinimum,
                     "the total includes nested files")
        suite.expect(group.complete, "a readable tree is complete")

        let missing = SystemDataSummaryBuilder.group(
            category: .containers,
            root: root.appendingPathComponent("does-not-exist"),
            fileManager: fm)
        suite.expect(!missing.complete && missing.bytes == 0 && missing.itemCount == 0,
                     "an unreadable root is incomplete, never a confident zero")

        let summary = SystemDataSummaryBuilder.summary(
            roots: [(.applicationSupport, root), (.containers, root.appendingPathComponent("nope"))],
            fileManager: fm)
        suite.expect(summary.groups.count == 2, "one group per root")
        suite.expect(summary.incomplete, "one incomplete group marks the summary incomplete")
        suite.expect(summary.total == summary.groups.map(\.bytes).reduce(0, +),
                     "the total adds the groups")

        let roots = SystemDataSummaryBuilder.defaultRoots(home: root)
        suite.expect(roots.count == SystemDataCategory.allCases.count,
                     "every System Data category has a root")
        suite.expect(roots.allSatisfy { $0.1.path.hasPrefix(root.path) },
                     "roots stay under the given home")
        suite.expect(SystemDataSummary.empty.groups.isEmpty
                     && SystemDataSummary.empty.total == 0,
                     "the empty summary is empty")
    }
}
