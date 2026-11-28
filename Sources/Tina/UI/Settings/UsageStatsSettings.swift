// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Local usage aggregates: screen time, input counts and the apps that took
/// the most time. Counts only — the store never sees key codes or text.
struct UsageStatsSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var store = UsageStatsStore.shared
    @AppStorage(DefaultsKey.usageStatsEnabled) private var enabled = false
    @AppStorage(DefaultsKey.usageStatsRetentionDays) private var retentionDays = 30

    private var text: UsageStatsStrings { FeatureStrings.usageStats(l10n.language) }

    var body: some View {
        Form {
            Section {
                Toggle(text.title, isOn: $enabled)
                    .onChange(of: enabled) { _, _ in
                        FeatureRuntime.shared.sync([.usageStats])
                    }
                Text(text.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker(text.retention, selection: $retentionDays) {
                    ForEach(UsageStatsStore.retentionChoices, id: \.self) { days in
                        Text(String(format: text.retentionFormat, days)).tag(days)
                    }
                }
                .onChange(of: retentionDays) { _, _ in
                    // The next sample trims to the new window.
                    store.add(appBundleID: nil, seconds: 0, screenOn: false)
                }
            }

            if let today = store.days.last {
                Section(text.today) {
                    LabeledContent(text.screenTime, value: Self.duration(today.screenSeconds))
                    LabeledContent(text.keyPresses, value: "\(today.keyPresses)")
                    LabeledContent(text.clicks, value: "\(today.clicks)")
                    if !today.topApps.isEmpty {
                        ForEach(Array(today.topApps.prefix(5).enumerated()), id: \.offset) { _, app in
                            LabeledContent(Self.appName(app.bundleID),
                                           value: Self.duration(app.seconds))
                        }
                    }
                }
            } else {
                Section {
                    Text(text.empty)
                        .foregroundStyle(.secondary)
                }
            }

            if store.days.count > 1 {
                Section(text.today) {
                    ForEach(store.recent(7)) { day in
                        LabeledContent(day.day, value: Self.duration(day.screenSeconds))
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    UsageStatsService.shared.clear()
                } label: {
                    Text(text.clear)
                }
                .disabled(store.days.isEmpty)
                Text(text.privacy)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private static func appName(_ bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return bundleID
        }
        return FileManager.default.displayName(atPath: url.path)
    }
}
