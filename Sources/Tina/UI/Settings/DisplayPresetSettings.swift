// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The preset list on Settings → Energy → Displays. Rows apply, update, edit
/// and delete; a sheet creates and edits names, icons, shortcuts and the
/// automatic rule. Failures from the last apply are listed under the rows.
struct DisplayPresetSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = DisplayPresetService.shared
    @State private var editor: DisplayPresetEditorState?
    @State private var pendingDelete: DisplayPreset?
    @State private var confirmingDelete = false

    private var strings: DisplayPresetStrings { FeatureStrings.displayPreset(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(strings.title)
                        .font(.subheadline.weight(.semibold))
                    Text(strings.caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Button {
                    editor = DisplayPresetEditorState(
                        mode: .create,
                        name: "",
                        symbol: DisplayPresetSupport.defaultSymbol,
                        shortcutValue: "",
                        triggerEnabled: false,
                        triggerFingerprint: "",
                        triggerEvent: .connected,
                        candidates: service.triggerCandidates())
                } label: {
                    Label(strings.saveCurrent, systemImage: "plus")
                }
                .controlSize(.small)
            }
            if service.presets.isEmpty {
                Text(strings.empty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(service.presets) { preset in
                    presetRow(preset)
                }
            }
            if let report = service.lastReport, report.failed {
                reportView(report)
            }
        }
        .sheet(item: $editor) { state in
            DisplayPresetEditorSheet(state: state)
        }
        .alert(strings.deleteTitle, isPresented: $confirmingDelete, presenting: pendingDelete) { preset in
            Button(strings.delete, role: .destructive) { service.delete(id: preset.id) }
            Button(strings.cancel, role: .cancel) {}
        } message: { _ in
            Text(strings.deleteBody)
        }
    }

    private func presetRow(_ preset: DisplayPreset) -> some View {
        HStack(spacing: 10) {
            Image(systemName: preset.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                    .lineLimit(1)
                if let trigger = preset.trigger {
                    Text(triggerCaption(trigger))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Button(strings.apply) { service.apply(id: preset.id) }
                .controlSize(.small)
                .disabled(service.isApplying)
            Menu {
                Button(strings.update) { service.updateFromCurrent(id: preset.id) }
                Button(strings.edit) {
                    editor = DisplayPresetEditorState(preset: preset,
                                                      candidates: candidates(for: preset))
                }
                Divider()
                Button(strings.delete, role: .destructive) {
                    pendingDelete = preset
                    confirmingDelete = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .frame(width: 26)
        }
        .disabled(service.isApplying)
    }

    private func triggerCaption(_ trigger: DisplayPreset.Trigger) -> String {
        let event = trigger.event == .connected ? strings.autoConnected : strings.autoDisconnected
        return "\(strings.autoTitle): \(trigger.displayName) \(event)"
    }

    /// Saved displays first, so a rule on a display that is not connected now
    /// can still be edited, then whatever is connected.
    private func candidates(for preset: DisplayPreset) -> [DisplayPresetCandidate] {
        var result = preset.displays.map {
            DisplayPresetCandidate(fingerprint: $0.fingerprint,
                                   name: DisplayPresetSupport.displayLabel($0))
        }
        for candidate in service.triggerCandidates()
        where !result.contains(where: { $0.fingerprint == candidate.fingerprint }) {
            result.append(candidate)
        }
        return result
    }

    private func reportView(_ report: DisplayPresetReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(strings.failuresTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                Spacer(minLength: 8)
                Button(l10n.s.actionClear) { service.dismissReport() }
                    .buttonStyle(.link)
                    .font(.caption)
            }
            ForEach(Array(report.failures.enumerated()), id: \.offset) { _, failure in
                Text(displayPresetFailureText(failure, strings: strings))
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Turns one failed item into the sentence the user sees. Every kind names
/// the display it belongs to.
func displayPresetFailureText(_ failure: DisplayPresetReport.Failure,
                              strings: DisplayPresetStrings) -> String {
    let format: String
    switch failure.kind {
    case .notConnected: format = strings.failureNotConnected
    case .resolutionUnsupported: format = strings.failureResolutionUnsupported
    case .resolutionFailed: format = strings.failureResolutionFailed
    case .brightnessUnavailable: format = strings.failureBrightnessUnavailable
    case .volumeUnavailable: format = strings.failureVolumeUnavailable
    case .mainDisplayFailed: format = strings.failureMainDisplay
    }
    return String(format: format, failure.displayName)
}

/// What the create or edit sheet is working on, kept as a value so the sheet
/// can be cancelled without touching the stored preset.
private struct DisplayPresetEditorState: Identifiable {
    enum Mode {
        case create
        case edit(UUID)
    }

    let id = UUID()
    let mode: Mode
    var name: String
    var symbol: String
    var shortcutValue: String
    var triggerEnabled: Bool
    var triggerFingerprint: String
    var triggerEvent: DisplayPreset.Trigger.Event
    var candidates: [DisplayPresetCandidate]

    init(mode: Mode, name: String, symbol: String, shortcutValue: String,
         triggerEnabled: Bool, triggerFingerprint: String,
         triggerEvent: DisplayPreset.Trigger.Event,
         candidates: [DisplayPresetCandidate]) {
        self.mode = mode
        self.name = name
        self.symbol = symbol
        self.shortcutValue = shortcutValue
        self.triggerEnabled = triggerEnabled
        self.triggerFingerprint = triggerFingerprint
        self.triggerEvent = triggerEvent
        self.candidates = candidates
    }

    init(preset: DisplayPreset, candidates: [DisplayPresetCandidate]) {
        self.init(mode: .edit(preset.id),
                  name: preset.name,
                  symbol: preset.symbol,
                  shortcutValue: preset.shortcut ?? "",
                  triggerEnabled: preset.trigger != nil,
                  triggerFingerprint: preset.trigger?.fingerprint ?? candidates.first?.fingerprint ?? "",
                  triggerEvent: preset.trigger?.event ?? .connected,
                  candidates: candidates)
    }
}

private struct DisplayPresetEditorSheet: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = DisplayPresetService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var state: DisplayPresetEditorState
    @State private var message: String?

    init(state: DisplayPresetEditorState) {
        _state = State(initialValue: state)
    }

    private var strings: DisplayPresetStrings { FeatureStrings.displayPreset(l10n.language) }

    private var title: String {
        if case .create = state.mode { return strings.newTitle }
        return strings.editTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)

            VStack(alignment: .leading, spacing: 5) {
                Text(strings.nameLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(strings.namePlaceholder, text: $state.name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(strings.iconLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 32), spacing: 6)], spacing: 6) {
                    ForEach(DisplayPresetSupport.symbols, id: \.self) { symbol in
                        iconButton(symbol)
                    }
                }
            }

            HStack(spacing: 10) {
                Text(strings.shortcutLabel)
                Spacer()
                ShortcutRecorderButton(
                    shortcut: GlobalShortcut(storageValue: state.shortcutValue) ?? .keepAwakeDefault,
                    isEnabled: true,
                    waitingTitle: l10n.s.shortcutPressKeys,
                    emptyTitle: state.shortcutValue.isEmpty ? l10n.s.shortcutNone : nil,
                    clearAction: {
                        state.shortcutValue = ""
                        message = nil
                    },
                    notCapturedAction: { message = l10n.s.shortcutNotCaptured },
                    recordingChanged: { if $0 { message = nil } },
                    invalidAction: { message = l10n.s.shortcutInvalid },
                    captureAction: { shortcut in
                        state.shortcutValue = shortcut.storageValue
                        message = nil
                    })
                    .frame(width: 160)
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle(strings.autoToggle, isOn: $state.triggerEnabled)
                    .disabled(state.candidates.isEmpty)
                if state.triggerEnabled, !state.candidates.isEmpty {
                    HStack(spacing: 8) {
                        Text(strings.autoDisplay)
                        Picker(strings.autoDisplay, selection: $state.triggerFingerprint) {
                            ForEach(state.candidates) { candidate in
                                Text(candidate.name).tag(candidate.fingerprint)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        Text(strings.autoWhen)
                        Picker(strings.autoWhen, selection: $state.triggerEvent) {
                            Text(strings.autoConnected).tag(DisplayPreset.Trigger.Event.connected)
                            Text(strings.autoDisconnected).tag(DisplayPreset.Trigger.Event.disconnected)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        Spacer()
                    }
                }
                Text(strings.autoCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button(strings.cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(strings.saveButton) { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear { syncTriggerSelection() }
        .onChange(of: state.triggerEnabled) { _, _ in syncTriggerSelection() }
    }

    private func iconButton(_ symbol: String) -> some View {
        Button {
            state.symbol = symbol
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 32, height: 30)
                .foregroundStyle(state.symbol == symbol ? Color.accentColor : Color.secondary)
                .background(state.symbol == symbol ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol)
    }

    private func syncTriggerSelection() {
        guard state.triggerEnabled, !state.candidates.isEmpty,
              !state.candidates.contains(where: { $0.fingerprint == state.triggerFingerprint })
        else { return }
        state.triggerFingerprint = state.candidates[0].fingerprint
    }

    private func save() {
        let trigger: DisplayPreset.Trigger? = state.triggerEnabled
            ? state.candidates.first(where: { $0.fingerprint == state.triggerFingerprint }).map {
                DisplayPreset.Trigger(fingerprint: $0.fingerprint,
                                      displayName: $0.name,
                                      event: state.triggerEvent)
            }
            : nil
        guard !state.triggerEnabled || trigger != nil else { return }
        let shortcut = GlobalShortcut(storageValue: state.shortcutValue)
        switch state.mode {
        case .create:
            guard let created = service.createPreset(name: state.name, symbol: state.symbol,
                                                      trigger: trigger) else { return }
            if let shortcut { service.setShortcut(shortcut, for: created.id) }
        case .edit(let id):
            service.updateDetails(id: id, name: state.name, symbol: state.symbol, trigger: trigger)
            service.setShortcut(shortcut, for: id)
        }
        dismiss()
    }
}
