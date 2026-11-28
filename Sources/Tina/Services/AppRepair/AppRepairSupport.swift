// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// What a scan can say about one installed app. The states are independent:
/// a quarantined app can still have a valid signature, and a broken signature
/// is never repaired here.
enum AppRepairIssue: String, CaseIterable, Hashable {
    case quarantined
    case invalidSignature
    case notAccepted
    case assessmentUnavailable
}

struct AppRepairFileIdentity: Equatable {
    let device: Int32
    let inode: UInt64
    let createdSeconds: Int
    let createdNanoseconds: Int
}

struct AppRepairCandidate: Identifiable, Equatable {
    let url: URL
    let bundleIdentifier: String?
    let name: String
    let fileIdentity: AppRepairFileIdentity
    let issues: Set<AppRepairIssue>
    /// The quarantine flag was read successfully. A failed read is not the
    /// same as "not quarantined" and keeps the row out of the repair list.
    let quarantineReadable: Bool

    var id: String { url.path }

    var canRemoveQuarantine: Bool {
        AppRepairPolicy.canRemoveQuarantine(issues: issues, quarantineReadable: quarantineReadable)
    }
}

enum AppRepairPolicy {
    /// Removing the quarantine flag is the one action this tool can take, and
    /// only when the bundle's signature verifies. A broken signature, an app
    /// Gatekeeper refuses, or an unreadable attribute is reported, never
    /// "repaired" by skipping a check.
    static func canRemoveQuarantine(issues: Set<AppRepairIssue>, quarantineReadable: Bool) -> Bool {
        quarantineReadable
            && issues.contains(.quarantined)
            && !issues.contains(.invalidSignature)
            && !issues.contains(.notAccepted)
            && !issues.contains(.assessmentUnavailable)
    }

    /// Only apps with at least one issue make it into the list.
    static func isCandidate(issues: Set<AppRepairIssue>) -> Bool {
        !issues.isEmpty
    }

    /// The sparse list is deliberately ordered: the problem the user can fix
    /// here first, then the ones that need the app's vendor.
    static func sortedIssues(_ issues: Set<AppRepairIssue>) -> [AppRepairIssue] {
        AppRepairIssue.allCases.filter(issues.contains)
    }
}
