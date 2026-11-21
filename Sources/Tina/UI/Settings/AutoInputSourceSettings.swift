// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The automatic input source page. The global default answers for apps with
/// no rule, each rule answers for one app at the two moments that matter, and
/// an exclusion list wins over both. The rules file is the same JSON the
/// feature stores, so a dotfile can carry it.
struct AutoInputSourceSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = AutoInputSourceService.shared
    @AppStorage(DefaultsKey.autoInputSourceEnabled) private var enabled = false

    @State private var showingRulePicker = false
    @State private var showingExclusionPicker = false
    @State private var pendingImport: AutoInputSourceConfiguration?
    @State private var fileMessage: String?
    @State private var fileMessageIsError = false

    private var strings: AutoInputSourceStrings { FeatureStrings.autoInputSource(l10n.language) }

    var body: some View {
        Form {
            Section {
                Toggle(strings.enabledLabel, isOn: $enabled)
                Text(strings.enabledCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label(enabled && service.isRunning ? strings.statusRunning : strings.statusStopped,
                      systemImage: enabled && service.isRunning ? "checkmark.circle.fill" : "pause.circle")
                    .font(.caption)
                    .foregroundStyle(enabled && service.isRunning ? Color.green : Color.secondary)
            }

            Section(strings.globalTitle) {
                Text(strings.globalCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                behaviorRow(strings.firstActivationLabel,
                            behavior: service.configuration.global.firstActivation,
                            allowFollowGlobal: false) { behavior in
                    service.updateGlobal(firstActivation: true, behavior: behavior)
                }
                behaviorRow(strings.reactivationLabel,
                            behavior: service.configuration.global.reactivation,
                            allowFollowGlobal: false) { behavior in
                    service.updateGlobal(firstActivation: false, behavior: behavior)
                }
            }

            Section(strings.rulesTitle) {
                Text(strings.rulesCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if service.configuration.rules.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(strings.noRules).font(.callout).foregroundStyle(.secondary)
                        Text(strings.noRulesHint).font(.caption).foregroundStyle(.tertiary)
                    }
                } else {
                    ForEach(service.configuration.rules) { rule in
                        ruleRow(rule)
                    }
                }
                Button {
                    showingRulePicker = true
                } label: {
                    Label(strings.addApp, systemImage: "plus")
                }
            }

            Section(strings.neverSwitchTitle) {
                Text(strings.neverSwitchCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if service.configuration.excludedBundleIDs.isEmpty {
                    Text(strings.noExclusions).font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(service.configuration.excludedBundleIDs, id: \.self) { bundleID in
                        HStack(spacing: 9) {
                            Image(nsImage: InstalledApps.icon(for: bundleID))
                                .resizable().frame(width: 20, height: 20)
                            Text(InstalledApps.name(for: bundleID)).lineLimit(1)
                            Spacer()
                            Button {
                                service.removeExclusion(bundleID: bundleID)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(strings.removeApp)
                        }
                    }
                }
                Button {
                    showingExclusionPicker = true
                } label: {
                    Label(strings.addExclusion, systemImage: "plus")
                }
            }

            Section(strings.fileTitle) {
                Text(strings.fileCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button(strings.exportJSON, action: exportRules)
                    Button(strings.importJSON, action: chooseRulesToImport)
                }
                if let fileMessage {
                    Text(fileMessage)
                        .font(.caption)
                        .foregroundStyle(fileMessageIsError ? Color.orange : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section {
                Text(strings.secureInputNote)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .onAppear { service.reload() }
        .onChange(of: enabled) { _, _ in service.syncWithPreferences() }
        .sheet(isPresented: $showingRulePicker) {
            AppPickerView(canBrowseApplications: true) {
                showingRulePicker = false
            } onSelect: { url in
                showingRulePicker = false
                guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
                service.addRule(bundleID: bundleID, appName: InstalledApps.name(for: bundleID))
            } onSelectApp: { app in
                showingRulePicker = false
                guard let bundleID = app.bundleID else { return }
                service.addRule(bundleID: bundleID, appName: app.name)
            } loadApps: {
                InstalledApps.installedBundleApplications(
                    excluding: Set(service.configuration.rules.map(\.bundleID)),
                    includeRunningApplications: true)
            }
        }
        .sheet(isPresented: $showingExclusionPicker) {
            AppPickerView(canBrowseApplications: true) {
                showingExclusionPicker = false
            } onSelect: { url in
                showingExclusionPicker = false
                guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
                service.addExclusion(bundleID: bundleID)
            } onSelectApp: { app in
                showingExclusionPicker = false
                guard let bundleID = app.bundleID else { return }
                service.addExclusion(bundleID: bundleID)
            } loadApps: {
                InstalledApps.installedBundleApplications(
                    excluding: Set(service.configuration.excludedBundleIDs),
                    includeRunningApplications: true)
            }
        }
        .alert(strings.importConfirmTitle,
               isPresented: Binding(get: { pendingImport != nil },
                                    set: { if !$0 { pendingImport = nil } })) {
            Button(l10n.s.uninstallerCancel, role: .cancel) { pendingImport = nil }
            Button(strings.importConfirmAction) {
                if let pendingImport {
                    service.replaceConfiguration(with: pendingImport)
                    fileMessage = String(format: strings.importSuccessFormat,
                                         pendingImport.rules.count)
                    fileMessageIsError = false
                }
                pendingImport = nil
            }
        } message: {
            Text(strings.importConfirmMessage)
        }
    }

    // MARK: - Rows

    private func ruleRow(_ rule: AutoInputSourceRule) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                Image(nsImage: InstalledApps.icon(for: rule.bundleID))
                    .resizable().frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(InstalledApps.name(for: rule.bundleID)).lineLimit(1)
                    if InstalledApps.url(for: rule.bundleID) == nil {
                        Text(strings.ruleMissingApp)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 8)
                Button {
                    service.removeRule(bundleID: rule.bundleID)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(strings.removeApp)
            }
            behaviorRow(strings.firstActivationLabel,
                        behavior: rule.timings.firstActivation,
                        allowFollowGlobal: true) { behavior in
                service.updateRule(bundleID: rule.bundleID, firstActivation: true,
                                   behavior: behavior)
            }
            behaviorRow(strings.reactivationLabel,
                        behavior: rule.timings.reactivation,
                        allowFollowGlobal: true) { behavior in
                service.updateRule(bundleID: rule.bundleID, firstActivation: false,
                                   behavior: behavior)
            }
        }
        .padding(.vertical, 2)
    }

    private func behaviorRow(_ title: String,
                             behavior: AutoInputSourceBehavior,
                             allowFollowGlobal: Bool,
                             onChange: @escaping (AutoInputSourceBehavior) -> Void) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            BehaviorMenu(behavior: behavior,
                         allowFollowGlobal: allowFollowGlobal,
                         sources: service.sources,
                         strings: strings,
                         onChange: onChange)
        }
    }

    // MARK: - Rules file

    private func exportRules() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "tina-auto-input-source.json"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try service.exportData().write(to: url, options: .atomic)
            fileMessage = nil
            fileMessageIsError = false
        } catch {
            fileMessage = strings.exportFailed
            fileMessageIsError = true
        }
    }

    private func chooseRulesToImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url) else {
            fileMessage = strings.importUnreadable
            fileMessageIsError = true
            return
        }
        switch AutoInputSourceSupport.importConfiguration(from: data) {
        case .success(let configuration):
            pendingImport = configuration
        case .failure(let failure):
            fileMessage = message(for: failure)
            fileMessageIsError = true
        }
    }

    private func message(for failure: AutoInputSourceSupport.ImportFailure) -> String {
        switch failure {
        case .unreadable: return strings.importUnreadable
        case .unsupportedFormat: return strings.importUnsupported
        case .newerVersion: return strings.importNewer
        }
    }
}

/// The behavior picker shared by the global default and every app rule. Input
/// sources come last under a divider, because a source name is a different
/// kind of answer from the three policies above it.
private struct BehaviorMenu: View {
    let behavior: AutoInputSourceBehavior
    let allowFollowGlobal: Bool
    let sources: [AutoInputSourceOption]
    let strings: AutoInputSourceStrings
    let onChange: (AutoInputSourceBehavior) -> Void

    var body: some View {
        Menu {
            if allowFollowGlobal {
                Button(strings.behaviorFollowGlobal) {
                    onChange(.followGlobal)
                }
                Divider()
            }
            Button(strings.behaviorRememberLast) { onChange(.rememberLast) }
            Button(strings.behaviorNoSwitch) { onChange(.noSwitch) }
            if !sources.isEmpty {
                Divider()
                ForEach(sources) { source in
                    Button {
                        onChange(.fixed(source.id))
                    } label: {
                        if behavior.fixedSourceID == source.id {
                            Label(source.name, systemImage: "checkmark")
                        } else {
                            Text(source.name)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(displayName)
                    .font(.system(size: 11.5))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(strings.chooseFixedSource)
    }

    private var displayName: String {
        switch behavior.kind {
        case .followGlobal:
            return strings.behaviorFollowGlobal
        case .rememberLast:
            return strings.behaviorRememberLast
        case .noSwitch:
            return strings.behaviorNoSwitch
        case .fixed:
            guard let id = behavior.fixedSourceID else { return strings.sourceFallback }
            return sources.first { $0.id == id }?.name ?? strings.sourceFallback
        }
    }
}
