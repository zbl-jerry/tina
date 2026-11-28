// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// Pure contracts behind the four system switches (issue #29): preference
/// parsing, the write plan and the component it relaunches, the default state,
/// the stored panel layout and the translated copy.
enum QuickTogglesSwitchesTests {
    static func run(_ suite: TestSuite) {
        flagsParseLikeThePreferencesStore(suite)
        plansNameTheOwningComponent(suite)
        statesDefaultOffAndReadBack(suite)
        rollsBackExactValueAndReportsFailure(suite)
        rowsAppendToTheStoredLayout(suite)
        copyIsTranslated(suite)
    }

    private static func rollsBackExactValueAndReportsFailure(_ suite: TestSuite) {
        var stored: CFPropertyList?
        var writes = 0
        var refreshes = 0
        var restorationRefreshes = 0
        let deniedWrite = QuickTogglesSupport.set(.dockAutoHide, enabled: true, read: { stored },
            write: { value in
                // CFPreferences may cache the write even if synchronizing fails.
                stored = value
                writes += 1
                return writes > 1
            }, refresh: { _ in
                refreshes += 1
                return true
            })
        suite.expect(deniedWrite == .failed && writes == 2 && stored == nil && refreshes == 0,
                     "a rejected initial write is cleared, never applied or relaunched")

        stored = "legacy value" as CFString
        let failedRestart = QuickTogglesSupport.set(.menuBarAutoHide, enabled: true, read: { stored },
            write: { stored = $0; return true }, refresh: { _ in false }, refreshAfterRollback: {
                restorationRefreshes += 1
                return true
            })
        suite.expect(failedRestart == .failed && stored as? String == "legacy value"
                     && restorationRefreshes == 1,
                     "failed relaunch restores the raw legacy string and refreshes affected hosts")

        stored = nil
        let unconfirmedRestore = QuickTogglesSupport.set(.stageManager, enabled: true, read: { stored },
            write: { value in
                // Ignore the second write, simulating a read-back mismatch.
                if let value { stored = value }
                return true
            }, refresh: { _ in false })
        suite.expect(unconfirmedRestore == .rollbackFailed && stored as? Bool == true,
                     "an unverified restoration is not reported as an ordinary rollback")

        stored = nil
        let ignoredWrite = QuickTogglesSupport.set(.dockLock, enabled: true, read: { stored },
            write: { _ in true }, refresh: { _ in
                refreshes += 1
                return true
            })
        suite.expect(ignoredWrite == .failed && stored == nil && refreshes == 0,
                     "success from the write is not enough without a matching read-back")

        let partialRestore = QuickTogglesSupport.set(.menuBarAutoHide, enabled: true, read: { stored },
            write: { stored = $0; return true }, refresh: { _ in false }, refreshAfterRollback: { false })
        suite.expect(partialRestore == .rollbackFailed && stored == nil,
                     "a restored preference without a confirmed refresh is still reported as incomplete")

        let success = QuickTogglesSupport.set(.stageManager, enabled: true, read: { stored },
            write: { stored = $0; return true }, refresh: { plan in
                refreshes += 1
                return plan.notification != nil
            })
        suite.expect(success == .applied && stored as? Bool == true && refreshes == 1,
                     "a verified write signals the target without attempting rollback")
    }

    private static func flagsParseLikeThePreferencesStore(_ suite: TestSuite) {
        suite.expect(QuickTogglesSupport.preferenceFlag(true, default: false)
                     && !QuickTogglesSupport.preferenceFlag(false, default: true),
                     "real booleans win over the default")
        suite.expect(QuickTogglesSupport.preferenceFlag(NSNumber(value: 1), default: false)
                     && !QuickTogglesSupport.preferenceFlag(NSNumber(value: 0), default: true),
                     "numbers use their boolean value")
        for value in ["YES", "yes", "TRUE", "true", "1"] {
            suite.expect(QuickTogglesSupport.preferenceFlag(value, default: false),
                         "\(value) reads as on")
        }
        for value in ["NO", "no", "FALSE", "false", "0"] {
            suite.expect(!QuickTogglesSupport.preferenceFlag(value, default: true),
                         "\(value) reads as off")
        }
        suite.expect(QuickTogglesSupport.preferenceFlag("not-a-flag", default: true)
                     && !QuickTogglesSupport.preferenceFlag("not-a-flag", default: false),
                     "an unreadable string keeps the given default")
        suite.expect(QuickTogglesSupport.preferenceFlag(nil, default: true)
                     && !QuickTogglesSupport.preferenceFlag(nil, default: false),
                     "a missing preference keeps the given default")
        suite.expect(QuickTogglesSupport.finderFlag("1", default: false),
                     "the Finder flag shares the same parser")
    }

    private static func plansNameTheOwningComponent(_ suite: TestSuite) {
        let dockAutoHide = QuickTogglesSupport.plan(for: .dockAutoHide, enabled: true)
        suite.expect(dockAutoHide.domain == "com.apple.dock"
                     && dockAutoHide.key == "autohide"
                     && dockAutoHide.value
                     && dockAutoHide.restartTarget == .dock
                     && dockAutoHide.notification == nil,
                     "Dock auto-hide writes com.apple.dock autohide and restarts the Dock")

        let dockLock = QuickTogglesSupport.plan(for: .dockLock, enabled: false)
        suite.expect(dockLock.domain == "com.apple.dock"
                     && dockLock.key == "contents-immutable"
                     && !dockLock.value
                     && dockLock.restartTarget == .dock,
                     "Dock lock writes com.apple.dock contents-immutable and restarts the Dock")

        let menuBar = QuickTogglesSupport.plan(for: .menuBarAutoHide, enabled: true)
        suite.expect(menuBar.domain == kCFPreferencesAnyApplication as String
                     && menuBar.key == "_HIHideMenuBar"
                     && menuBar.restartTarget == .menuBar
                     && menuBar.notification == nil,
                     "menu bar auto-hide writes the global domain and restarts the menu bar")

        let stageManager = QuickTogglesSupport.plan(for: .stageManager, enabled: true)
        suite.expect(stageManager.domain == "com.apple.WindowManager"
                     && stageManager.key == "GloballyEnabled"
                     && stageManager.restartTarget == nil
                     && stageManager.notification
                        == "com.apple.WindowManager.GloballyEnabled.changed",
                     "Stage Manager applies through its notification and restarts nothing")

        suite.expect(Set(QuickTogglesSupport.SystemSwitch.allCases.map(\.key)).count == 4,
                     "each switch owns a distinct preference key")
    }

    private static func statesDefaultOffAndReadBack(_ suite: TestSuite) {
        for systemSwitch in QuickTogglesSupport.SystemSwitch.allCases {
            suite.expect(!systemSwitch.defaultValue,
                         "\(systemSwitch.rawValue) starts off when never written")
            suite.expect(!QuickTogglesSupport.switchState(systemSwitch, value: nil),
                         "\(systemSwitch.rawValue) reads a missing preference as off")
            suite.expect(QuickTogglesSupport.switchState(systemSwitch, value: true),
                         "\(systemSwitch.rawValue) reads a stored true")
            suite.expect(!QuickTogglesSupport.switchState(systemSwitch, value: NSNumber(value: 0)),
                         "\(systemSwitch.rawValue) reads a stored zero as off")
            suite.expect(QuickTogglesSupport.switchState(systemSwitch, value: "1"),
                         "\(systemSwitch.rawValue) reads a legacy string")
        }
    }

    private static func rowsAppendToTheStoredLayout(_ suite: TestSuite) {
        let switches: [QuickToggleAction] = [.dockAutoHide, .dockLock,
                                             .stageManager, .menuBarAutoHide]
        suite.expect(Array(QuickToggleAction.allCases.suffix(switches.count)) == switches,
                     "the switch rows append after the existing actions")
        suite.expect(switches.map(\.rawValue)
                     == ["dockAutoHide", "dockLock", "stageManager", "menuBarAutoHide"],
                     "switch ids stay stable for saved panel orders and visibility keys")
        suite.expect(switches.compactMap(\.systemSwitch)
                     == QuickTogglesSupport.SystemSwitch.allCases,
                     "each row maps to its own preference switch")
        suite.expect(switches.allSatisfy { $0.feature == .quickToggles },
                     "the switches inherit the quick toggles availability check")
        suite.expect(switches.filter(\.restartsSystemComponent).isEmpty,
                     "the switches remain distinct from the dedicated restart rows")
        suite.expect(switches.filter(\.relaunchesComponent).map(\.rawValue)
                     == ["dockAutoHide", "dockLock", "menuBarAutoHide"],
                     "only the Dock and menu bar switches report a component relaunch")

        for key in [DefaultsKey.panelToggleDockAutoHide, DefaultsKey.panelToggleDockLock,
                    DefaultsKey.panelToggleStageManager, DefaultsKey.panelToggleMenuBarAutoHide] {
            suite.expect(Defaults.registeredDefaults[key] as? Bool == true,
                         "\(key) shows the row by default")
        }

        let oldOrder = ["darkMode", "keyboardLight", "micMute", "emptyTrash", "quitAllApps",
                        "restartDock", "restartFinder", "restartMenuBar", "restartInputMethod",
                        "ejectDisks", "hiddenFiles", "desktopIcons", "lockScreen", "displayOff",
                        "screenSaver"]
        let restored = Defaults.sanitizedPanelItemOrder(
            oldOrder.joined(separator: ","),
            defaultOrder: QuickToggleAction.allCases.map(\.rawValue))
        suite.expect(Array(restored.prefix(oldOrder.count)) == oldOrder,
                     "an existing saved quick toggle order keeps its order")
        suite.expect(restored.count == QuickToggleAction.allCases.count
                     && Set(restored) == Set(QuickToggleAction.allCases.map(\.rawValue)),
                     "every switch joins an existing order exactly once")
    }

    private static func copyIsTranslated(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let strings = FeatureStrings.quickToggles(language)
            let values = [strings.dockAutoHideTitle, strings.dockAutoHideCaption,
                          strings.dockLockTitle, strings.dockLockCaption,
                          strings.stageManagerTitle, strings.stageManagerCaption,
                          strings.menuBarAutoHideTitle, strings.menuBarAutoHideCaption,
                          strings.systemSwitchRollbackFailed]
            suite.expect(values.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
                         "every switch string is translated (\(language.rawValue))")
            suite.expect(values.allSatisfy { !$0.contains("—") },
                         "switch copy avoids the em dash (\(language.rawValue))")
        }
        let english = FeatureStrings.quickToggles(.enUS)
        suite.expect(english.dockAutoHideCaption.localizedCaseInsensitiveContains("Dock restarts")
                     && english.dockLockCaption.localizedCaseInsensitiveContains("Dock restarts"),
                     "the Dock captions say the Dock restarts")
        suite.expect(english.menuBarAutoHideCaption
                        .localizedCaseInsensitiveContains("menu bar restarts"),
                     "the menu bar caption says the menu bar restarts")
        suite.expect(!english.stageManagerCaption.localizedCaseInsensitiveContains("restart"),
                     "Stage Manager applies without a restart")
    }
}
