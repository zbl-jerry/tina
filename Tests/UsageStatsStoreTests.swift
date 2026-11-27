// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

enum UsageStatsStoreTests {
    static func run(_ suite: TestSuite) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("tina-usage-\(UUID().uuidString)",
                                                                isDirectory: true)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let file = root.appendingPathComponent("usage.json")

        let store = UsageStatsStore(fileURL: file)
        suite.expect(store.days.isEmpty, "a fresh store starts empty")

        let now = Date()
        store.add(appBundleID: "com.a", seconds: 30, screenOn: true,
                  keyPresses: 10, clicks: 2, now: now)
        store.add(appBundleID: "com.a", seconds: 20, screenOn: true,
                  keyPresses: 5, clicks: 1, now: now.addingTimeInterval(30))
        store.add(appBundleID: "com.b", seconds: 10, screenOn: false,
                  keyPresses: 1, clicks: 1, now: now.addingTimeInterval(60))

        suite.expect(store.days.count == 1, "samples on one day share a record")
        let first = store.days[0]
        suite.expect(first.appSeconds["com.a"] == 50, "app seconds accumulate, got \(first.appSeconds)")
        suite.expect(first.appSeconds["com.b"] == 10, "a second app keeps its own total")
        suite.expect(first.screenSeconds == 50, "only screen-on samples count as screen time")
        suite.expect(first.keyPresses == 16 && first.clicks == 4,
                     "input counts accumulate")
        suite.expect(first.topApps.first?.bundleID == "com.a",
                     "the top app is the one with the most time")

        // Persistence: a new instance sees the same aggregates.
        store.flush()
        let reloaded = UsageStatsStore(fileURL: file)
        suite.expect(reloaded.days.count == 1, "days survive a relaunch")
        suite.expect(reloaded.days.first?.appSeconds["com.a"] == 50,
                     "aggregates survive a relaunch")

        // A second day becomes its own record, in day order.
        let tomorrow = now.addingTimeInterval(86_400)
        store.add(appBundleID: "com.c", seconds: 5, screenOn: true, now: tomorrow)
        suite.expect(store.days.count == 2 && store.days.map(\.day) == store.days.map(\.day).sorted(),
                     "a new day appends in day order")

        // Retention drops anything before the cutoff once a current sample
        // arrives.
        UserDefaults.standard.set(7, forKey: DefaultsKey.usageStatsRetentionDays)
        store.add(appBundleID: "com.old", seconds: 1, screenOn: true,
                  now: now.addingTimeInterval(-30 * 86_400))
        store.add(appBundleID: "com.c", seconds: 1, screenOn: true, now: tomorrow)
        suite.expect(!store.days.contains { $0.appSeconds["com.old"] != nil },
                     "a day older than the retention window is dropped")
        UserDefaults.standard.removeObject(forKey: DefaultsKey.usageStatsRetentionDays)

        store.clear()
        suite.expect(store.days.isEmpty, "clear empties the store")
        suite.expect(UsageStatsStore(fileURL: file).days.isEmpty, "clear persists")
    }
}
