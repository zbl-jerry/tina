// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

enum LaunchItemScope: String, Equatable {
    case userAgent
    case systemAgent
    case systemDaemon

    /// Only the current user's own agents can be stopped without an
    /// administrator password. Everything else is listed and explained.
    var isWritable: Bool { self == .userAgent }
}

struct LaunchItem: Identifiable, Equatable {
    let url: URL
    let label: String
    let program: String?
    let scope: LaunchItemScope
    /// Whether launchd currently has this label loaded in the user's domain.
    /// System scopes are read-only and always report false here; the UI says
    /// so instead of implying "not running".
    let loaded: Bool
    /// The user stopped this item from Tina. It is never re-enabled behind
    /// their back.
    let disabledByTina: Bool

    var id: String { url.path }
    var canToggle: Bool { scope.isWritable }
}

enum LaunchItemsSupport {
    /// Reads the label and the executable path from a launchd plist. A plist
    /// without a label cannot be identified and is skipped.
    static func parse(_ data: Data) -> (label: String, program: String?)? {
        guard let object = try? PropertyListSerialization.propertyList(from: data,
                                                                       options: [],
                                                                       format: nil),
              let dictionary = object as? [String: Any],
              let label = dictionary["Label"] as? String,
              !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        let program = (dictionary["Program"] as? String)
            ?? (dictionary["ProgramArguments"] as? [String])?.first
        return (label, program?.isEmpty == true ? nil : program)
    }

    /// Resolves which of the three launchd folders a plist belongs to. The
    /// user folder is matched against the given home so tests can use a
    /// fixture.
    static func scope(for url: URL, home: URL) -> LaunchItemScope? {
        let path = url.standardizedFileURL.path
        let homePath = home.standardizedFileURL.path
        if path == homePath + "/Library/LaunchAgents/\(url.lastPathComponent)" {
            return .userAgent
        }
        if path == "/Library/LaunchAgents/\(url.lastPathComponent)" {
            return .systemAgent
        }
        if path == "/Library/LaunchDaemons/\(url.lastPathComponent)" {
            return .systemDaemon
        }
        return nil
    }

    static func bootoutArguments(uid: uid_t, label: String) -> [String] {
        ["bootout", "gui/\(uid)/\(label)"]
    }

    static func bootstrapArguments(uid: uid_t, url: URL) -> [String] {
        ["bootstrap", "gui/\(uid)", url.path]
    }

    /// The labels in `launchctl list`'s first column. Rows without a label
    /// ("PID\tStatus\tLabel" header, empty lines) are ignored.
    static func loadedLabels(from output: String) -> Set<String> {
        var labels: Set<String> = []
        for line in output.split(separator: "\n") {
            let columns = line.split(separator: "\t", omittingEmptySubsequences: true)
            guard let last = columns.last, columns.count >= 3 else { continue }
            let label = String(last).trimmingCharacters(in: .whitespaces)
            if !label.isEmpty, label != "Label" { labels.insert(label) }
        }
        return labels
    }
}
