// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AVFoundation
import SwiftUI

/// Settings for the screen recorder: how a recording starts, what it captures
/// and where the file lands. Everything a person rarely touches sits behind
/// one disclosure, so the page reads at a glance.
struct ScreenRecordingCaptureSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var service = ScreenRecorderService.shared
    @ObservedObject private var sharing = RecordingShareService.shared
    @AppStorage(DefaultsKey.recorderCountdown) private var countdown = 3
    @AppStorage(DefaultsKey.recorderQuality) private var qualityRaw =
        RecorderSupport.Quality.balanced.rawValue
    @AppStorage(DefaultsKey.recorderFrameRate) private var frameRate = 60
    @AppStorage(DefaultsKey.recorderSystemAudio) private var systemAudio = true
    @AppStorage(DefaultsKey.recorderMicrophone) private var microphone = false
    @AppStorage(DefaultsKey.recorderCameraOverlay) private var cameraOverlay = false
    @AppStorage(DefaultsKey.recorderCameraDevice) private var cameraDevice = ""
    @AppStorage(DefaultsKey.recorderCameraShape) private var cameraShape =
        RecorderCameraShape.circle.rawValue
    @AppStorage(DefaultsKey.recorderCameraMirror) private var cameraMirror = true
    @AppStorage(DefaultsKey.recorderCameraShadow) private var cameraShadow = true
    @State private var cameras: [AVCaptureDevice] = []
    @AppStorage(DefaultsKey.recorderSaveFolder) private var saveFolder = ""
    @AppStorage(DefaultsKey.recorderOpenEditor) private var opensEditor = true
    @AppStorage(DefaultsKey.recorderAutomaticZoom) private var automaticZoom = true
    @AppStorage(DefaultsKey.recorderKeystrokesEnabled) private var keystrokesEnabled = false
    @AppStorage(DefaultsKey.recorderKeystrokePlacement) private var keystrokePlacement =
        RecorderKeystrokePlacement.bottomTrailing.rawValue
    @AppStorage(DefaultsKey.recorderKeystrokeSize) private var keystrokeSize =
        RecorderKeystrokeSize.medium.rawValue
    @AppStorage(DefaultsKey.recorderKeystrokeDwell) private var keystrokeDwell = 2.0
    @AppStorage(DefaultsKey.recorderKeystrokeTheme) private var keystrokeTheme =
        RecorderKeystrokeTheme.dark.rawValue
    @AppStorage(DefaultsKey.recorderGIFFrameRate) private var gifFrameRate = 12
    @AppStorage(DefaultsKey.recorderSharingEnabled) private var sharingEnabled = true
    @State private var showsMoreOptions = false
    @State private var showingSharedLinks = false
    @State private var showingSharePrivacy = false

    private var strings: RecorderFeatureStrings {
        FeatureStrings.recorder(l10n.language)
    }

    private var shareStrings: RecorderShareStrings {
        FeatureStrings.recorderShare(l10n.language)
    }

    private var screenshotStrings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    var body: some View {
        Group {
            Section {
                Button {
                    ScreenRecorderService.shared.toggle()
                } label: {
                    Label(service.isRecording ? strings.stopButton : strings.startButton,
                          systemImage: service.isRecording ? "stop.circle" : "record.circle")
                }
                Text(service.isRecording
                     ? RecorderSupport.elapsedLabel(seconds: service.elapsedSeconds)
                     : strings.panelCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if !permissions.screenRecording {
                    PermissionRow(kind: .screenRecording)
                }
                if !permissions.accessibility {
                    PermissionRow(kind: .accessibility)
                }
            } header: {
                Text(strings.pageTitle)
            }
            .settingsFormSectionAnchor(.screenRecorder)

            Section {
                Picker(strings.countdownLabel, selection: $countdown) {
                    ForEach(ScreenshotSupport.allowedDelays, id: \.self) { seconds in
                        if seconds == 0 {
                            Text(strings.countdownOff).tag(0)
                        } else {
                            Text(String(format: strings.countdownSecondsFormat, seconds)).tag(seconds)
                        }
                    }
                }
                .pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(strings.systemAudioToggle, isOn: $systemAudio)
                    Text(strings.systemAudioCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(strings.microphoneToggle, isOn: $microphone)
                        .onChange(of: microphone) { _, enabled in
                            if enabled, permissions.microphone == .undetermined {
                                permissions.requestMicrophone()
                            }
                        }
                    Text(strings.microphoneCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if microphone, permissions.microphone != .granted {
                        PermissionRow(kind: .microphone)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(strings.cameraToggle, isOn: $cameraOverlay)
                        .onChange(of: cameraOverlay) { _, enabled in
                            guard enabled else { return }
                            cameras = RecorderCameraCapture.devices()
                            if permissions.camera == .undetermined {
                                permissions.requestCamera()
                            }
                        }
                    Text(strings.cameraCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if cameraOverlay {
                        Picker(strings.cameraPickerLabel, selection: $cameraDevice) {
                            ForEach(cameras, id: \.uniqueID) { camera in
                                Text(camera.localizedName).tag(camera.uniqueID)
                            }
                            if cameras.isEmpty {
                                Text(strings.cameraNone).tag("")
                            }
                        }
                        Picker(strings.cameraShapeLabel, selection: $cameraShape) {
                            Text(strings.cameraShapeCircle)
                                .tag(RecorderCameraShape.circle.rawValue)
                            Text(strings.cameraShapeRounded)
                                .tag(RecorderCameraShape.rounded.rawValue)
                        }
                        .pickerStyle(.segmented)
                        Toggle(strings.cameraMirrorToggle, isOn: $cameraMirror)
                        Toggle(strings.cameraShadowToggle, isOn: $cameraShadow)
                        if permissions.camera != .granted {
                            PermissionRow(kind: .camera)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(strings.openEditorToggle, isOn: $opensEditor)
                    Text(strings.openEditorCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(strings.automaticZoomToggle, isOn: $automaticZoom)
                    Text(strings.automaticZoomCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                keyOverlayOptions
            }

            Section {
                folderRow
                DisclosureHeaderRow(isExpanded: $showsMoreOptions) {
                    Text(strings.moreOptions)
                    Spacer()
                }
                if showsMoreOptions {
                    Group {
                        VStack(alignment: .leading, spacing: 4) {
                            Picker(strings.qualityLabel, selection: $qualityRaw) {
                                Text(strings.qualitySmall)
                                    .tag(RecorderSupport.Quality.small.rawValue)
                                Text(strings.qualityBalanced)
                                    .tag(RecorderSupport.Quality.balanced.rawValue)
                                Text(strings.qualityHigh)
                                    .tag(RecorderSupport.Quality.high.rawValue)
                            }
                            Text(strings.qualityCaption)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Picker(strings.frameRateLabel, selection: $frameRate) {
                            ForEach(RecorderSupport.frameRates, id: \.self) { rate in
                                Text(String(format: strings.frameRateFormat, rate)).tag(rate)
                            }
                        }
                        .pickerStyle(.segmented)
                        Picker(strings.gifFrameRateLabel, selection: $gifFrameRate) {
                            ForEach(RecorderSupport.gifFrameRates, id: \.self) { rate in
                                Text(String(format: strings.frameRateFormat, rate)).tag(rate)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .disclosureIndent()
                }
            }

            Section {
                Toggle(screenshotStrings.shareEnabledToggle, isOn: $sharingEnabled)
                if sharingEnabled {
                    Text(shareStrings.caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    showingSharePrivacy = true
                } label: {
                    Label(screenshotStrings.sharePrivacyButton, systemImage: "hand.raised")
                }
                if !sharing.records.isEmpty {
                    Button {
                        showingSharedLinks = true
                    } label: {
                        HStack {
                            Label(screenshotStrings.sharedLinksTitle, systemImage: "link")
                            Spacer()
                            Text("\(sharing.records.count)")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(screenshotStrings.shareSectionTitle)
            }
        }
        .onAppear {
            sharing.refresh()
            cameras = RecorderCameraCapture.devices()
            // A camera remembered on another Mac is not a tag this picker
            // has, so the menu falls back to the first available one.
            if !cameraDevice.isEmpty,
               !cameras.contains(where: { $0.uniqueID == cameraDevice }) {
                cameraDevice = ""
            }
        }
        .sheet(isPresented: $showingSharedLinks) {
            RecorderSharedLinksView()
        }
        .sheet(isPresented: $showingSharePrivacy) {
            RecorderSharePrivacyView()
        }
    }

    /// The optional key row. Off by default; refusing Input Monitoring leaves
    /// the switch off with a way to grant it, instead of silently recording
    /// with no keys.
    private var keyOverlayOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Turning the switch on asks macOS for the grant immediately, the
            // same way the camera and microphone switches do. Leaving it on
            // without the grant records normally and says so at record time;
            // hiding the switch until the grant exists only hid the way to
            // ask for it.
            Toggle(strings.keystrokeToggle, isOn: $keystrokesEnabled)
                .onChange(of: keystrokesEnabled) { _, enabled in
                    if enabled, !permissions.inputMonitoring {
                        permissions.requestInputMonitoring()
                    }
                }
            Text(strings.keystrokeCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !permissions.inputMonitoring {
                Text(strings.keystrokePermissionExplain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                PermissionRow(kind: .inputMonitoring)
            } else if keystrokesEnabled {
                Text(strings.keystrokeSecureInputNote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Picker(strings.keystrokePositionLabel, selection: $keystrokePlacement) {
                    Text(strings.keystrokePositionTopLeading)
                        .tag(RecorderKeystrokePlacement.topLeading.rawValue)
                    Text(strings.keystrokePositionTopTrailing)
                        .tag(RecorderKeystrokePlacement.topTrailing.rawValue)
                    Text(strings.keystrokePositionBottomLeading)
                        .tag(RecorderKeystrokePlacement.bottomLeading.rawValue)
                    Text(strings.keystrokePositionBottomTrailing)
                        .tag(RecorderKeystrokePlacement.bottomTrailing.rawValue)
                    Text(strings.keystrokePositionCursor)
                        .tag(RecorderKeystrokePlacement.cursor.rawValue)
                }
                Picker(strings.keystrokeSizeLabel, selection: $keystrokeSize) {
                    Text(strings.keystrokeSizeSmall)
                        .tag(RecorderKeystrokeSize.small.rawValue)
                    Text(strings.keystrokeSizeMedium)
                        .tag(RecorderKeystrokeSize.medium.rawValue)
                    Text(strings.keystrokeSizeLarge)
                        .tag(RecorderKeystrokeSize.large.rawValue)
                }
                .pickerStyle(.segmented)
                Picker(strings.keystrokeDwellLabel, selection: $keystrokeDwell) {
                    ForEach(RecorderKeystrokeStyle.dwellChoices, id: \.self) { seconds in
                        Text(String(format: strings.keystrokeDwellFormat, Int(seconds)))
                            .tag(seconds)
                    }
                }
                .pickerStyle(.segmented)
                Picker(strings.keystrokeThemeLabel, selection: $keystrokeTheme) {
                    Text(strings.keystrokeThemeDark)
                        .tag(RecorderKeystrokeTheme.dark.rawValue)
                    Text(strings.keystrokeThemeLight)
                        .tag(RecorderKeystrokeTheme.light.rawValue)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var folderRow: some View {
        HStack {
            Text(strings.folderLabel)
            Spacer()
            Text(currentFolderName)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            if !saveFolder.isEmpty {
                Button {
                    saveFolder = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.borderless)
                .screenshotSafeHelp(l10n.s.shortcutReset)
            }
            Button(strings.folderChoose) {
                chooseFolder()
            }
        }
    }

    private var currentFolderName: String {
        let manager = FileManager.default
        if !saveFolder.isEmpty {
            let expanded = (saveFolder as NSString).expandingTildeInPath
            var isDirectory: ObjCBool = false
            if manager.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue {
                return manager.displayName(atPath: expanded)
            }
        }
        let desktop = manager.urls(for: .desktopDirectory, in: .userDomainMask).first
        return desktop.map { manager.displayName(atPath: $0.path) } ?? "Desktop"
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            saveFolder = url.path
        }
    }
}

private struct RecorderSharePrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var l10n = L10n.shared

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    private var shareStrings: RecorderShareStrings {
        FeatureStrings.recorderShare(l10n.language)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(strings.sharePrivacyTitle, systemImage: "hand.raised")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(strings.done) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    privacyParagraph(symbol: "video", text: shareStrings.privacyData)
                    privacyParagraph(symbol: "externaldrive", text: shareStrings.privacyStorage)
                    privacyParagraph(symbol: "person.2", text: shareStrings.privacyAccess)
                }
                .padding(20)
            }
        }
        .frame(width: 560, height: 390)
    }

    private func privacyParagraph(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct RecorderSharedLinksView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var sharing = RecordingShareService.shared
    @State private var deletingID: String?
    @State private var showingDeleteError = false

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(strings.sharedLinksTitle)
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(strings.done) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(18)

            Divider()

            if sharing.records.isEmpty {
                ContentUnavailableView(strings.sharedLinksEmpty,
                                       systemImage: "link.badge.plus")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(sharing.records) { record in
                    linkRow(record)
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 560, height: 360)
        .onAppear { sharing.refresh() }
        .alert(strings.deleteFailedHUD, isPresented: $showingDeleteError) {
            Button(strings.done, role: .cancel) {}
        }
    }

    private func linkRow(_ record: RecordingShareRecord) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "link")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.url.absoluteString)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                HStack(spacing: 4) {
                    Text(strings.expiresLabel)
                    Text(record.expiresAt, style: .relative)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button {
                sharing.copy(record.url)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .screenshotSafeHelp(strings.copyLink)
            Button {
                NSWorkspace.shared.open(record.url)
            } label: {
                Image(systemName: "arrow.up.forward.app")
            }
            .buttonStyle(.borderless)
            .screenshotSafeHelp(strings.openLink)
            Button(role: .destructive) {
                delete(record)
            } label: {
                if deletingID == record.id {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "trash")
                }
            }
            .buttonStyle(.borderless)
            .disabled(deletingID != nil)
            .screenshotSafeHelp(strings.deleteLink)
        }
        .padding(.vertical, 5)
    }

    private func delete(_ record: RecordingShareRecord) {
        deletingID = record.id
        Task { @MainActor in
            do {
                try await sharing.delete(record)
                QuickToolHUD.show(icon: "link", message: strings.linkDeletedHUD)
            } catch {
                showingDeleteError = true
            }
            deletingID = nil
        }
    }
}
