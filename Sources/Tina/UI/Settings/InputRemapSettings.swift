// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import ApplicationServices
import SwiftUI

/// Single key-to-key mappings. The page edits the rule list; the service
/// installs a session tap only while the feature is enabled and Accessibility
/// is granted, so a missing permission never swallows a key.
struct InputRemapSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.inputRemapEnabled) private var enabled = false
    @State private var rules: [InputRemapRule] = []
    @State private var adding = false
    @State private var newSource: GlobalShortcut?
    @State private var newTarget: GlobalShortcut?
    @State private var failed = false

    private var text: InputRemapStrings { FeatureStrings.inputRemap(l10n.language) }

    var body: some View {
        Form {
            Section {
                Toggle(text.title, isOn: $enabled)
                    .onChange(of: enabled) { _, _ in
                        save()
                        FeatureRuntime.shared.sync([.inputRemapping])
                    }
                Text(text.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if enabled, !AXIsProcessTrusted() {
                    Text(text.permission)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section {
                ForEach(rules) { rule in
                    ruleRow(rule)
                }
                Button(text.addRule) {
                    newSource = nil
                    newTarget = nil
                    adding = true
                }
                if failed {
                    Text(text.failed)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: load)
        .sheet(isPresented: $adding) {
            addSheet
        }
    }

    private func ruleRow(_ rule: InputRemapRule) -> some View {
        HStack(spacing: 10) {
            Text(shortcut(for: rule.sourceKeyCode, rule.sourceModifiers).displayString)
                .frame(width: 90, alignment: .leading)
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            Text(shortcut(for: rule.targetKeyCode, rule.targetModifiers).displayString)
                .foregroundStyle(.secondary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { value in
                    if let index = rules.firstIndex(where: { $0.id == rule.id }) {
                        rules[index].enabled = value
                        save()
                    }
                }
            ))
            .labelsHidden()
            Button(role: .destructive) {
                rules.removeAll { $0.id == rule.id }
                save()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    private var addSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(text.addRule).font(.headline)
            HStack {
                Text(text.from)
                ShortcutRecorderButton(
                    shortcut: newSource ?? GlobalShortcut(keyCode: 0, modifiers: []),
                    isEnabled: true,
                    waitingTitle: l10n.s.shortcutPressKeys,
                    emptyTitle: l10n.s.shortcutNone,
                    invalidAction: {},
                    captureAction: { newSource = $0 }
                )
                .frame(width: 120)
            }
            HStack {
                Text(text.to)
                ShortcutRecorderButton(
                    shortcut: newTarget ?? GlobalShortcut(keyCode: 0, modifiers: []),
                    isEnabled: true,
                    waitingTitle: l10n.s.shortcutPressKeys,
                    emptyTitle: l10n.s.shortcutNone,
                    invalidAction: {},
                    captureAction: { newTarget = $0 }
                )
                .frame(width: 120)
            }
            HStack {
                Spacer()
                Button(l10n.s.uninstallerCancel) { adding = false }
                Button(text.addRule) {
                    guard let source = newSource, let target = newTarget else { return }
                    rules.append(InputRemapRule(sourceKeyCode: UInt16(max(0, source.keyCode)),
                                                sourceModifiers: source.modifiers,
                                                targetKeyCode: UInt16(max(0, target.keyCode)),
                                                targetModifiers: target.modifiers))
                    save()
                    adding = false
                }
                .disabled(newSource == nil || newTarget == nil)
            }
        }
        .padding(18)
        .frame(width: 360)
    }

    private func shortcut(for keyCode: UInt16, _ modifiers: GlobalShortcutModifiers) -> GlobalShortcut {
        GlobalShortcut(keyCode: Int64(keyCode), modifiers: modifiers)
    }

    private func load() {
        let data = UserDefaults.standard.data(forKey: DefaultsKey.inputRemapRules) ?? Data()
        rules = (try? JSONDecoder().decode([InputRemapRule].self, from: data)) ?? []
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(InputRemapSupport.sanitized(rules))
            UserDefaults.standard.set(data, forKey: DefaultsKey.inputRemapRules)
            failed = false
        } catch {
            failed = true
        }
        FeatureRuntime.shared.sync([.inputRemapping])
    }
}
