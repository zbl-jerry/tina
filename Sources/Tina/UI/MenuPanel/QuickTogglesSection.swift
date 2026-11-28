// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The quick toggles tab of the menu panel: one-click system actions, each an
/// action row that can be hidden and reordered in the section's edit mode.
struct QuickTogglesSection: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var draggingItem: QuickToggleAction?
    var collapsible = true

    var body: some View {
        PanelSection(.toggles,
                     title: FeatureStrings.quickToggles(l10n.language).pageTitle,
                     collapsible: collapsible,
                     supportsEditing: true,
                     resetAction: QuickTogglesList.resetPanelDefaults) { editing in
            QuickTogglesList(editing: editing, draggingItem: $draggingItem) {
                appDelegate()?.closePopover()
            }
            // Actions here activate other apps (the Finder restarting, System
            // Events, the Trash confirmation), which would dismiss the panel
            // mid-flow; holding it open keeps a toggle-back one click away.
            // The status icon and switching tabs still close as always.
            .onAppear { PanelInteractionState.shared.viewKeepsPopoverOpen = true }
            .onDisappear { PanelInteractionState.shared.viewKeepsPopoverOpen = false }
        }
    }
}

/// The toggles hosted inside the quick panel (⌃⌘V), replacing the grid like
/// the other utilities do.
struct PanelQuickTogglesView: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var draggingItem: QuickToggleAction?

    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            QuickTogglesList(editing: false, draggingItem: $draggingItem) {
                QuickLauncherService.shared.hide()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label(FeatureStrings.quickToggles(l10n.language).pageTitle, systemImage: "togglepower")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help(l10n.s.uninstallerCancel)
        }
    }
}

/// The shared row list: the menu panel tab and the quick panel host render
/// the same actions, honoring the same order and per-item visibility.
struct QuickTogglesList: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var toggles = QuickTogglesService.shared
    @ObservedObject private var micMute = MicMuteService.shared
    @ObservedObject private var brightness = BrightnessService.shared
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(DefaultsKey.panelToggleDarkMode) private var showDarkMode = true
    @AppStorage(DefaultsKey.panelToggleKeyboardLight) private var showKeyboardLight = true
    @AppStorage(DefaultsKey.panelToggleMicMute) private var showMicMute = true
    @AppStorage(DefaultsKey.panelToggleEmptyTrash) private var showEmptyTrash = true
    @AppStorage(DefaultsKey.panelToggleQuitAllApps) private var showQuitAllApps = true
    @AppStorage(DefaultsKey.panelToggleRestartDock) private var showRestartDock = true
    @AppStorage(DefaultsKey.panelToggleRestartFinder) private var showRestartFinder = true
    @AppStorage(DefaultsKey.panelToggleRestartMenuBar) private var showRestartMenuBar = true
    @AppStorage(DefaultsKey.panelToggleRestartInputMethod) private var showRestartInputMethod = true
    @AppStorage(DefaultsKey.panelToggleEjectDisks) private var showEjectDisks = true
    @AppStorage(DefaultsKey.panelToggleHiddenFiles) private var showHiddenFiles = true
    @AppStorage(DefaultsKey.panelToggleDesktopIcons) private var showDesktopIcons = true
    @AppStorage(DefaultsKey.panelToggleLockScreen) private var showLockScreen = true
    @AppStorage(DefaultsKey.panelToggleDisplayOff) private var showDisplayOff = true
    @AppStorage(DefaultsKey.panelToggleScreenSaver) private var showScreenSaver = true
    @AppStorage(DefaultsKey.panelToggleDockAutoHide) private var showDockAutoHide = true
    @AppStorage(DefaultsKey.panelToggleDockLock) private var showDockLock = true
    @AppStorage(DefaultsKey.panelToggleStageManager) private var showStageManager = true
    @AppStorage(DefaultsKey.panelToggleMenuBarAutoHide) private var showMenuBarAutoHide = true
    @AppStorage(DefaultsKey.panelToggleOrder) private var toggleOrderRaw = ""

    let editing: Bool
    @Binding var draggingItem: QuickToggleAction?
    /// Closes whatever surface hosts the list, so actions that take over the
    /// screen (lock, Trash confirmation) never fight the open panel.
    let dismissSurface: () -> Void

    var body: some View {
        PanelRowGroup(items: items, showsDragHandles: editing) { item in
            PanelReorderableItem(item: item,
                                 isEnabled: editing,
                                 previewsAsCard: true,
                                 order: itemOrderBinding,
                                 dragging: $draggingItem) {
                itemView(item)
                    .disabled(!editing && (toggles.state(for: item) == .running
                                           || isUnavailable(item)))
                    .opacity(isUnavailable(item) ? 0.55 : 1)
            }
        }
        .onAppear {
            toggles.refreshPermissionStates()
            toggles.refreshInputMethodTarget()
            brightness.refreshKeyboardLight()
        }
    }

    static func resetPanelDefaults() {
        PanelLayout.resetItemOrder(key: DefaultsKey.panelToggleOrder)
        let defaults = UserDefaults.standard
        for key in [DefaultsKey.panelToggleDarkMode, DefaultsKey.panelToggleKeyboardLight,
                    DefaultsKey.panelToggleMicMute,
                    DefaultsKey.panelToggleEmptyTrash, DefaultsKey.panelToggleQuitAllApps,
                    DefaultsKey.panelToggleRestartDock, DefaultsKey.panelToggleRestartFinder,
                    DefaultsKey.panelToggleRestartMenuBar, DefaultsKey.panelToggleRestartInputMethod,
                    DefaultsKey.panelToggleEjectDisks, DefaultsKey.panelToggleHiddenFiles,
                    DefaultsKey.panelToggleDesktopIcons, DefaultsKey.panelToggleLockScreen,
                    DefaultsKey.panelToggleDisplayOff, DefaultsKey.panelToggleScreenSaver,
                    DefaultsKey.panelToggleDockAutoHide, DefaultsKey.panelToggleDockLock,
                    DefaultsKey.panelToggleStageManager, DefaultsKey.panelToggleMenuBarAutoHide] {
            defaults.set(true, forKey: key)
        }
    }

    // MARK: - Items

    private var orderedItems: [QuickToggleAction] {
        _ = toggleOrderRaw
        return PanelLayout.itemOrder(QuickToggleAction.self, key: DefaultsKey.panelToggleOrder)
    }

    private var itemOrderBinding: Binding<[QuickToggleAction]> {
        Binding {
            orderedItems
        } set: { newValue in
            PanelLayout.setItemOrder(newValue, key: DefaultsKey.panelToggleOrder)
        }
    }

    private var items: [QuickToggleAction] {
        orderedItems.filter {
            $0.feature.isAvailable
                && ($0 != .keyboardLight || brightness.keyboardLightEnabled != nil)
                && (editing || isVisible($0))
        }
    }

    private func isVisible(_ item: QuickToggleAction) -> Bool {
        visibilityBinding(item).wrappedValue
    }

    private func visibilityBinding(_ item: QuickToggleAction) -> Binding<Bool> {
        switch item {
        case .darkMode: return $showDarkMode
        case .keyboardLight: return $showKeyboardLight
        case .micMute: return $showMicMute
        case .emptyTrash: return $showEmptyTrash
        case .quitAllApps: return $showQuitAllApps
        case .restartDock: return $showRestartDock
        case .restartFinder: return $showRestartFinder
        case .restartMenuBar: return $showRestartMenuBar
        case .restartInputMethod: return $showRestartInputMethod
        case .ejectDisks: return $showEjectDisks
        case .hiddenFiles: return $showHiddenFiles
        case .desktopIcons: return $showDesktopIcons
        case .lockScreen: return $showLockScreen
        case .displayOff: return $showDisplayOff
        case .screenSaver: return $showScreenSaver
        case .dockAutoHide: return $showDockAutoHide
        case .dockLock: return $showDockLock
        case .stageManager: return $showStageManager
        case .menuBarAutoHide: return $showMenuBarAutoHide
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func itemView(_ item: QuickToggleAction) -> some View {
        let strings = FeatureStrings.quickToggles(l10n.language)
        switch item {
        case .darkMode:
            UtilityActionButton(title: colorScheme == .dark ? strings.darkModeToLight : strings.darkModeToDark,
                                caption: caption(for: item, idle: strings.darkModeCaption),
                                systemImage: colorScheme == .dark ? "sun.max.fill" : "moon.fill",
                                isEditing: editing,
                                showsDragHandle: true,
                                visibility: visibilityBinding(item),
                                captionStaysVisible: reportsState(item),
                                action: {
                                    QuickTogglesService.shared.toggleDarkMode()
                                })
        case .keyboardLight:
            let brightnessStrings = FeatureStrings.brightness(l10n.language)
            PanelToggleRow(title: brightnessStrings.keyboardLight,
                           caption: brightnessStrings.keyboardLightCaption,
                           systemImage: "keyboard",
                           isOn: Binding(
                               get: { brightness.keyboardLightEnabled ?? false },
                               set: { brightness.setKeyboardLightEnabled($0) }
                           ),
                           isEditing: editing,
                           showsDragHandle: true,
                           visibility: visibilityBinding(item))
        case .micMute:
            UtilityActionButton(title: micMute.isMuted ? l10n.s.micUnmuteName : l10n.s.micMuteName,
                                caption: micMute.warning?.message ?? l10n.s.micMuteCaption,
                                systemImage: micMute.controlSymbol,
                                isEditing: editing,
                                showsDragHandle: true,
                                visibility: $showMicMute,
                                needsAttention: micMute.warning != nil,
                                shortcutHint: shortcutHint(.micMute),
                                action: {
                                    MicMuteService.shared.toggle()
                                })
        case .emptyTrash:
            UtilityActionButton(title: strings.emptyTrashTitle,
                                caption: caption(for: item, idle: strings.emptyTrashCaption),
                                systemImage: "trash",
                                isEditing: editing,
                                showsDragHandle: true,
                                visibility: visibilityBinding(item),
                                needsAttention: needsPermission(item),
                                captionStaysVisible: reportsState(item),
                                permissionButtonTitle: permissionButtonTitle(item),
                                permissionAction: permissionAction(item),
                                action: {
                                    // The confirmation alert opens centered and
                                    // key; the panel stays put behind it.
                                    QuickTogglesService.shared.emptyTrash()
                                })
        case .quitAllApps:
            UtilityActionButton(title: strings.quitAllTitle,
                                caption: caption(for: item, idle: l10n.s.quitAppsCaption),
                                systemImage: "xmark.app",
                                isEditing: editing,
                                showsDragHandle: true,
                                visibility: visibilityBinding(item),
                                shortcutHint: shortcutHint(.quitAll),
                                action: {
                                    QuickTogglesService.shared.showQuitApps()
                                })
        case .restartDock:
            restartRow(item, title: strings.restartDockTitle,
                       caption: strings.restartDockCaption,
                       systemImage: "dock.rectangle")
        case .restartFinder:
            restartRow(item, title: strings.restartFinderTitle,
                       caption: strings.restartFinderCaption,
                       systemImage: "face.smiling")
        case .restartMenuBar:
            restartRow(item, title: strings.restartMenuBarTitle,
                       caption: strings.restartMenuBarCaption,
                       systemImage: "menubar.rectangle")
        case .restartInputMethod:
            // The row stays in place without a target, dimmed with the reason
            // in its caption instead of vanishing from the list.
            let idle = toggles.inputMethodTarget == nil
                ? strings.restartInputMethodUnavailable
                : strings.restartInputMethodCaption
            restartRow(item, title: strings.restartInputMethodTitle,
                       caption: idle,
                       systemImage: "character.cursor.ibeam")
        case .ejectDisks:
            // Anything but the plain description is news: nothing to eject,
            // ejecting now, or a failure.
            let eject = ejectCaption(strings)
            UtilityActionButton(title: strings.ejectTitle,
                                caption: eject,
                                systemImage: "eject.fill",
                                isEditing: editing,
                                showsDragHandle: true,
                                visibility: visibilityBinding(item),
                                captionStaysVisible: eject != strings.ejectCaption,
                                action: {
                                    QuickTogglesService.shared.ejectAllDisks()
                                })
        case .hiddenFiles:
            UtilityActionButton(title: toggles.hiddenFilesShown ? strings.hiddenFilesHide : strings.hiddenFilesShow,
                                caption: caption(for: item, idle: strings.finderRestartCaption),
                                systemImage: toggles.hiddenFilesShown ? "eye.slash" : "eye",
                                isEditing: editing,
                                showsDragHandle: true,
                                visibility: visibilityBinding(item),
                                captionStaysVisible: true,
                                action: {
                                    QuickTogglesService.shared.toggleHiddenFiles()
                                })
        case .desktopIcons:
            UtilityActionButton(title: toggles.desktopIconsShown ? strings.desktopIconsHide : strings.desktopIconsShow,
                                caption: caption(for: item, idle: strings.finderRestartCaption),
                                systemImage: "desktopcomputer",
                                isEditing: editing,
                                showsDragHandle: true,
                                visibility: visibilityBinding(item),
                                captionStaysVisible: true,
                                action: {
                                    QuickTogglesService.shared.toggleDesktopIcons()
                                })
        case .lockScreen:
            UtilityActionButton(title: strings.lockScreenTitle,
                                caption: strings.lockScreenCaption,
                                systemImage: "lock.fill",
                                isEditing: editing,
                                showsDragHandle: true,
                                visibility: visibilityBinding(item),
                                action: {
                                    dismissSurface()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        QuickTogglesService.shared.lockScreen()
                                    }
                                })
        case .displayOff:
            UtilityActionButton(title: strings.displayOffTitle,
                                caption: caption(for: item, idle: strings.displayOffCaption),
                                systemImage: "display",
                                isEditing: editing,
                                showsDragHandle: true,
                                visibility: visibilityBinding(item),
                                captionStaysVisible: reportsState(item),
                                action: {
                                    dismissSurface()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        QuickTogglesService.shared.turnDisplayOff()
                                    }
                                })
        case .screenSaver:
            UtilityActionButton(title: strings.screenSaverTitle,
                                caption: strings.screenSaverCaption,
                                systemImage: "sparkles.tv",
                                isEditing: editing,
                                showsDragHandle: true,
                                visibility: visibilityBinding(item),
                                action: {
                                    dismissSurface()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        QuickTogglesService.shared.startScreenSaver()
                                    }
                                })
        case .dockAutoHide:
            systemSwitchRow(item, title: strings.dockAutoHideTitle,
                            caption: strings.dockAutoHideCaption,
                            systemImage: "dock.rectangle",
                            isOn: { toggles.dockAutoHideEnabled })
        case .dockLock:
            systemSwitchRow(item, title: strings.dockLockTitle,
                            caption: strings.dockLockCaption,
                            systemImage: "lock.square",
                            isOn: { toggles.dockLockEnabled })
        case .stageManager:
            systemSwitchRow(item, title: strings.stageManagerTitle,
                            caption: strings.stageManagerCaption,
                            systemImage: "rectangle.3.group",
                            isOn: { toggles.stageManagerEnabled })
        case .menuBarAutoHide:
            systemSwitchRow(item, title: strings.menuBarAutoHideTitle,
                            caption: strings.menuBarAutoHideCaption,
                            systemImage: "menubar.rectangle",
                            isOn: { toggles.menuBarAutoHideEnabled })
        }
    }

    // MARK: - Row state

    /// True while the caption is a failure or permission note rather than the
    /// idle description, so the row keeps it in view.
    /// One of the four system component rows (issue #36). They differ only in
    /// copy and symbol, so the row shape is shared.
    private func restartRow(_ item: QuickToggleAction,
                            title: String,
                            caption idle: String,
                            systemImage: String) -> some View {
        UtilityActionButton(title: title,
                            caption: caption(for: item, idle: idle),
                            systemImage: systemImage,
                            isEditing: editing,
                            showsDragHandle: true,
                            visibility: visibilityBinding(item),
                            captionStaysVisible: isUnavailable(item) || reportsState(item),
                            action: {
                                QuickTogglesService.shared.requestRestart(item)
                            })
    }

    /// One of the four system preference switches (issue #29). The toggle is
    /// bound to a fresh read of the preference; flipping it runs the write and
    /// relaunch off the main thread. The value changes when the service bumps
    /// its revision, never before the system took it.
    private func systemSwitchRow(_ item: QuickToggleAction,
                                 title: String,
                                 caption idle: String,
                                 systemImage: String,
                                 isOn: @escaping () -> Bool) -> some View {
        PanelToggleRow(title: title,
                       caption: caption(for: item, idle: idle),
                       systemImage: systemImage,
                       isOn: Binding(get: isOn,
                                     set: { toggles.setSystemSwitch(item, enabled: $0) }),
                       isEditing: editing,
                       showsDragHandle: true,
                       visibility: visibilityBinding(item),
                       isActive: item.relaunchesComponent && toggles.state(for: item) == .running,
                       activeText: FeatureStrings.quickToggles(l10n.language).restartInProgress,
                       needsAttention: toggles.state(for: item) == .failed
                           || toggles.state(for: item) == .rollbackFailed)
    }

    private func reportsState(_ item: QuickToggleAction) -> Bool {
        switch toggles.state(for: item) {
        case .failed, .rollbackFailed, .needsPermission, .succeeded: return true
        case .running, .none: return false
        }
    }

    /// The input method row is present but unusable when no third-party input
    /// method is running; its caption says why rather than leaving a silent
    /// no-op.
    private func isUnavailable(_ item: QuickToggleAction) -> Bool {
        item == .restartInputMethod && toggles.inputMethodTarget == nil
    }

    /// The idle caption, replaced by a progress, result or failure note; a
    /// plain success in the other rows needs no caption, the row itself
    /// already reflects the new state.
    private func caption(for item: QuickToggleAction, idle: String) -> String {
        let strings = FeatureStrings.quickToggles(l10n.language)
        switch toggles.state(for: item) {
        case .failed: return strings.actionFailed
        case .rollbackFailed: return strings.systemSwitchRollbackFailed
        case .succeeded: return strings.restartSucceeded
        case .needsPermission:
            return "\(l10n.s.permissionRequired): \(permissionName(item))"
        case .running:
            return item.relaunchesComponent ? strings.restartInProgress : idle
        case .none: return idle
        }
    }

    private func shortcutHint(_ role: GlobalShortcutRole) -> String? {
        guard role.requiredEnableKeys.allSatisfy({ UserDefaults.standard.bool(forKey: $0) })
        else { return nil }
        return role.assignedShortcut()?.displayString
    }

    private func ejectCaption(_ strings: QuickToggleFeatureStrings) -> String {
        switch toggles.state(for: .ejectDisks) {
        case .running: return l10n.s.diskEjecting
        case .failed, .rollbackFailed: return l10n.s.diskEjectFailed
        case .needsPermission, .succeeded, .none:
            return toggles.ejectableVolumeCount() > 0 ? strings.ejectCaption : l10n.s.diskNoExternal
        }
    }

    private func needsPermission(_ item: QuickToggleAction) -> Bool {
        toggles.state(for: item) == .needsPermission
    }

    /// Only the Trash talks to another app (the Finder); everything else
    /// works without a permission.
    private func permissionName(_ item: QuickToggleAction) -> String {
        FeatureStrings.hub(l10n.language).permAutomationFinder
    }

    private func permissionButtonTitle(_ item: QuickToggleAction) -> String? {
        needsPermission(item) ? l10n.s.permissionOpenSettings : nil
    }

    /// A declined Automation consent never re-prompts by itself; the row
    /// swaps into a button that opens the Automation pane instead.
    private func permissionAction(_ item: QuickToggleAction) -> (() -> Void)? {
        guard needsPermission(item) else { return nil }
        return {
            Permissions.shared.openAutomationSettings()
        }
    }
}
