// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// The live result of every global shortcut registration, kept in one place.
///
/// Each feature still owns its own registration path and its own settings
/// page; this type is a read-only summary. A service reports here after every
/// attempt, so the central Shortcuts page can say that a shortcut the user
/// saved never reached the system instead of only warning on the feature page
/// the user may never open.
///
/// Nothing in here retries on its own: `retryAll()` re-runs the closure each
/// owner supplied with its failed report, which is the service's ordinary
/// registration path.
final class ShortcutRegistrationAudit: ObservableObject {
    static let shared = ShortcutRegistrationAudit()

    /// Keys whose latest registration attempt failed. Storage keys are
    /// `GlobalShortcutRole.storageKey` values, so the central page can match
    /// a row to its state without a second mapping table.
    @Published private(set) var failedKeys: Set<String> = []

    private let lock = NSLock()
    private var failures: Set<String> = []
    private var retryActions: [String: () -> Void] = [:]

    /// Records the outcome of one attempt. `retry` is kept only while the key
    /// is failing; a successful attempt drops it.
    func report(key: String, failed: Bool, retry: (() -> Void)? = nil) {
        lock.lock()
        if failed {
            failures.insert(key)
            if let retry { retryActions[key] = retry }
        } else {
            failures.remove(key)
            retryActions[key] = nil
        }
        let snapshot = failures
        lock.unlock()
        publish(snapshot)
    }

    /// Forgets a key entirely, for a feature that was uninstalled or turned
    /// off and no longer registers a shortcut at all.
    func clear(key: String) {
        report(key: key, failed: false)
    }

    func isFailed(_ key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return failures.contains(key)
    }

    /// Asks every failing owner to run its registration path once more. The
    /// answers come back through `report`, so the set updates on its own.
    func retryAll() {
        lock.lock()
        let actions = Array(retryActions.values)
        lock.unlock()
        actions.forEach { $0() }
    }

    func resetForTests() {
        lock.lock()
        failures.removeAll()
        retryActions.removeAll()
        lock.unlock()
        publish([])
    }

    private func publish(_ snapshot: Set<String>) {
        let apply = { [weak self] in
            guard let self, self.failedKeys != snapshot else { return }
            self.failedKeys = snapshot
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }
}
