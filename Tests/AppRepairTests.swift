// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Darwin
import Foundation

enum AppRepairTests {
    static func run(_ suite: TestSuite) {
        // The only repair this tool offers is dropping quarantine, and only
        // when the signature still verifies.
        suite.expect(AppRepairPolicy.canRemoveQuarantine(
            issues: [.quarantined], quarantineReadable: true),
            "a quarantined app with a valid signature can be repaired")
        suite.expect(!AppRepairPolicy.canRemoveQuarantine(
            issues: [.quarantined, .invalidSignature], quarantineReadable: true),
            "a broken signature is never repaired")
        suite.expect(!AppRepairPolicy.canRemoveQuarantine(
            issues: [.quarantined, .notAccepted], quarantineReadable: true),
            "an app Gatekeeper refuses is never repaired")
        suite.expect(!AppRepairPolicy.canRemoveQuarantine(
            issues: [.quarantined, .assessmentUnavailable], quarantineReadable: true),
            "an absent or failed assessment does not authorize repair")
        suite.expect(AppRepairService.assessmentIsEnabled(status: 0, output: Data("assessments enabled\n".utf8))
                     && !AppRepairService.assessmentIsEnabled(status: 0, output: Data("assessments disabled\n".utf8))
                     && !AppRepairService.assessmentIsEnabled(status: 1, output: Data("assessments enabled\n".utf8)),
                     "repair requires an explicit successful enabled status")
        suite.expect(!AppRepairPolicy.canRemoveQuarantine(
            issues: [.quarantined], quarantineReadable: false),
            "an unreadable quarantine attribute is not treated as present")
        suite.expect(!AppRepairPolicy.canRemoveQuarantine(
            issues: [], quarantineReadable: true),
            "an app without issues has nothing to repair")

        suite.expect(AppRepairPolicy.isCandidate(issues: [.invalidSignature]),
                     "a signature failure is listed even without quarantine")
        suite.expect(!AppRepairPolicy.isCandidate(issues: []),
                     "a healthy app stays out of the list")
        suite.expect(AppRepairPolicy.sortedIssues([.notAccepted, .quarantined, .invalidSignature])
                     == [.quarantined, .invalidSignature, .notAccepted],
                     "issues are listed in a stable, readable order")

        // The attribute probe distinguishes "absent" from "unreadable".
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("tina-app-repair-\(UUID().uuidString)",
                                                                isDirectory: true)
        do {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: root) }
            let candidate = root.appendingPathComponent("Sample.app")
            let moved = root.appendingPathComponent("Moved.app")
            let alias = root.appendingPathComponent("Alias.app")
            try fm.createDirectory(at: candidate, withIntermediateDirectories: false)
            let confirmed = AppRepairService.identity(at: candidate)
            try fm.moveItem(at: candidate, to: moved)
            try fm.createDirectory(at: candidate, withIntermediateDirectories: false)
            try fm.createSymbolicLink(at: alias, withDestinationURL: moved)
            suite.expect(confirmed != nil && AppRepairService.identity(at: moved) == confirmed
                         && AppRepairService.identity(at: candidate) != confirmed
                         && AppRepairService.identity(at: alias) == nil,
                         "a pathname replacement or symlink cannot stand in for the confirmed bundle")
            suite.expect(AppRepairService.signatureArguments(for: candidate) ==
                         ["--verify", "--deep", "--strict", candidate.path],
                         "signature verification checks nested code without changing it")
            let file = root.appendingPathComponent("probe")
            fm.createFile(atPath: file.path, contents: Data("x".utf8))
            suite.expect(AppRepairService.quarantineState(at: file) == .absent,
                         "a plain file has no quarantine attribute")
            let value = Data("0081;00000000;Tina;".utf8)
            let set = file.path.withCString { path in
                value.withUnsafeBytes { bytes in
                    setxattr(path, "com.apple.quarantine", bytes.baseAddress, value.count, 0, 0)
                }
            }
            suite.expect(set == 0, "the quarantine attribute could be written for the probe")
            if set == 0 {
                suite.expect(AppRepairService.quarantineState(at: file) == .present,
                             "a quarantined file is detected")
            }
        } catch {
            suite.expect(false, "app repair fixture failed: \(error)")
        }
    }
}
