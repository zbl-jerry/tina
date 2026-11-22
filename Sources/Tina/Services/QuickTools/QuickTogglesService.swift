// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox

/// Everything the quick toggles tab can do. Raw values are storage ids for
/// the user's order and the per-item visibility keys.
enum QuickToggleAction: String, PanelOrderItem, Identifiable {
    // Case order is the default panel order: the appearance switch leads
    // because it is the tab's headline action (issue request). Quit all sits
    // next to Empty the Trash (issue #855), and the four component restarts
    // (issue #36) follow the other maintenance actions.
    case darkMode, keyboardLight, micMute, emptyTrash, quitAllApps,
         restartDock, restartFinder, restartMenuBar, restartInputMethod,
         ejectDisks, hiddenFiles, desktopIcons, lockScreen, displayOff, screenSaver

    var id: String { rawValue }

    var feature: AppFeature {
        switch self {
        case .micMute: return .micMute
        case .quitAllApps: return .quitApps
        default: return .quickToggles
        }
    }

    /// The rows that ask the system to relaunch a component. They share the
    /// confirmation, progress and result captions (issue #36).
    var restartsSystemComponent: Bool {
        switch self {
        case .restartDock, .restartFinder, .restartMenuBar, .restartInputMethod: return true
        default: return false
        }
    }
}

/// One-click system actions, all on demand: nothing runs, observes or polls
/// while the panel is closed. Each action reports a short-lived state so the
/// row can show progress and the outcome.
final class QuickTogglesService: ObservableObject {
    static let shared = QuickTogglesService()

    enum RunState: Equatable {
        case running, failed
        /// The action needs an Automation consent the user declined; the row
        /// turns into a permission prompt until the grant shows up.
        case needsPermission
        /// A component restart finished. Shown briefly so the row reports the
        /// result instead of silently returning to idle (issue #36).
        case succeeded
    }

    /// The third-party input method the restart row targets, resolved from
    /// the current input source and the running apps.
    struct InputMethodTarget: Equatable {
        let bundleIdentifier: String
        let name: String
        let bundlePath: String
        let pid: pid_t
    }

    @Published private(set) var states: [QuickToggleAction: RunState] = [:]
    /// Refreshed when a surface shows the list and again before the input
    /// method confirmation. Nil means the row is disabled and says why.
    @Published private(set) var inputMethodTarget: InputMethodTarget?
    @Published private(set) var shortcutRegistrationFailed = false
    @Published private(set) var othersShortcutRegistrationFailed = false
    @Published private(set) var quitAllExceptions: [String] = []

    private let workQueue = DispatchQueue(label: "com.tina.utils.quick-toggles", qos: .userInitiated)
    private let hotkey = QuickToolHotkey(id: 63)
    private let othersHotkey = QuickToolHotkey(id: 62)

    private init() {
        hotkey.onPress = { [weak self] in self?.showQuitApps(scope: .all) }
        othersHotkey.onPress = { [weak self] in self?.showQuitApps(scope: .allExceptFront) }
        reloadQuitAllExceptions()
    }

    func state(for action: QuickToggleAction) -> RunState? {
        states[action]
    }

    func syncWithPreferences() {
        let available = quitAppsAvailable
        let defaults = UserDefaults.standard
        shortcutRegistrationFailed = !hotkey.sync(
            enabled: available && defaults.bool(forKey: DefaultsKey.quitAppsShortcutEnabled),
            shortcut: GlobalShortcut.saved(for: DefaultsKey.quitAppsShortcut,
                                           fallback: .quitAllDefault),
            storageKey: DefaultsKey.quitAppsShortcut)
        othersShortcutRegistrationFailed = !othersHotkey.sync(
            enabled: available && defaults.bool(forKey: DefaultsKey.quitAppsExceptFrontShortcutEnabled),
            shortcut: GlobalShortcut.saved(for: DefaultsKey.quitAppsExceptFrontShortcut,
                                           fallback: .quitAllExceptFrontDefault),
            storageKey: DefaultsKey.quitAppsExceptFrontShortcut)
        if !available {
            hotkey.unregister()
            othersHotkey.unregister()
            QuitAppsPanelController.shared.close()
        }
        reloadQuitAllExceptions()
    }

    // MARK: - Current system state (read on demand, never observed)

    var hiddenFilesShown: Bool {
        finderFlag(QuickTogglesSupport.showAllFilesKey, default: false)
    }

    /// Current system appearance, read from the same WindowServer switch the
    /// toggle flips; nil when the symbol is unavailable.
    var systemAppearanceIsDark: Bool? {
        Self.appearanceTheme?.get()
    }

    var desktopIconsShown: Bool {
        finderFlag(QuickTogglesSupport.createDesktopKey, default: true)
    }

    func ejectableVolumeCount() -> Int {
        Self.ejectableVolumeURLs().count
    }

    // MARK: - Appearance (issue #205)

    /// Flips the system between light and dark mode through the WindowServer,
    /// the same switch System Settings flips: instant, system wide and with
    /// no Automation consent involved. The symbol is resolved lazily and
    /// guarded; without it the row reports the failure instead of crashing.
    func toggleDarkMode() {
        guard available, beginRun(.darkMode) else { return }
        guard let theme = Self.appearanceTheme else {
            finishRun(.darkMode, state: .failed)
            return
        }
        theme.set(!theme.get())
        finishRun(.darkMode, state: nil)
    }

    // MARK: - Trash

    /// Asks first (emptying is permanent), then tells the Finder to empty
    /// the Trash. Runs on the main thread up to the confirmation; the Apple
    /// Event goes to the work queue.
    func emptyTrash() {
        guard available, states[.emptyTrash] != .running else { return }
        let strings = FeatureStrings.quickToggles(L10n.shared.language)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = strings.emptyTrashConfirmTitle
        alert.informativeText = strings.emptyTrashConfirmMessage
        alert.addButton(withTitle: strings.emptyTrashConfirmButton)
        alert.addButton(withTitle: L10n.shared.s.uninstallerCancel)
        let island = NotchService.shared.presentationWindow
        let fromIsland = island?.isVisible == true
            && (NSApp.currentEvent?.window === island || NSApp.keyWindow === island)
        guard NotchIslandAlert.run(alert, above: fromIsland ? island : nil) == .alertFirstButtonReturn else { return }
        emptyTrashConfirmed()
    }

    /// The variant for surfaces that already asked in their own words (the
    /// command bar confirms inline); emptying is still permanent.
    func emptyTrashConfirmed() {
        runAppleScript(.emptyTrash,
                       target: .finder,
                       source: QuickTogglesSupport.emptyTrashSource)
    }

    // MARK: - Quit apps (issue #855)

    /// Opens the Quit apps window. `scope` only decides which batch button
    /// Return presses; the list and both buttons are always there.
    func showQuitApps(scope: QuitAppsScope = .all) {
        guard quitAppsAvailable else { return }
        QuitAppsPanelController.shared.show(scope: scope, frontmostPID: frontmostAppPID())
    }

    /// Soft quit only: `terminate()`, never `forceTerminate()`, so unsaved
    /// document sheets still appear. Finder, Phone, Tina, any app the user
    /// listed as an exception and `keepingPID` are left alone.
    func quitAllApps(keepingPID: pid_t?) {
        guard quitAppsAvailable, beginRun(.quitAllApps) else { return }
        let exceptions = Set(quitAllExceptions)
        // `terminate()` only posts the quit request, and running-app state
        // updates on the main run loop, so the sweep stays on main.
        let running = NSWorkspace.shared.runningApplications
        let targets = Set(QuickTogglesSupport.batchQuitTargets(
            running.map(Self.candidate), exceptions: exceptions, keepingPID: keepingPID))
        for app in running where targets.contains(app.processIdentifier) {
            _ = app.terminate()
        }
        finishRun(.quitAllApps, state: nil)
    }

    /// Asks one app to quit, exceptions included: picking its row is explicit.
    func quitApp(pid: pid_t) -> Bool {
        guard quitAppsAvailable,
              let app = NSRunningApplication(processIdentifier: pid),
              let bundleID = app.bundleIdentifier,
              !QuickTogglesSupport.tinaBundleIdentifiers.contains(bundleID) else { return false }
        return app.terminate()
    }

    private static func candidate(_ app: NSRunningApplication) -> QuitAppsCandidate {
        QuitAppsCandidate(pid: app.processIdentifier,
                          bundleIdentifier: app.bundleIdentifier,
                          activationPolicyRawValue: app.activationPolicy.rawValue,
                          isTerminated: app.isTerminated)
    }

    /// Preserve the app in front, or the source remembered before our panel
    /// took focus. An unrelated visible window is not a safe substitute.
    func frontmostAppPID() -> pid_t? {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ownPID {
            return front.processIdentifier
        }
        return (NSApp.delegate as? AppDelegate)?.panelActivationSourcePID
    }

    func addQuitAllException(_ bundleID: String) {
        let bundleID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bundleID.isEmpty, !quitAllExceptions.contains(bundleID) else { return }
        var list = QuickTogglesSupport.sanitizedQuitAllExceptions(quitAllExceptions)
        list.append(bundleID)
        UserDefaults.standard.set(list, forKey: DefaultsKey.quitAppsKeptApps)
        reloadQuitAllExceptions()
    }

    func removeQuitAllException(_ bundleID: String) {
        guard !isMandatoryQuitAllException(bundleID) else { return }
        let list = QuickTogglesSupport.sanitizedQuitAllExceptions(
            quitAllExceptions.filter { $0 != bundleID })
        UserDefaults.standard.set(list, forKey: DefaultsKey.quitAppsKeptApps)
        reloadQuitAllExceptions()
    }

    func isMandatoryQuitAllException(_ bundleID: String) -> Bool {
        Defaults.mandatoryAutoQuitExceptionBundleIDs.contains(bundleID)
    }

    private func reloadQuitAllExceptions() {
        let raw = UserDefaults.standard.stringArray(forKey: DefaultsKey.quitAppsKeptApps) ?? []
        let sanitized = QuickTogglesSupport.sanitizedQuitAllExceptions(raw)
        if raw != sanitized {
            UserDefaults.standard.set(sanitized, forKey: DefaultsKey.quitAppsKeptApps)
        }
        quitAllExceptions = sanitized
    }

    // MARK: - Finder flags

    /// Writes the Finder preference and restarts the Finder to apply it;
    /// launchd brings it right back with the new value in effect.
    func toggleHiddenFiles() {
        toggleFinderFlag(.hiddenFiles,
                         key: QuickTogglesSupport.showAllFilesKey,
                         to: !hiddenFilesShown)
    }

    func toggleDesktopIcons() {
        toggleFinderFlag(.desktopIcons,
                         key: QuickTogglesSupport.createDesktopKey,
                         to: !desktopIconsShown)
    }

    // MARK: - Disks

    /// Safely ejects every external volume, the on-demand cousin of the disk
    /// monitor's "Eject all". Enumerated fresh on each click, so the action
    /// never keeps a disk list alive.
    func ejectAllDisks() {
        guard available, beginRun(.ejectDisks) else { return }
        workQueue.async {
            let volumes = Self.ejectableVolumeURLs()
            guard !volumes.isEmpty else {
                self.finishRun(.ejectDisks, state: nil)
                return
            }
            var failures = 0
            for url in volumes {
                do {
                    try NSWorkspace.shared.unmountAndEjectDevice(at: url)
                } catch {
                    // A drive that carries more than one volume leaves whole on
                    // the first eject, so the ones still on the list are gone
                    // before their turn comes and refuse an eject of their own.
                    // Only a volume that is still mounted really failed.
                    if Self.isMounted(url) { failures += 1 }
                }
            }
            self.finishRun(.ejectDisks, state: failures == 0 ? nil : .failed)
        }
    }

    // MARK: - Screen

    /// The same immediate lock as the system's own shortcut. The symbol is
    /// resolved lazily and guarded; when it is unavailable the screen saver
    /// path stands in (with a password required, it locks too).
    func lockScreen() {
        guard available else { return }
        if let lock = Self.lockScreenFunction {
            _ = lock()
        } else {
            startScreenSaver()
        }
    }

    func turnDisplayOff() {
        guard available, beginRun(.displayOff) else { return }
        workQueue.async {
            let result = Shell.run("/usr/bin/pmset", ["displaysleepnow"])
            self.finishRun(.displayOff, state: result.status == 0 ? nil : .failed)
        }
    }

    func startScreenSaver() {
        guard available else { return }
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app")
        NSWorkspace.shared.openApplication(at: url,
                                           configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: - System component restarts (issue #36)

    /// Confirms first, then relaunches one component. The alert is the same
    /// confirmation the Trash action uses, so the panel keeps a single modal
    /// contract and the island keeps focus. Nothing runs when the alert is
    /// cancelled or dismissed.
    func requestRestart(_ action: QuickToggleAction) {
        guard available, action.restartsSystemComponent,
              states[action] != .running else { return }
        if action == .restartInputMethod {
            refreshInputMethodTarget()
            guard inputMethodTarget != nil else { return }
        }
        let strings = FeatureStrings.quickToggles(L10n.shared.language)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = Self.confirmTitle(for: action, strings: strings)
        alert.informativeText = Self.confirmMessage(for: action, strings: strings)
        alert.addButton(withTitle: strings.restartConfirmButton)
        alert.addButton(withTitle: L10n.shared.s.uninstallerCancel)
        let island = NotchService.shared.presentationWindow
        let fromIsland = island?.isVisible == true
            && (NSApp.currentEvent?.window === island || NSApp.keyWindow === island)
        guard NotchIslandAlert.run(alert, above: fromIsland ? island : nil)
                == .alertFirstButtonReturn else { return }
        // The target is resolved on the main thread: TIS and NSWorkspace
        // reads belong here. The kill and relaunch below run off it.
        performRestart(action,
                       inputMethod: action == .restartInputMethod ? inputMethodTarget : nil)
    }

    /// Re-reads the current input source and the running input methods. TIS
    /// and NSWorkspace are main-thread APIs; the list calls this when it
    /// appears so the row's caption and enabled state are current.
    func refreshInputMethodTarget() {
        let running = NSWorkspace.shared.runningApplications.compactMap {
            app -> (candidate: QuickTogglesSupport.InputMethodCandidate, pid: pid_t)? in
            guard !app.isTerminated,
                  let bundleIdentifier = app.bundleIdentifier,
                  let url = app.bundleURL else { return nil }
            let path = url.path
            // Apple's methods live under /System and are never restarted.
            guard path.contains("/Input Methods/"), !path.hasPrefix("/System/") else { return nil }
            let name = app.localizedName ?? url.deletingPathExtension().lastPathComponent
            return (.init(bundleIdentifier: bundleIdentifier, name: name, bundlePath: path),
                    app.processIdentifier)
        }
        guard let match = QuickTogglesSupport.inputMethodTarget(
                sourceID: InputSourceSelection.currentSourceID(),
                candidates: running.map(\.candidate)),
              let runningMatch = running.first(where: { $0.candidate == match }) else {
            inputMethodTarget = nil
            return
        }
        inputMethodTarget = InputMethodTarget(bundleIdentifier: match.bundleIdentifier,
                                              name: match.name,
                                              bundlePath: match.bundlePath,
                                              pid: runningMatch.pid)
    }

    private func performRestart(_ action: QuickToggleAction,
                                inputMethod: InputMethodTarget?) {
        guard beginRun(action) else { return }
        workQueue.async {
            let succeeded: Bool
            switch action {
            case .restartDock:
                succeeded = Self.restartDock()
            case .restartFinder:
                succeeded = self.restartFinder()
            case .restartMenuBar:
                succeeded = Self.restartMenuBar()
            case .restartInputMethod:
                succeeded = Self.restartInputMethod(inputMethod)
            default:
                succeeded = false
            }
            self.finishRun(action, state: succeeded ? .succeeded : .failed)
        }
    }

    /// launchd relaunches the Dock by itself after SIGTERM. The kickstart
    /// fallback covers a Dock that ignores the signal, which killall reports
    /// as a failure.
    private static func restartDock() -> Bool {
        guard !KillProcessSupport.isProtectedName("Dock") else { return false }
        if Shell.run("/usr/bin/killall", ["Dock"]).status == 0 { return true }
        return Shell.run("/bin/launchctl",
                         ["kickstart", "-k", "gui/\(getuid())/com.apple.Dock"]).status == 0
    }

    /// Only the bar hosts that exist on this release are touched: killing a
    /// name that is absent would report a failure for a component the system
    /// does not use.
    private static func restartMenuBar() -> Bool {
        let present = Set(QuickTogglesSupport.menuBarHostNames.filter(processIsRunning))
        let running = QuickTogglesSupport.runningMenuBarHosts(present)
        guard !running.isEmpty else { return false }
        var restarted = 0
        for name in running {
            guard !KillProcessSupport.isProtectedName(name) else { continue }
            if Shell.run("/usr/bin/killall", [name]).status == 0 || !processIsRunning(name) {
                restarted += 1
            }
        }
        return restarted == running.count
    }

    /// Polite quit first, then SIGKILL, then reopen the bundle that was
    /// captured before the kill. The selection preference is untouched.
    private static func restartInputMethod(_ target: InputMethodTarget?) -> Bool {
        guard let target,
              let app = NSRunningApplication(processIdentifier: target.pid),
              !app.isTerminated,
              !KillProcessSupport.isProtected(pid: target.pid,
                                              name: target.name,
                                              path: target.bundlePath) else { return false }
        _ = app.terminate()
        if !waitForExit(pid: target.pid) {
            guard kill(target.pid, SIGKILL) == 0, waitForExit(pid: target.pid) else { return false }
        }
        let url = URL(fileURLWithPath: target.bundlePath)
        guard FileManager.default.fileExists(atPath: target.bundlePath) else { return false }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        return true
    }

    private static func processIsRunning(_ name: String) -> Bool {
        Shell.run("/usr/bin/pgrep", ["-x", name]).status == 0
    }

    /// `kill(pid, 0)` answers ESRCH only after the process is gone; a live
    /// process, including one we may not signal, keeps it at 0.
    private static func waitForExit(pid: pid_t, attempts: Int = 20) -> Bool {
        for _ in 0..<attempts {
            if kill(pid, 0) != 0 && errno == ESRCH { return true }
            usleep(100_000)
        }
        return false
    }

    private static func confirmTitle(for action: QuickToggleAction,
                                     strings: QuickToggleFeatureStrings) -> String {
        switch action {
        case .restartDock: return strings.restartDockConfirmTitle
        case .restartFinder: return strings.restartFinderConfirmTitle
        case .restartMenuBar: return strings.restartMenuBarConfirmTitle
        case .restartInputMethod: return strings.restartInputMethodConfirmTitle
        default: return strings.actionFailed
        }
    }

    private static func confirmMessage(for action: QuickToggleAction,
                                       strings: QuickToggleFeatureStrings) -> String {
        switch action {
        case .restartDock: return strings.restartDockConfirmMessage
        case .restartFinder: return strings.restartFinderConfirmMessage
        case .restartMenuBar: return strings.restartMenuBarConfirmMessage
        case .restartInputMethod: return strings.restartInputMethodConfirmMessage
        default: return ""
        }
    }

    // MARK: - Permission refresh

    /// Clears a stale "needs permission" mark once the grant shows up in
    /// System Settings, so the row goes back to being clickable. Called when
    /// the list appears; checked off the main thread (the AE check blocks).
    func refreshPermissionStates() {
        let marked = states.filter { $0.value == .needsPermission }.map(\.key)
        guard !marked.isEmpty else { return }
        workQueue.async {
            for action in marked {
                guard let target = Self.automationTarget(for: action) else { continue }
                if Permissions.automationStatus(for: target) == .granted {
                    DispatchQueue.main.async {
                        if self.states[action] == .needsPermission {
                            self.states[action] = nil
                        }
                    }
                }
            }
        }
    }

    // MARK: - Internals

    private var available: Bool {
        AppFeature.quickToggles.isAvailable
    }

    private var quitAppsAvailable: Bool {
        AppFeature.quitApps.isAvailable
    }

    private static func automationTarget(for action: QuickToggleAction) -> Permissions.AutomationTarget? {
        switch action {
        case .emptyTrash: return .finder
        default: return nil
        }
    }

    private func runAppleScript(_ action: QuickToggleAction,
                                target: Permissions.AutomationTarget,
                                source: String) {
        guard available, beginRun(action) else { return }
        workQueue.async {
            // Denied consent never re-prompts by itself: surface the grant
            // button instead of a silent failure. Undetermined runs straight
            // into the script, which is what triggers the system prompt.
            if Permissions.automationStatus(for: target) == .denied {
                self.finishRun(action, state: .needsPermission, resets: false)
                return
            }
            let result = AppleScriptRunner.runDetailed(source)
            if result.ok {
                self.finishRun(action, state: nil)
            } else if QuickTogglesSupport.isPermissionError(result.errorNumber) {
                self.finishRun(action, state: .needsPermission, resets: false)
            } else {
                self.finishRun(action, state: .failed)
            }
        }
    }

    private func toggleFinderFlag(_ action: QuickToggleAction, key: String, to value: Bool) {
        guard available, beginRun(action) else { return }
        workQueue.async {
            CFPreferencesSetAppValue(key as CFString,
                                     value as CFBoolean,
                                     QuickTogglesSupport.finderDomain as CFString)
            CFPreferencesAppSynchronize(QuickTogglesSupport.finderDomain as CFString)
            self.finishRun(action, state: self.restartFinder() ? nil : .failed)
        }
    }

    /// The Finder only reads these preferences at launch, so it has to
    /// restart. When the Finder Automation grant is already in (the Trash
    /// and cut and paste share it), the restart is polite: a regular quit
    /// followed by our own relaunch, which keeps launchd out of it and
    /// avoids its "running in background" churn. Without the grant, or when
    /// the Finder will not quit (an operation in progress), the classic
    /// killall does it; never prompts either way. Work-queue only: the exit
    /// poll blocks.
    private func restartFinder() -> Bool {
        if Permissions.automationStatus(for: .finder) == .granted,
           AppleScriptRunner.runDetailed(QuickTogglesSupport.quitFinderSource).ok,
           waitForFinderExit() {
            let url = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            return true
        }
        return Shell.run("/usr/bin/killall", ["Finder"]).status == 0
    }

    /// A quit Finder stays quit (nothing relaunches it), so the poll only
    /// confirms the exit before the relaunch; a Finder that is still around
    /// after the timeout is busy and falls back to killall.
    private func waitForFinderExit() -> Bool {
        for _ in 0..<30 {
            if Shell.run("/usr/bin/pgrep", ["-x", "Finder"]).status != 0 {
                return true
            }
            usleep(100_000)
        }
        return false
    }

    /// Marks the action as running; a second click while it runs is ignored.
    private func beginRun(_ action: QuickToggleAction) -> Bool {
        guard states[action] != .running else { return false }
        setState(action, .running)
        return true
    }

    /// Success clears the state right away (the row itself is the feedback,
    /// no caption flash); a failure shows briefly, a permission mark stays.
    private func finishRun(_ action: QuickToggleAction, state: RunState?, resets: Bool = true) {
        setState(action, state)
        guard state != nil, resets else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
            guard let self, self.states[action] == state else { return }
            self.states[action] = nil
        }
    }

    /// Applies synchronously on the main thread so beginRun's double-click
    /// guard reads the value it just wrote.
    private func setState(_ action: QuickToggleAction, _ state: RunState?) {
        if Thread.isMainThread {
            states[action] = state
        } else {
            DispatchQueue.main.async {
                self.states[action] = state
            }
        }
    }

    private func finderFlag(_ key: String, default defaultValue: Bool) -> Bool {
        let value = CFPreferencesCopyAppValue(key as CFString,
                                              QuickTogglesSupport.finderDomain as CFString)
        return QuickTogglesSupport.finderFlag(value, default: defaultValue)
    }

    private static func ejectableVolumeURLs() -> [URL] {
        let keys: Set<URLResourceKey> = [
            .volumeIsInternalKey, .volumeIsRemovableKey,
            .volumeIsEjectableKey, .volumeIsLocalKey,
            .volumeIsRootFileSystemKey,
            .volumeNameKey,
            .volumeLocalizedNameKey,
            .volumeUUIDStringKey,
        ]
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]) else { return [] }
        let excludedList = UserDefaults.standard.stringArray(forKey: DefaultsKey.diskEjectExcludedVolumes) ?? []
        let excludedSet = Set(excludedList.map { $0.lowercased() })
        return urls.filter { url in
            guard let values = try? url.resourceValues(forKeys: keys) else { return false }
            // A volume with no bus of its own, a mounted image for one, states
            // no internal flag at all, so only a stated internal bus counts as
            // internal. The local flag stays strict: a volume that will not say
            // it is local is left alone. The volume the Mac started from falls
            // back to its mount point, so a missing flag cannot expose it.
            let name = values.volumeLocalizedName ?? values.volumeName ?? url.lastPathComponent
            return QuickTogglesSupport.shouldOfferEject(isInternal: values.volumeIsInternal ?? false,
                                                        isRemovable: values.volumeIsRemovable ?? false,
                                                        isEjectable: values.volumeIsEjectable ?? false,
                                                        isLocal: values.volumeIsLocal ?? false,
                                                        isRootFileSystem: values.volumeIsRootFileSystem
                                                            ?? (url.path == "/"),
                                                        volumeName: name,
                                                        volumeUUID: values.volumeUUIDString,
                                                        mountPath: url.path,
                                                        excludedVolumes: excludedSet)
        }
    }

    /// Whether a volume is still on the mount table, asked only after an eject
    /// reported a problem. A list we cannot read answers yes, so a real failure
    /// is never swallowed.
    private static func isMounted(_ url: URL) -> Bool {
        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil,
                                                               options: []) else { return true }
        return urls.contains { $0.path == url.path }
    }

    /// SACLockScreenImmediate from the login framework, resolved once and
    /// guarded: a missing symbol just means the screen saver fallback.
    private static let lockScreenFunction: (@convention(c) () -> Int32)? = {
        let path = "/System/Library/PrivateFrameworks/login.framework/login"
        guard let handle = dlopen(path, RTLD_LAZY),
              let symbol = dlsym(handle, "SACLockScreenImmediate") else { return nil }
        return unsafeBitCast(symbol, to: (@convention(c) () -> Int32).self)
    }()

    private typealias AppearanceGet = @convention(c) () -> Bool
    private typealias AppearanceSet = @convention(c) (Bool) -> Void

    /// The WindowServer's appearance switch (SkyLight), resolved once and
    /// guarded like the lock above. Stable across many macOS releases; if it
    /// ever leaves, toggleDarkMode degrades to a visible failure.
    private static let appearanceTheme: (get: AppearanceGet, set: AppearanceSet)? = {
        let path = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
        guard let handle = dlopen(path, RTLD_LAZY),
              let getSymbol = dlsym(handle, "SLSGetAppearanceThemeLegacy"),
              let setSymbol = dlsym(handle, "SLSSetAppearanceThemeLegacy") else { return nil }
        return (unsafeBitCast(getSymbol, to: AppearanceGet.self),
                unsafeBitCast(setSymbol, to: AppearanceSet.self))
    }()
}
