// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// One day of aggregates. Counts and seconds only: no key codes, no window
/// titles, no file paths, no per-app detail beyond the bundle identifier.
struct UsageStatsDay: Codable, Equatable, Identifiable {
    let day: String              // yyyy-MM-dd in the local calendar
    var appSeconds: [String: Double] = [:]
    var screenSeconds: Double = 0
    var keyPresses: Int = 0
    var clicks: Int = 0

    var id: String { day }
    var topApps: [(bundleID: String, seconds: Double)] {
        appSeconds.sorted { lhs, rhs in
            lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
        }.map { ($0.key, $0.value) }
    }
}

/// Local, opt-in usage aggregates. The store keeps a bounded number of days,
/// writes owner-only at most once a minute, and never leaves the Mac.
final class UsageStatsStore: ObservableObject {
    static let shared = UsageStatsStore()

    static let retentionChoices = [7, 30, 90]

    @Published private(set) var days: [UsageStatsDay] = []

    private let fileURL: URL?
    private let calendar = Calendar.current
    private let lock = NSLock()
    private var dirty = false
    private var lastWrite = Date.distantPast

    init(fileURL: URL? = UsageStatsStore.defaultFileURL()) {
        self.fileURL = fileURL
        load()
    }

    static func defaultFileURL() -> URL? {
        guard let container = PrivateFileStore.containerURL else { return nil }
        return container.appendingPathComponent("usage-stats.json")
    }

    var retentionDays: Int {
        let raw = UserDefaults.standard.integer(forKey: DefaultsKey.usageStatsRetentionDays)
        return Self.retentionChoices.contains(raw) ? raw : 30
    }

    /// Adds one sample. `bundleID` is nil when no app was frontmost.
    func add(appBundleID: String?, seconds: Double, screenOn: Bool,
             keyPresses: Int = 0, clicks: Int = 0, now: Date = Date()) {
        let key = Self.dayKey(now, calendar: calendar)
        lock.lock()
        var changed = false
        if let index = days.firstIndex(where: { $0.day == key }) {
            if let bundleID = appBundleID, seconds > 0 {
                days[index].appSeconds[bundleID, default: 0] += seconds
            }
            if screenOn { days[index].screenSeconds += seconds }
            days[index].keyPresses += keyPresses
            days[index].clicks += clicks
            changed = true
        } else {
            var day = UsageStatsDay(day: key)
            if let bundleID = appBundleID, seconds > 0 { day.appSeconds[bundleID] = seconds }
            if screenOn { day.screenSeconds = seconds }
            day.keyPresses = keyPresses
            day.clicks = clicks
            days.append(day)
            days.sort { $0.day < $1.day }
            changed = true
        }
        if changed { dirty = true }
        lock.unlock()
        if changed { trimAndPersist(now: now) }
    }

    /// Forces the pending aggregates to disk (quit, feature off, tests).
    func flush() {
        persist(force: true)
    }

    func clear() {
        lock.lock(); days = []; dirty = true; lock.unlock()
        persist(force: true)
    }

    /// Newest first, for the UI.
    func recent(_ count: Int) -> [UsageStatsDay] {
        Array(days.suffix(max(0, count)).reversed())
    }

    func total(for day: UsageStatsDay) -> Double {
        day.screenSeconds
    }

    // MARK: - Persistence

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func trimAndPersist(now: Date) {
        let cutoff = calendar.date(byAdding: .day, value: -retentionDays, to: now) ?? now
        let cutoffKey = Self.dayKey(cutoff, calendar: calendar)
        lock.lock()
        let before = days.count
        days.removeAll { $0.day < cutoffKey }
        if days.count != before { dirty = true }
        let shouldWrite = dirty && now.timeIntervalSince(lastWrite) >= 60
        lock.unlock()
        if shouldWrite { persist(force: false) }
    }

    private func persist(force: Bool) {
        lock.lock()
        let snapshot = days
        let wrote = force || dirty
        dirty = false
        lastWrite = Date()
        lock.unlock()
        guard wrote, let fileURL,
              let data = try? JSONEncoder().encode(snapshot) else { return }
        _ = PrivateFileStore.createDirectory(at: fileURL.deletingLastPathComponent())
        _ = PrivateFileStore.write(data, to: fileURL)
    }

    private func load() {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([UsageStatsDay].self, from: data)
        else { return }
        let cutoffKey = Self.dayKey(calendar.date(byAdding: .day, value: -retentionDays,
                                                  to: Date()) ?? Date(), calendar: calendar)
        days = decoded.filter { $0.day >= cutoffKey }.sorted { $0.day < $1.day }
    }
}
