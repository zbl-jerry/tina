// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Saves the curated user-level macOS settings, compares them with this Mac
/// and applies only what differs. A copy of the values is kept before each
/// apply, so the last change can be undone.
struct MacSettingsSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var store = MacSettingsStore.shared
    @State private var current: [String: MacSettingValue] = [:]
    @State private var name = ""
    @State private var errorText: String?

    private var text: MacSettingsStrings { FeatureStrings.macSettings(l10n.language) }

    var body: some View {
        Form {
            Section {
                Text(text.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(text.current) {
                ForEach(MacSetting.allCases) { setting in
                    LabeledContent(setting.key,
                                   value: current[setting.rawValue]?.displayString ?? "—")
                        .font(.caption)
                }
            }

            Section {
                HStack {
                    TextField(text.save, text: $name)
                    Button(text.save) {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        store.save(store.capture(named: trimmed))
                        name = ""
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if store.profiles.isEmpty {
                Section {
                    Text(text.empty)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(store.profiles) { profile in
                    profileSection(profile)
                }
            }

            if store.canUndoLastApply {
                Section {
                    Button(text.undo) {
                        errorText = store.restoreLastApply() ? nil : text.failed
                        refresh()
                    }
                }
            }

            if let errorText {
                Section {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refresh)
    }

    private func profileSection(_ profile: MacSettingsProfile) -> some View {
        Section {
            DisclosureGroup {
                ForEach(MacSetting.allCases) { setting in
                    if let value = profile.values[setting.rawValue] {
                        LabeledContent(setting.key, value: value.displayString)
                            .font(.caption2)
                    }
                }
            } label: {
                HStack {
                    Text(profile.name)
                    Spacer()
                    Button(text.apply) {
                        errorText = nil
                        if !store.apply(profile) {
                            errorText = text.failed
                        }
                        refresh()
                    }
                    Button(role: .destructive) {
                        store.delete(profile.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private func refresh() {
        current = store.readCurrent()
    }
}
