// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// One trigger, one existing feature switch. The page edits the rule list and
/// shows the recent runs; it never chains actions or offers a destructive one.
struct AutomationSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = AutomationService.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.automationEnabled) private var enabled = false
    @State private var rules: [AutomationRule] = []
    @State private var adding = false

    private var text: AutomationStrings { FeatureStrings.automation(l10n.language) }
    private var installedSwitches: [AppFeature] {
        AppFeature.allCases.filter { $0.isAvailable && AutomationSupport.featureSwitches[$0] != nil }
    }

    var body: some View {
        Form {
            Section {
                Toggle(text.title, isOn: $enabled)
                    .onChange(of: enabled) { _, _ in features.sync([.automation]) }
                Text(text.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(rules) { rule in
                    ruleRow(rule)
                }
                Button(text.addRule) { adding = true }
                    .disabled(rules.count >= AutomationSupport.maximumRules || installedSwitches.isEmpty)
            }

            if !service.recentRuns.isEmpty {
                Section(text.history) {
                    ForEach(service.recentRuns) { run in
                        LabeledContent(run.ruleName, value: run.detail)
                            .font(.caption)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: load)
        .sheet(isPresented: $adding) {
            AddAutomationRuleView(installed: installedSwitches, existing: rules) { rule in
                rules.append(rule)
                save()
                adding = false
            } onCancel: {
                adding = false
            }
        }
    }

    private func ruleRow(_ rule: AutomationRule) -> some View {
        HStack(spacing: 10) {
            Text(triggerText(rule.trigger))
                .font(.system(size: 12, weight: .medium))
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            Text(actionText(rule.action))
                .font(.caption)
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

    private func triggerText(_ trigger: AutomationTrigger) -> String {
        switch trigger {
        case .schedule(let hour, let minute, _):
            return String(format: "⏰ %02d:%02d", hour, minute)
        case .power(let connected): return connected ? "⚡ on" : "⚡ off"
        case .display(let connected): return connected ? "🖥 +" : "🖥 −"
        case .app(let bundleID): return "▶︎ \(bundleID)"
        }
    }

    private func actionText(_ action: AutomationAction) -> String {
        guard case .feature(let id, let on) = action,
              let feature = AppFeature(rawValue: id) else { return idDescription(action) }
        let hub = FeatureStrings.hub(l10n.language)
        return feature.hubTitle(l10n.s, hub: hub) + " · " + (on ? text.turnOn : text.turnOff)
    }

    private func idDescription(_ action: AutomationAction) -> String {
        if case .feature(let id, _) = action { return id }
        return ""
    }

    private func load() {
        let data = UserDefaults.standard.data(forKey: DefaultsKey.automationRules) ?? Data()
        rules = AutomationSupport.configuredRules(
            (try? JSONDecoder().decode([AutomationRule].self, from: data)) ?? [])
    }

    private func save() {
        rules = AutomationSupport.configuredRules(rules)
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: DefaultsKey.automationRules)
        }
        FeatureRuntime.shared.sync([.automation])
    }
}

private struct AddAutomationRuleView: View {
    @ObservedObject private var l10n = L10n.shared
    let installed: [AppFeature]
    let existing: [AutomationRule]
    let onSave: (AutomationRule) -> Void
    let onCancel: () -> Void

    private enum TriggerKind: Int, CaseIterable, Identifiable {
        case schedule, power, display, app
        var id: Int { rawValue }
    }

    @State private var kind: TriggerKind = .schedule
    @State private var hour = 9
    @State private var minute = 0
    @State private var connected = true
    @State private var bundleID = ""
    @State private var featureID: String?
    @State private var turnOn = true

    private var text: AutomationStrings { FeatureStrings.automation(l10n.language) }
    private var draft: AutomationRule? {
        guard let featureID, installed.contains(where: { $0.rawValue == featureID }),
              kind != .app || !bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return AutomationRule(trigger: trigger, action: .feature(id: featureID, enabled: turnOn))
    }

    private var isDuplicate: Bool {
        guard let draft else { return false }
        let signature = AutomationSupport.signature(draft)
        return existing.contains { AutomationSupport.signature($0) == signature }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text.addRule).font(.headline)
            Picker(text.when, selection: $kind) {
                Text("⏰").tag(TriggerKind.schedule)
                Text("⚡").tag(TriggerKind.power)
                Text("🖥").tag(TriggerKind.display)
                Text("▶︎").tag(TriggerKind.app)
            }
            .pickerStyle(.segmented)

            switch kind {
            case .schedule:
                HStack {
                    Stepper("\(hour)", value: $hour, in: 0...23)
                    Stepper("\(minute)", value: $minute, in: 0...59, step: 5)
                }
            case .power, .display:
                Toggle(text.turnOn, isOn: $connected)
            case .app:
                TextField("com.vendor.app", text: $bundleID)
            }

            HStack {
                Picker(text.action, selection: $featureID) {
                    ForEach(installed, id: \.self) { feature in
                        Text(feature.hubTitle(l10n.s,
                                              hub: FeatureStrings.hub(l10n.language)))
                            .tag(Optional(feature.rawValue))
                    }
                }
                Toggle(text.turnOn, isOn: $turnOn)
            }

            HStack {
                Spacer()
                Button(l10n.s.uninstallerCancel, action: onCancel)
                Button(text.addRule) {
                    if let draft, !isDuplicate { onSave(draft) }
                }
                .disabled(draft == nil || isDuplicate || existing.count >= AutomationSupport.maximumRules)
            }
            if isDuplicate {
                Text(text.duplicateRule)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(width: 420)
        .onAppear { featureID = installed.first?.rawValue }
    }

    private var trigger: AutomationTrigger {
        switch kind {
        case .schedule: return .schedule(hour: hour, minute: minute,
                                         weekdays: Array(1...7))
        case .power: return .power(connected: connected)
        case .display: return .display(connected: connected)
        case .app: return .app(bundleID: bundleID.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
