// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Single key-to-key mappings. The page edits the rule list; the service
/// installs a session tap only while the feature is enabled and Accessibility
/// is granted, so a missing permission never swallows a key.
struct InputRemapSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
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
                        FeatureRuntime.shared.sync([.inputRemapping])
                    }
                Text(text.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if enabled, !permissions.accessibility {
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
                    failed = false
                    adding = true
                }
                .disabled(rules.count >= InputRemapSupport.maximumRules)
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
                        var edited = rules
                        edited[index].enabled = value
                        save(edited)
                    }
                }
            ))
            .labelsHidden()
            Button(role: .destructive) {
                save(rules.filter { $0.id != rule.id })
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
                    shortcut: newSource,
                    isEnabled: true,
                    waitingTitle: l10n.s.shortcutPressKeys,
                    requiresModifier: false,
                    capturesEditingKeys: true,
                    emptyTitle: newSource == nil ? l10n.s.shortcutNone : nil,
                    invalidAction: {},
                    captureAction: { newSource = $0 }
                )
                .frame(width: 120)
            }
            HStack {
                Text(text.to)
                ShortcutRecorderButton(
                    shortcut: newTarget,
                    isEnabled: true,
                    waitingTitle: l10n.s.shortcutPressKeys,
                    requiresModifier: false,
                    capturesEditingKeys: true,
                    emptyTitle: newTarget == nil ? l10n.s.shortcutNone : nil,
                    invalidAction: {},
                    captureAction: { newTarget = $0 }
                )
                .frame(width: 120)
            }
            if failed {
                Text(text.failed)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            HStack {
                Spacer()
                Button(l10n.s.uninstallerCancel) { adding = false }
                Button(text.addRule) {
                    guard let source = newSource, let target = newTarget,
                          let sourceCode = UInt16(exactly: source.keyCode),
                          let targetCode = UInt16(exactly: target.keyCode) else { return }
                    let rule = InputRemapRule(sourceKeyCode: sourceCode, sourceModifiers: source.modifiers,
                                              targetKeyCode: targetCode, targetModifiers: target.modifiers)
                    if save(rules + [rule]) { adding = false }
                }
                .disabled(newSource == nil || newTarget == nil || newSource == newTarget)
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
        let decoded = (try? JSONDecoder().decode([InputRemapRule].self, from: data)) ?? []
        rules = InputRemapSupport.sanitized(decoded)
    }

    @discardableResult
    private func save(_ edited: [InputRemapRule]) -> Bool {
        let cleaned = InputRemapSupport.sanitized(edited)
        guard cleaned == edited, let data = try? JSONEncoder().encode(cleaned) else {
            failed = true
            return false
        }
        UserDefaults.standard.set(data, forKey: DefaultsKey.inputRemapRules)
        rules = cleaned
        failed = false
        FeatureRuntime.shared.sync([.inputRemapping])
        return true
    }
}
