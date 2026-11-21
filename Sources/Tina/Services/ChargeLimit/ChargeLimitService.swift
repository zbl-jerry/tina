// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation
import os
import ServiceManagement

/// Holds the user's charge limit while Tina runs. The limit itself lives in
/// the privileged helper: this service registers it, sends the policy, and
/// mirrors what the hardware reports. Quitting Tina, or losing the connection
/// to the helper, puts normal charging back.
final class ChargeLimitService: ObservableObject {
    enum AccessState: Equatable {
        case notRegistered
        case requiresApproval
        case enabled
        case unavailable
    }

    static let shared = ChargeLimitService()

    @Published private(set) var accessState: AccessState = .notRegistered
    @Published private(set) var status: ChargeLimitStatus = .empty
    @Published private(set) var error: ChargeLimitErrorCode?
    @Published private(set) var isWorking = false

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "tina",
                                    category: "ChargeLimit")
    private static let helperDefaultsKey = DefaultsKey.fanControlHelperVersion

    private var connection: NSXPCConnection?
    private var timer: Timer?
    private var requestInFlight = false
    private var requestGeneration = 0
    private var registrationAttemptedVersion: String?
    private var observingWorkspace = false

    private static var appService: SMAppService {
        SMAppService.daemon(plistName: FanControlIdentifiers.plistName)
    }

    /// The same stamp the fan helper uses: the helper binary and its plist.
    private static var helperVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "TinaFanControlHelperVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? AppInfo.version
    }

    private init() {
        refreshAccessState()
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        connection?.invalidate()
        timer?.invalidate()
    }

    // MARK: - Preferences

    /// The single entry point for a toggle, a slider move, a feature install or
    /// uninstall, and the launch-time sync.
    func syncWithPreferences() {
        guard AppFeature.chargeLimit.isAvailable,
              UserDefaults.standard.bool(forKey: DefaultsKey.chargeLimitEnabled) else {
            stopHolding()
            return
        }
        refreshAccessState()
        switch accessState {
        case .enabled:
            if replaceRegistrationIfNeeded() { return }
            startObservingWorkspace()
            applyLimit()
            startTimerIfNeeded()
        case .notRegistered:
            register()
        case .requiresApproval:
            startTimerIfNeeded()
        case .unavailable:
            error = .unsupportedHardware
        }
    }

    /// The card's approve button, and the automatic path when the feature is
    /// switched on for the first time.
    func authorize() {
        refreshAccessState()
        switch accessState {
        case .requiresApproval:
            SMAppService.openSystemSettingsLoginItems()
        case .notRegistered:
            register()
        case .enabled:
            applyLimit()
        case .unavailable:
            error = .unsupportedHardware
        }
    }

    func refresh() {
        refreshAccessState()
        if accessState == .enabled { applyLimit() }
    }

    private func register() {
        guard !isWorking else { return }
        isWorking = true
        do {
            try Self.appService.register()
            UserDefaults.standard.set(Self.helperVersion, forKey: Self.helperDefaultsKey)
            isWorking = false
            refreshAccessState()
            // Registration returns before macOS flips the state to enabled;
            // the approval notification and the next sync finish the job.
            if accessState == .enabled {
                applyLimit()
                startTimerIfNeeded()
            }
        } catch {
            isWorking = false
            refreshAccessState()
            Self.log.error("Charge limit helper registration failed: \(error.localizedDescription, privacy: .public)")
            if accessState == .enabled {
                applyLimit()
            } else {
                self.error = .controlFailed
            }
        }
    }

    private func refreshAccessState() {
        switch Self.appService.status {
        case .notRegistered: accessState = .notRegistered
        case .enabled: accessState = .enabled
        case .requiresApproval: accessState = .requiresApproval
        case .notFound: accessState = .notRegistered
        @unknown default: accessState = .unavailable
        }
    }

    /// An update brings a helper other than the registered one. Apple requires
    /// the old registration to be removed first. Runs once per build.
    private func replaceRegistrationIfNeeded() -> Bool {
        let installed = UserDefaults.standard.string(forKey: Self.helperDefaultsKey) ?? ""
        let current = Self.helperVersion
        guard !installed.isEmpty, installed != current,
              registrationAttemptedVersion != current else { return false }
        registrationAttemptedVersion = current
        isWorking = true
        Self.appService.unregister { error in
            DispatchQueue.main.async {
                guard error == nil else {
                    self.isWorking = false
                    self.error = .controlFailed
                    return
                }
                do {
                    try Self.appService.register()
                    UserDefaults.standard.set(current, forKey: Self.helperDefaultsKey)
                    self.isWorking = false
                    self.refreshAccessState()
                    if self.accessState == .enabled {
                        self.applyLimit()
                        self.startTimerIfNeeded()
                    }
                } catch {
                    self.isWorking = false
                    self.refreshAccessState()
                    self.error = .controlFailed
                }
            }
        }
        return true
    }

    // MARK: - Requests

    func applyLimit() {
        let configuration = ChargeLimitConfiguration(
            upperPercent: ChargeLimitPolicy.sanitizedPercent(
                UserDefaults.standard.integer(forKey: DefaultsKey.chargeLimitPercent)),
            chargeToFull: false)
        request { proxy, reply in
            guard let data = ChargeLimitIPC.encode(configuration) else {
                reply(ChargeLimitIPC.encode(.failure(.controlFailed)))
                return
            }
            proxy.applyChargeLimit(data, withReply: reply)
        }
    }

    func chargeToFull() {
        let configuration = ChargeLimitConfiguration(
            upperPercent: ChargeLimitPolicy.sanitizedPercent(
                UserDefaults.standard.integer(forKey: DefaultsKey.chargeLimitPercent)),
            chargeToFull: true)
        // An explicit click supersedes a periodic refresh; the request
        // generation keeps the later reply from being overwritten.
        request(force: true) { proxy, reply in
            guard let data = ChargeLimitIPC.encode(configuration) else {
                reply(ChargeLimitIPC.encode(.failure(.controlFailed)))
                return
            }
            proxy.applyChargeLimit(data, withReply: reply)
        }
    }

    private func request(force: Bool = false,
                         _ operation: @escaping (FanControlXPCProtocol,
                                                 @escaping (Data) -> Void) -> Void) {
        guard force || !requestInFlight else { return }
        let generation = beginRequest()
        send(operation) { response in
            guard self.finishRequest(generation) else { return }
            guard let response else {
                self.error = .controlFailed
                return
            }
            self.status = response.status
            self.error = response.error
        }
    }

    /// Stops holding the limit and puts charging back. Called when the feature
    /// is switched off or uninstalled.
    private func stopHolding() {
        timer?.invalidate()
        timer = nil
        guard accessState == .enabled, hasSentAControlRequest else {
            status = .empty
            error = nil
            return
        }
        send({ proxy, reply in proxy.restoreCharging(withReply: reply) }) { response in
            if let response {
                self.status = response.status
                self.error = response.error
            }
            // With the feature off nothing needs the daemon, so let it exit
            // when its own work is done instead of holding a connection open.
            self.connection?.invalidate()
            self.connection = nil
        }
    }

    /// Whether a restore is owed. A fresh launch with the feature off has
    /// nothing to undo, and must not open a connection just to say so.
    private var hasSentAControlRequest: Bool {
        status.upperPercent != nil || status.isInhibited
    }

    private func send(_ operation: @escaping (FanControlXPCProtocol,
                                              @escaping (Data) -> Void) -> Void,
                      completion: @escaping (ChargeLimitResponse?) -> Void) {
        guard let proxy = proxy() else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        operation(proxy) { data in
            let response = ChargeLimitIPC.decode(data)
            DispatchQueue.main.async { completion(response) }
        }
    }

    private func proxy() -> FanControlXPCProtocol? {
        if connection == nil {
            let connection = NSXPCConnection(machServiceName: FanControlIdentifiers.helperID,
                                             options: .privileged)
            connection.remoteObjectInterface = NSXPCInterface(with: FanControlXPCProtocol.self)
            connection.setCodeSigningRequirement(FanControlIdentifiers.helperCodeRequirement)
            connection.interruptionHandler = { [weak self, weak connection] in
                DispatchQueue.main.async {
                    guard let connection, self?.connection === connection else { return }
                    connection.invalidate()
                    self?.connection = nil
                    // The helper restores charging when this connection drops,
                    // so the card must not keep claiming the limit is held.
                    self?.status.isInhibited = false
                }
            }
            connection.invalidationHandler = { [weak self, weak connection] in
                DispatchQueue.main.async {
                    guard let connection else { return }
                    if self?.connection === connection { self?.connection = nil }
                }
            }
            connection.activate()
            self.connection = connection
        }
        guard let connection else { return nil }
        return connection.remoteObjectProxyWithErrorHandler { [weak self] _ in
            DispatchQueue.main.async {
                self?.connection?.invalidate()
                self?.connection = nil
                self?.error = .controlFailed
            }
        } as? FanControlXPCProtocol
    }

    private func beginRequest() -> Int {
        requestGeneration += 1
        requestInFlight = true
        return requestGeneration
    }

    private func finishRequest(_ generation: Int) -> Bool {
        guard generation == requestGeneration else { return false }
        requestInFlight = false
        return true
    }

    // MARK: - Timers and system state

    private func startTimerIfNeeded() {
        guard AppFeature.chargeLimit.isAvailable,
              UserDefaults.standard.bool(forKey: DefaultsKey.chargeLimitEnabled) else { return }
        startObservingWorkspace()
        guard timer == nil else { return }
        // The helper enforces on its own cadence; this timer refreshes the card
        // and re-sends the policy after a missed connection.
        let timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.refreshAccessState()
            if self.accessState == .enabled { self.applyLimit() }
        }
        timer.tolerance = 5
        self.timer = timer
    }

    private func startObservingWorkspace() {
        guard !observingWorkspace else { return }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(workspaceDidWake),
            name: NSWorkspace.didWakeNotification, object: nil)
        observingWorkspace = true
    }

    @objc private func workspaceDidWake() {
        guard AppFeature.chargeLimit.isAvailable,
              UserDefaults.standard.bool(forKey: DefaultsKey.chargeLimitEnabled) else { return }
        refreshAccessState()
        if accessState == .enabled { applyLimit() }
    }

    // MARK: - Removal

    /// Puts charging back before the bundle, and its helper, are removed. Runs
    /// on the caller's background queue like the fan helper's teardown.
    @discardableResult
    static func restoreForRemoval() -> Bool {
        shared.restoreSynchronously()
    }

    private func restoreSynchronously() -> Bool {
        refreshAccessState()
        guard accessState != .notRegistered, accessState != .unavailable else { return true }
        guard let proxy = proxy() else { return false }
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var restored = false
        let generation = beginRequest()
        proxy.restoreCharging { data in
            if let response = ChargeLimitIPC.decode(data), response.succeeded {
                lock.withLock { restored = true }
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 20)
        lock.withLock {
            if restored { status.isInhibited = false }
        }
        _ = finishRequest(generation)
        return restored
    }
}
