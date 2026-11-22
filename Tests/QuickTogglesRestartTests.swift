// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// Pure contracts behind the four system component restarts (issue #36): the
/// action ids, the menu bar host probe, the input method target decision, the
/// protection boundary, the persisted layout and the translated copy.
enum QuickTogglesRestartTests {
    static func run(_ suite: TestSuite) {
        restartsAreQuickToggles(suite)
        savedOrdersGainTheRestarts(suite)
        menuBarHostsAreProbed(suite)
        inputMethodTargetIsUnambiguous(suite)
        protectedProcessesStayOut(suite)
        copyIsTranslated(suite)
    }

    private static func restartsAreQuickToggles(_ suite: TestSuite) {
        let restarts: [QuickToggleAction] = [.restartDock, .restartFinder,
                                             .restartMenuBar, .restartInputMethod]
        suite.expect(QuickToggleAction.allCases.filter(\.restartsSystemComponent) == restarts,
                     "exactly the four component rows are restarts")
        suite.expect(restarts.allSatisfy { $0.feature == .quickToggles },
                     "component restarts inherit the quick toggles availability and permission checks")
        suite.expect(restarts.map(\.rawValue)
                     == ["restartDock", "restartFinder", "restartMenuBar", "restartInputMethod"],
                     "restart ids stay stable for saved panel orders and visibility keys")
        for key in [DefaultsKey.panelToggleRestartDock, DefaultsKey.panelToggleRestartFinder,
                    DefaultsKey.panelToggleRestartMenuBar, DefaultsKey.panelToggleRestartInputMethod] {
            suite.expect(Defaults.registeredDefaults[key] as? Bool == true,
                         "\(key) shows the row by default")
        }
    }

    private static func savedOrdersGainTheRestarts(_ suite: TestSuite) {
        let oldOrder = ["darkMode", "keyboardLight", "micMute", "emptyTrash", "quitAllApps",
                        "ejectDisks", "hiddenFiles", "desktopIcons", "lockScreen", "displayOff",
                        "screenSaver"]
        let restored = Defaults.sanitizedPanelItemOrder(
            oldOrder.joined(separator: ","),
            defaultOrder: QuickToggleAction.allCases.map(\.rawValue))
        suite.expect(Array(restored.prefix(oldOrder.count)) == oldOrder,
                     "an existing saved quick toggle order keeps its order")
        suite.expect(restored.count == QuickToggleAction.allCases.count
                     && Set(restored) == Set(QuickToggleAction.allCases.map(\.rawValue)),
                     "every restart joins an existing order exactly once")
    }

    private static func menuBarHostsAreProbed(_ suite: TestSuite) {
        suite.expect(QuickTogglesSupport.runningMenuBarHosts(["ControlCenter"]) == ["ControlCenter"],
                     "ControlCenter alone is a menu bar host")
        suite.expect(QuickTogglesSupport.runningMenuBarHosts(["SystemUIServer"]) == ["SystemUIServer"],
                     "SystemUIServer alone is a menu bar host on older releases")
        suite.expect(QuickTogglesSupport.runningMenuBarHosts(["SystemUIServer", "ControlCenter"])
                     == ["ControlCenter", "SystemUIServer"],
                     "the fixed host order is independent of the running set's order")
        suite.expect(QuickTogglesSupport.runningMenuBarHosts(["Dock"]).isEmpty,
                     "an unrelated process is never treated as a menu bar host")
    }

    private static func inputMethodTargetIsUnambiguous(_ suite: TestSuite) {
        let sogou = candidate("com.sogou.inputmethod.sogou", "SogouInput")
        let wetype = candidate("com.tencent.inputmethod.wetype", "WeType")
        let tencentFamily = candidate("com.tencent.inputmethod", "Tencent")

        suite.expect(QuickTogglesSupport.inputMethodTarget(
            sourceID: "com.tencent.inputmethod.wetype.pinyin",
            candidates: [sogou, wetype]) == wetype,
            "the current third-party source selects its input method")
        suite.expect(QuickTogglesSupport.inputMethodTarget(
            sourceID: "com.tencent.inputmethod.wetype.pinyin",
            candidates: [tencentFamily, wetype]) == wetype,
            "the longest bundle id prefix wins over a shorter family id")
        suite.expect(QuickTogglesSupport.inputMethodTarget(
            sourceID: "com.apple.keylayout.ABC",
            candidates: [sogou, wetype]) == nil,
            "an Apple layout with several third-party methods is ambiguous and restarts none")
        suite.expect(QuickTogglesSupport.inputMethodTarget(
            sourceID: "com.apple.keylayout.ABC",
            candidates: [sogou]) == sogou,
            "a single running third-party method is still the target on an Apple layout")
        suite.expect(QuickTogglesSupport.inputMethodTarget(
            sourceID: nil,
            candidates: [sogou]) == sogou,
            "a missing current source falls back to the single running method")
        suite.expect(QuickTogglesSupport.inputMethodTarget(
            sourceID: "com.apple.inputmethod.SCIM.ITABC",
            candidates: []) == nil,
            "no third-party method means no target")
        suite.expect(QuickTogglesSupport.inputMethodTarget(
            sourceID: "com.sogou.inputmethod.sogou.pinyin",
            candidates: []) == nil,
            "a third-party source without a running app means no target")
    }

    private static func protectedProcessesStayOut(_ suite: TestSuite) {
        for name in ["kernel_task", "launchd", "WindowServer", "loginwindow", "Tina"] {
            suite.expect(KillProcessSupport.isProtectedName(name),
                         "\(name) is never a restart target")
        }
        for name in ["Dock", "ControlCenter", "SystemUIServer"] {
            suite.expect(!KillProcessSupport.isProtectedName(name),
                         "\(name) is restartable")
        }
        suite.expect(!KillProcessSupport.isProtectedName("  Dock  "),
                     "the protection check trims the process name before deciding")
    }

    private static func copyIsTranslated(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let strings = FeatureStrings.quickToggles(language)
            let values = [strings.restartDockTitle, strings.restartDockCaption,
                          strings.restartDockConfirmTitle, strings.restartDockConfirmMessage,
                          strings.restartFinderTitle, strings.restartFinderCaption,
                          strings.restartFinderConfirmTitle, strings.restartFinderConfirmMessage,
                          strings.restartMenuBarTitle, strings.restartMenuBarCaption,
                          strings.restartMenuBarConfirmTitle, strings.restartMenuBarConfirmMessage,
                          strings.restartInputMethodTitle, strings.restartInputMethodCaption,
                          strings.restartInputMethodConfirmTitle, strings.restartInputMethodConfirmMessage,
                          strings.restartInputMethodUnavailable, strings.restartInProgress,
                          strings.restartSucceeded, strings.restartConfirmButton]
            suite.expect(values.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
                         "every restart string is translated (\(language.rawValue))")
            suite.expect(values.allSatisfy { !$0.contains("—") },
                         "restart copy avoids the em dash (\(language.rawValue))")
        }
    }

    private static func candidate(_ bundleIdentifier: String,
                                  _ name: String) -> QuickTogglesSupport.InputMethodCandidate {
        QuickTogglesSupport.InputMethodCandidate(bundleIdentifier: bundleIdentifier,
                                                 name: name,
                                                 bundlePath: "/Library/Input Methods/\(name).app")
    }
}
