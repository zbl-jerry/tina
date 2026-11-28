// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation
import Combine

/// The folders macOS rolls into "System Data". Read-only: this summary only
/// measures, and every delete path stays with the Cleaner's own categories.
enum SystemDataCategory: String, CaseIterable, Identifiable {
    case applicationSupport
    case containers
    case groupContainers
    case caches
    case logs
    case developer
    case deviceBackups
    case trash

    var id: String { rawValue }
}

struct SystemDataEntry: Identifiable, Equatable {
    let name: String
    let bytes: Int64
    var id: String { name }
}

struct SystemDataGroup: Identifiable, Equatable {
    let category: SystemDataCategory
    let bytes: Int64
    let itemCount: Int
    let top: [SystemDataEntry]
    /// False when part of the tree could not be read. The group then shows
    /// what it could measure instead of presenting an incomplete total as the
    /// whole answer.
    let complete: Bool
    var id: String { category.rawValue }
}

struct SystemDataSummary: Equatable {
    let groups: [SystemDataGroup]
    let scannedAt: Date
    var incomplete: Bool { groups.contains { !$0.complete } }
    var total: Int64 { groups.reduce(0) { $0 + $1.bytes } }

    static let empty = SystemDataSummary(groups: [], scannedAt: .distantPast)
}

/// Sizes immediate children of each root and keeps the largest few, so the
/// summary answers "which app is holding System Data" without a treemap.
enum SystemDataSummaryBuilder {
    static func defaultRoots(home: URL = URL(fileURLWithPath: NSHomeDirectory())) -> [(SystemDataCategory, URL)] {
        // Resolve only the caller's anchor (macOS may spell it through an
        // alias such as /var). Generated paths below it must not redirect.
        let anchor = home.resolvingSymlinksInPath().standardizedFileURL
        let library = anchor.appendingPathComponent("Library", isDirectory: true)
        let applicationSupport = library.appendingPathComponent("Application Support",
                                                                 isDirectory: true)
        // The home Trash, so every root stays under the home the caller gave.
        let trash = anchor.appendingPathComponent(".Trash", isDirectory: true)
        return [
            (.applicationSupport, applicationSupport),
            (.containers, library.appendingPathComponent("Containers", isDirectory: true)),
            (.groupContainers, library.appendingPathComponent("Group Containers", isDirectory: true)),
            (.caches, library.appendingPathComponent("Caches", isDirectory: true)),
            (.logs, library.appendingPathComponent("Logs", isDirectory: true)),
            (.developer, library.appendingPathComponent("Developer", isDirectory: true)),
            (.deviceBackups, applicationSupport.appendingPathComponent("MobileSync/Backup",
                                                                       isDirectory: true)),
            (.trash, trash),
        ]
    }

    static func summary(roots: [(SystemDataCategory, URL)],
                        fileManager: FileManager = .default,
                        topLimit: Int = 10) -> SystemDataSummary {
        let groups = roots.map { category, root in
            let rootPath = root.standardizedFileURL.path
            let prefix = rootPath == "/" ? "/" : rootPath + "/"
            let nestedRoots = Set(roots.map { $0.1.standardizedFileURL.path }
                .filter { $0 != rootPath && $0.hasPrefix(prefix) })
            return group(category: category, root: root, fileManager: fileManager, topLimit: topLimit,
                         excluding: nestedRoots)
        }
        return SystemDataSummary(groups: groups, scannedAt: Date())
    }

    static func group(category: SystemDataCategory,
                      root: URL,
                      fileManager: FileManager = .default,
                      topLimit: Int = 10,
                      excluding excludedPaths: Set<String> = []) -> SystemDataGroup {
        let rootKeys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        guard root.standardizedFileURL.path == root.resolvingSymlinksInPath().standardizedFileURL.path,
              let values = try? root.resourceValues(forKeys: rootKeys),
              values.isDirectory == true, values.isSymbolicLink == false,
              let entries = try? fileManager.contentsOfDirectory(at: root,
                                                                 includingPropertiesForKeys: Array(measurementKeys),
                                                                 options: []) else {
            return SystemDataGroup(category: category, bytes: 0, itemCount: 0,
                                   top: [], complete: false)
        }
        var total: Int64 = 0
        var complete = true
        var all: [SystemDataEntry] = []
        for entry in entries {
            guard !excludedPaths.contains(entry.standardizedFileURL.path) else { continue }
            guard let values = try? entry.resourceValues(forKeys: measurementKeys),
                  let isLink = values.isSymbolicLink else { complete = false; continue }
            if isLink { continue }
            let measured = size(of: entry, values: values, fileManager: fileManager, excluding: excludedPaths)
            if !measured.complete { complete = false }
            total += measured.bytes
            all.append(SystemDataEntry(name: entry.lastPathComponent, bytes: measured.bytes))
        }
        let top = all.sorted { lhs, rhs in
            lhs.bytes == rhs.bytes ? lhs.name < rhs.name : lhs.bytes > rhs.bytes
        }.prefix(max(0, topLimit))
        return SystemDataGroup(category: category, bytes: total, itemCount: all.count,
                               top: Array(top), complete: complete)
    }

    /// Allocated bytes under one URL, never following a symlink. A tree with
    /// an unreadable member reports `complete: false`; the bytes it could
    /// read are still counted.
    private static let measurementKeys: Set<URLResourceKey> = [
        .totalFileAllocatedSizeKey, .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey,
    ]

    private static func size(of url: URL, values: URLResourceValues,
                             fileManager: FileManager, excluding excludedPaths: Set<String>)
        -> (bytes: Int64, complete: Bool) {
        guard let isDirectory = values.isDirectory, let isFile = values.isRegularFile else { return (0, false) }
        if !isDirectory {
            guard isFile else { return (0, true) }
            guard let bytes = values.totalFileAllocatedSize else { return (0, false) }
            return (Int64(bytes), true)
        }
        var complete = true
        guard let enumerator = fileManager.enumerator(at: url,
                                                      includingPropertiesForKeys: Array(measurementKeys),
                                                      options: [],
                                                      errorHandler: { _, _ in
            complete = false
            return true
        }) else { return (0, false) }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            if excludedPaths.contains(file.standardizedFileURL.path) {
                enumerator.skipDescendants()
                continue
            }
            guard let values = try? file.resourceValues(forKeys: measurementKeys),
                  let isLink = values.isSymbolicLink, let isFile = values.isRegularFile else {
                complete = false
                enumerator.skipDescendants()
                continue
            }
            if isLink {
                enumerator.skipDescendants()
            } else if isFile {
                if let bytes = values.totalFileAllocatedSize {
                    total += Int64(bytes)
                } else {
                    complete = false
                }
            }
        }
        return (total, complete)
    }
}

/// Runs the measurement off the main thread; the summary is read-only and is
/// never cached to disk.
final class SystemDataScanner: ObservableObject {
    enum State: Equatable {
        case idle
        case scanning
        case done(SystemDataSummary)
        case failed
    }

    @Published private(set) var state: State = .idle

    private let queue = DispatchQueue(label: "com.tina.utils.system-data", qos: .userInitiated)
    private var generation = 0

    func scan() {
        generation += 1
        let current = generation
        state = .scanning
        queue.async { [weak self] in
            let summary = SystemDataSummaryBuilder.summary(
                roots: SystemDataSummaryBuilder.defaultRoots())
            DispatchQueue.main.async {
                guard let self, self.generation == current else { return }
                self.state = summary.groups.isEmpty ? .failed : .done(summary)
            }
        }
    }

    func reset() {
        generation += 1
        state = .idle
    }
}
