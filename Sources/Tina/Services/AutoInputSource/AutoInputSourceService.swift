// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox
import Combine
import Foundation

/// One enabled keyboard input source, as the page and the panel present it.
struct AutoInputSourceOption: Identifiable, Equatable {
    let id: String
    let name: String
    let code: String
    let isLayout: Bool
}

/// Watches app activation and applies the input source the rules ask for.
///
/// The service only listens: it never taps the keyboard, so a switch happens
/// after an app becomes active and never while a key is being handled. Secure
/// input (a password field) suppresses switching entirely. While the feature
/// is off in the hub or its own toggle is off, nothing is observed.
final class AutoInputSourceService: ObservableObject {
    static let shared = AutoInputSourceService()

    /// True while activation is actually being watched, which is the feature
    /// installed, its toggle on, and the observer installed.
    @Published private(set) var isRunning = false
    @Published private(set) var configuration: AutoInputSourceConfiguration = .empty
    @Published private(set) var currentSource: InputSourceSelection.Reading?
    @Published private(set) var sources: [AutoInputSourceOption] = []

    private let defaults: UserDefaults
    private let workspace: NSWorkspace
    private let ownBundleID: String?

    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var defaultsObserver: NSObjectProtocol?

    /// Apps whose first activation has already been seen. Running apps are
    /// seeded here when observation starts, so returning to an app that was
    /// already open counts as a reactivation, not as a launch.
    private var seenActive: Set<String> = []
    private var lastSources: [String: String] = [:]
    private var storedConfiguration: String?

    init(defaults: UserDefaults = .standard,
         workspace: NSWorkspace = .shared,
         ownBundleID: String? = Bundle.main.bundleIdentifier) {
        self.defaults = defaults
        self.workspace = workspace
        self.ownBundleID = ownBundleID
    }

    // MARK: - Lifecycle

    func syncWithPreferences() {
        // The rules are read whether or not switching is on: the Settings
        // page still edits them while the toggle is off, and a later enable
        // must not present an empty list.
        reloadConfiguration()
        reloadLastSources()
        let enabled = AppFeature.autoInputSource.isAvailable
            && defaults.bool(forKey: DefaultsKey.autoInputSourceEnabled)
        if enabled {
            startObserving()
            refresh()
            isRunning = true
        } else {
            stopObserving()
            isRunning = false
            refresh()
        }
    }

    /// Reads the rules and the current source again without changing whether
    /// observation is on. Surfaces call this when they open.
    func reload() {
        reloadConfiguration()
        reloadLastSources()
        refresh()
    }

    /// Reads the current source and the enabled list again. The panel calls
    /// this when it opens, whether or not automatic switching is on, so it
    /// can still offer a manual choice.
    func refresh() {
        sources = Self.readOptions()
        currentSource = InputSourceSelection.currentReading()
        let pruned = AutoInputSourceSupport.pruned(lastSources,
                                                   enabledSourceIDs: Set(sources.map(\.id)))
        if pruned != lastSources {
            lastSources = pruned
            persistLastSources()
        }
    }

    private func startObserving() {
        guard workspaceObservers.isEmpty else { return }
        seenActive = Set(workspace.runningApplications.compactMap(\.bundleIdentifier))

        let center = workspace.notificationCenter
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            self?.appDidActivate(note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication)
        })
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication)?.bundleIdentifier else { return }
            // A relaunch starts the app's first-activation window again even
            // if an earlier process had already been seen.
            self?.seenActive.remove(bundleID)
        })
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication)?.bundleIdentifier else { return }
            self?.seenActive.remove(bundleID)
        })

        let distributed = DistributedNotificationCenter.default()
        distributedObservers.append(distributed.addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main
        ) { [weak self] _ in self?.sourceDidChange() })
        distributedObservers.append(distributed.addObserver(
            forName: NSNotification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() })

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.configurationDidChange() }
    }

    private func stopObserving() {
        let center = workspace.notificationCenter
        workspaceObservers.forEach { center.removeObserver($0) }
        workspaceObservers.removeAll()
        let distributed = DistributedNotificationCenter.default()
        distributedObservers.forEach { distributed.removeObserver($0) }
        distributedObservers.removeAll()
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
            self.defaultsObserver = nil
        }
        seenActive.removeAll()
    }

    // MARK: - Activation

    private func appDidActivate(_ app: NSRunningApplication?) {
        guard let bundleID = app?.bundleIdentifier, !bundleID.isEmpty else { return }
        let isFirst = !seenActive.contains(bundleID)
        seenActive.insert(bundleID)

        currentSource = InputSourceSelection.currentReading()
        guard isRunning, bundleID != ownBundleID else { return }
        // Secure input means a password field owns the keyboard; switching
        // under it would be both surprising and useless.
        guard !IsSecureEventInputEnabled() else { return }

        let decision = AutoInputSourceSupport.decision(
            bundleID: bundleID,
            firstActivation: isFirst,
            configuration: configuration,
            lastSources: lastSources,
            enabledSourceIDs: Set(sources.map(\.id)),
            currentSourceID: InputSourceSelection.currentSourceID())
        guard let sourceID = decision.sourceID else { return }
        select(sourceID: sourceID)
    }

    /// Records what the frontmost app is typing with. The system posts this
    /// notification for manual switches and for Tina's own, so "remember
    /// last source" needs no separate bookkeeping.
    private func sourceDidChange() {
        currentSource = InputSourceSelection.currentReading()
        guard isRunning,
              let bundleID = workspace.frontmostApplication?.bundleIdentifier,
              !bundleID.isEmpty, bundleID != ownBundleID,
              let sourceID = currentSource?.id,
              lastSources[bundleID] != sourceID
        else { return }
        lastSources[bundleID] = sourceID
        persistLastSources()
    }

    @discardableResult
    func select(sourceID: String) -> Bool {
        guard InputSourceSelection.select(sourceID: sourceID) else { return false }
        currentSource = InputSourceSelection.currentReading()
        return true
    }

    // MARK: - Editing

    func addRule(bundleID: String, appName: String) {
        let id = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AutoInputSourceSupport.isValidBundleID(id),
              !configuration.rules.contains(where: { $0.bundleID == id }) else { return }
        configuration.rules.append(AutoInputSourceRule(
            bundleID: id,
            appName: appName.trimmingCharacters(in: .whitespacesAndNewlines),
            timings: AutoInputSourceTimings(firstActivation: .followGlobal,
                                            reactivation: .followGlobal)))
        persistConfiguration()
    }

    func removeRule(bundleID: String) {
        configuration.rules.removeAll { $0.bundleID == bundleID }
        persistConfiguration()
    }

    func updateRule(bundleID: String, firstActivation: Bool,
                    behavior: AutoInputSourceBehavior) {
        guard let index = configuration.rules.firstIndex(where: { $0.bundleID == bundleID })
        else { return }
        if firstActivation {
            configuration.rules[index].timings.firstActivation = behavior
        } else {
            configuration.rules[index].timings.reactivation = behavior
        }
        persistConfiguration()
    }

    func updateGlobal(firstActivation: Bool, behavior: AutoInputSourceBehavior) {
        // The global default has nothing above it to follow.
        let behavior = behavior.withoutFollowGlobal
        if firstActivation {
            configuration.global.firstActivation = behavior
        } else {
            configuration.global.reactivation = behavior
        }
        persistConfiguration()
    }

    func addExclusion(bundleID: String) {
        let id = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AutoInputSourceSupport.isValidBundleID(id),
              !configuration.excludedBundleIDs.contains(id) else { return }
        configuration.excludedBundleIDs.append(id)
        persistConfiguration()
    }

    func removeExclusion(bundleID: String) {
        configuration.excludedBundleIDs.removeAll { $0 == bundleID }
        persistConfiguration()
    }

    func replaceConfiguration(with new: AutoInputSourceConfiguration) {
        configuration = AutoInputSourceSupport.sanitized(new)
        persistConfiguration()
    }

    // MARK: - Rules file

    func exportData() -> Data {
        AutoInputSourceSupport.exportData(configuration)
    }

    func importConfiguration(from data: Data)
        -> Result<AutoInputSourceConfiguration, AutoInputSourceSupport.ImportFailure> {
        let result = AutoInputSourceSupport.importConfiguration(from: data)
        if case .success(let imported) = result {
            replaceConfiguration(with: imported)
        }
        return result
    }

    // MARK: - Storage

    private func reloadConfiguration() {
        let raw = defaults.string(forKey: DefaultsKey.autoInputSourceData)
        guard raw != storedConfiguration else { return }
        configuration = AutoInputSourceSupport.decodeConfiguration(raw)
        storedConfiguration = raw
    }

    private func reloadLastSources() {
        lastSources = AutoInputSourceSupport.decodeLastSources(
            defaults.string(forKey: DefaultsKey.autoInputSourceLastSources))
    }

    /// Picks up changes made outside this service, such as a settings import
    /// from Tina's own settings backup.
    private func configurationDidChange() {
        let before = storedConfiguration
        reloadConfiguration()
        // Enabled input sources have their own notification; only a changed
        // rules blob needs the current source and list read again here.
        if before != storedConfiguration { refresh() }
    }

    private func persistConfiguration() {
        configuration = AutoInputSourceSupport.sanitized(configuration)
        let raw = AutoInputSourceSupport.encodeConfiguration(configuration)
        storedConfiguration = raw
        defaults.set(raw, forKey: DefaultsKey.autoInputSourceData)
    }

    private func persistLastSources() {
        defaults.set(AutoInputSourceSupport.encodeLastSources(lastSources),
                     forKey: DefaultsKey.autoInputSourceLastSources)
    }

    // MARK: - Text input sources

    private static func readOptions() -> [AutoInputSourceOption] {
        InputSourceSelection.selectableInputSources().compactMap { source in
            guard let id = InputSourceSelection.inputSourceString(
                source, property: kTISPropertyInputSourceID), !id.isEmpty
            else { return nil }
            return AutoInputSourceOption(
                id: id,
                name: InputSourceSelection.inputSourceString(
                    source, property: kTISPropertyLocalizedName) ?? id,
                code: InputSourceSelection.shortCode(
                    languages: InputSourceSelection.languages(of: source)),
                isLayout: InputSourceSelection.inputSourceString(
                    source, property: kTISPropertyInputSourceType)
                    == kTISTypeKeyboardLayout as String)
        }
    }
}
