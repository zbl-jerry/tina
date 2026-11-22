// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The live caption settings: whether the feature is armed, what it listens
/// to, how the bar looks, and where the sessions go.
struct CaptionSettingsCard: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = CaptionService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.captionsEnabled) private var enabled = false
    @AppStorage(DefaultsKey.captionsShortcutEnabled) private var shortcutEnabled = true
    @AppStorage(DefaultsKey.captionsShortcut) private var shortcutStorage =
        GlobalShortcut.captionsDefault.storageValue
    @AppStorage(DefaultsKey.captionsFontSize) private var fontSize = 20.0
    @AppStorage(DefaultsKey.captionsMaxLines) private var maxLines = 2
    @AppStorage(DefaultsKey.captionsAutoSave) private var autoSave = true

    private var strings: CaptionFeatureStrings {
        FeatureStrings.captions(l10n.language)
    }

    private var shortcut: GlobalShortcut {
        GlobalShortcut(storageValue: shortcutStorage) ?? .captionsDefault
    }

    var body: some View {
        SettingsCard(title: strings.title) {
            Toggle(strings.title, isOn: $enabled)
                .onChange(of: enabled) { _, _ in service.syncWithPreferences() }

            Text(strings.hubDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if permissions.speechRecognition != .granted {
                PermissionRow(kind: .speechRecognition)
            }

            Divider()

            languageRow
            Divider()
            appearanceRows
            Divider()
            sessionRows
            Divider()
            shortcutRow

            Text(strings.privacyNote)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear { service.prepareLocales() }
    }

    private var languageRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(strings.sessionLanguage)
                Spacer()
                if CaptionService.availableLocales.isEmpty {
                    Text(strings.onDeviceUnavailable)
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Picker("", selection: localeSelection) {
                        ForEach(CaptionService.availableLocales, id: \.identifier) { locale in
                            Text(service.localeName(locale)).tag(locale.identifier)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 260)
                }
            }
            Text(strings.dictationHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var localeSelection: Binding<String> {
        Binding(
            get: { service.localeIdentifier },
            set: { identifier in
                guard let locale = CaptionService.availableLocales.first(where: {
                    $0.identifier == identifier
                }) else { return }
                service.setLocale(locale)
            }
        )
    }

    private var appearanceRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(strings.fontSize)
                Slider(value: $fontSize,
                       in: CaptionSupport.fontSizeRange,
                       step: 1)
                Text("\(Int(fontSize))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .trailing)
            }
            Stepper(value: $maxLines, in: CaptionSupport.maxLinesRange) {
                Text("\(strings.maxLines): \(maxLines)")
            }
            Button(strings.resetPosition) {
                service.resetOverlayPosition()
            }
        }
    }

    private var sessionRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(strings.autoSave, isOn: $autoSave)
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(strings.saveFolder)
                    Text(service.folderPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button(strings.chooseFolder) { chooseFolder() }
                    .controlSize(.small)
                if service.isUsingCustomFolder {
                    Button(strings.resetFolder) { service.resetFolder() }
                        .controlSize(.small)
                }
            }
            HStack {
                Text(strings.recentSessions)
                Spacer()
                Button(l10n.s.actionRemove) { service.clearHistory() }
                    .controlSize(.small)
                    .disabled(service.recentSessions.isEmpty)
            }
        }
    }

    private var shortcutRow: some View {
        HStack(spacing: 8) {
            Toggle(l10n.s.shortcutsPageTitle, isOn: $shortcutEnabled)
                .onChange(of: shortcutEnabled) { _, _ in service.syncWithPreferences() }
            Spacer()
            ShortcutRecorderButton(
                shortcut: shortcut,
                isEnabled: enabled && shortcutEnabled,
                waitingTitle: l10n.s.shortcutPressKeys,
                recordingChanged: { recording in
                    if recording {
                        service.suspendShortcut()
                    } else {
                        service.syncWithPreferences()
                    }
                },
                invalidAction: {},
                captureAction: { newShortcut in
                    shortcutStorage = newShortcut.storageValue
                    service.syncWithPreferences()
                }
            )
            .frame(width: 108)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = strings.chooseFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        service.setFolder(url)
    }
}
