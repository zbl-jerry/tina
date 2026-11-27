// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

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
        let library = home.appendingPathComponent("Library", isDirectory: true)
        let applicationSupport = library.appendingPathComponent("Application Support",
                                                                 isDirectory: true)
        // The home Trash, so every root stays under the home the caller gave.
        let trash = home.appendingPathComponent(".Trash", isDirectory: true)
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
            group(category: category, root: root, fileManager: fileManager, topLimit: topLimit)
        }
        return SystemDataSummary(groups: groups, scannedAt: Date())
    }

    static func group(category: SystemDataCategory,
                      root: URL,
                      fileManager: FileManager = .default,
                      topLimit: Int = 10) -> SystemDataGroup {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        guard let entries = try? fileManager.contentsOfDirectory(at: root,
                                                                 includingPropertiesForKeys: keys,
                                                                 options: []) else {
            return SystemDataGroup(category: category, bytes: 0, itemCount: 0,
                                   top: [], complete: false)
        }
        var total: Int64 = 0
        var complete = true
        var all: [SystemDataEntry] = []
        for entry in entries {
            let values = try? entry.resourceValues(forKeys: Set(keys))
            if values?.isSymbolicLink == true { continue }
            let measured = size(of: entry, fileManager: fileManager)
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
    static func size(of url: URL, fileManager: FileManager = .default) -> (bytes: Int64, complete: Bool) {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return (0, false)
        }
        if !isDirectory.boolValue {
            let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
            return (Int64(values?.totalFileAllocatedSize ?? 0), true)
        }
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
        var complete = true
        guard let enumerator = fileManager.enumerator(at: url,
                                                      includingPropertiesForKeys: keys,
                                                      options: [],
                                                      errorHandler: { _, _ in
            complete = false
            return true
        }) else { return (0, false) }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            let values = try? file.resourceValues(forKeys: Set(keys))
            if values?.isSymbolicLink == true { continue }
            if values?.isRegularFile == true {
                total += Int64(values?.totalFileAllocatedSize ?? 0)
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
