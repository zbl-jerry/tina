// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

enum ShortcutRegistrationAuditTests {
    static func run(_ suite: TestSuite) {
        let audit = ShortcutRegistrationAudit.shared
        audit.resetForTests()

        var retried: [String] = []
        audit.report(key: "a", failed: true) { retried.append("a") }
        suite.expect(audit.isFailed("a"), "a failed report marks the key")
        suite.expect(audit.failedKeys == ["a"], "the published set carries the key")

        audit.report(key: "b", failed: true) { retried.append("b") }
        audit.retryAll()
        suite.expect(Set(retried) == ["a", "b"],
                     "retryAll runs every failing owner once, got \(retried)")

        audit.report(key: "a", failed: false)
        suite.expect(!audit.isFailed("a"), "a successful report clears the key")
        suite.expect(audit.failedKeys == ["b"], "only the still-failing key remains")

        retried.removeAll()
        audit.retryAll()
        suite.expect(retried == ["b"], "a cleared key is not retried again, got \(retried)")

        audit.clear(key: "b")
        suite.expect(audit.failedKeys.isEmpty, "clear removes the last failing key")
        retried.removeAll()
        audit.retryAll()
        suite.expect(retried.isEmpty, "nothing is retried when nothing failed")

        // A later failure after a success re-enters the set, and its own retry
        // replaces the one dropped by the success.
        audit.report(key: "c", failed: true)
        suite.expect(audit.failedKeys == ["c"], "re-reporting a failure restores it")

        // Reporting a failure without a retry keeps the key visible; retryAll
        // simply has nothing to run for it.
        audit.report(key: "d", failed: true)
        suite.expect(audit.failedKeys == ["c", "d"], "a failure without a retry is still shown")
        retried.removeAll()
        audit.retryAll()
        suite.expect(retried.isEmpty, "a failure without a retry adds no action")

        audit.resetForTests()
        suite.expect(audit.failedKeys.isEmpty, "reset clears the audit")
    }
}
