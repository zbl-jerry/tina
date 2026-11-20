// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreGraphics
import Foundation

/// Applies a schedule-driven colour temperature to every active display and
/// fades between temperatures instead of stepping.
///
/// The mechanism is a gamma table per display through public CoreGraphics
/// APIs: no helper, no permission, no window, no network. The tables belong
/// to the session, so the feature's whole footprint is gone when the tables
/// are set back to the identity, which happens when the feature is switched
/// off, when the app quits, and once after a crash that left a tint behind.
///
/// Nothing runs while the feature is off: no timer, no observers, and no
/// gamma writes.
final class NightWarmthService: ObservableObject {
    static let shared = NightWarmthService()

    /// The phase the schedule is in right now, pause included.
    @Published private(set) var phase: NightWarmthPhase = .day
    /// The temperature currently on screen, rounded for display.
    @Published private(set) var currentKelvin: Double = NightWarmthPreset.neutral
    /// Where the fade is heading.
    @Published private(set) var targetKelvin: Double = NightWarmthPreset.neutral
    @Published private(set) var pausedUntil: Date?
    /// False when every active display refused the table, which leaves the
    /// feature installed but visibly inert instead of silently broken.
    @Published private(set) var supported = true

    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var appliedKelvin = NightWarmthPreset.neutral
    private var lastAppliedKey = ""
    private var lastPhase: NightWarmthPhase = .day
    private var manualOffset: Double = 0
    private var running = false
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Lifecycle

    func syncWithPreferences() {
        let enabled = AppFeature.nightWarmth.isAvailable
            && defaults.bool(forKey: DefaultsKey.nightWarmthEnabled)
        guard enabled else {
            stop()
            // A crash can end the process between a tint and its cleanup.
            // The next start puts the identity back once, then forgets it.
            if defaults.bool(forKey: DefaultsKey.nightWarmthApplied) {
                restoreDisplays()
            }
            return
        }
        start()
    }

    /// Stops the schedule and puts the original colours back. Safe to call
    /// repeatedly and safe when the feature never ran.
    func stop() {
        timer?.invalidate()
        timer = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
        let wasRunning = running
        running = false
        if wasRunning || defaults.bool(forKey: DefaultsKey.nightWarmthApplied) {
            restoreDisplays()
        }
        appliedKelvin = NightWarmthPreset.neutral
        lastAppliedKey = ""
        lastPhase = .day
        manualOffset = 0
        if phase != .day { phase = .day }
        if currentKelvin != NightWarmthPreset.neutral { currentKelvin = NightWarmthPreset.neutral }
        if targetKelvin != NightWarmthPreset.neutral { targetKelvin = NightWarmthPreset.neutral }
        if pausedUntil != nil { pausedUntil = nil }
        if !supported { supported = true }
    }

    /// Called from the app's termination path, where the feature's own
    /// enabled state no longer matters: any tint still on screen is removed.
    func restoreBeforeTermination() {
        timer?.invalidate()
        timer = nil
        if defaults.bool(forKey: DefaultsKey.nightWarmthApplied) {
            restoreDisplays()
        }
    }

    private func start() {
        if let raw = defaults.object(forKey: DefaultsKey.nightWarmthPausedUntil) as? Double,
           raw > 0 {
            let date = Date(timeIntervalSince1970: raw)
            pausedUntil = date > Date() ? date : nil
        } else {
            pausedUntil = nil
        }
        guard !running else {
            tick()
            return
        }
        running = true
        installObservers()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // Common mode keeps the fade running while a menu is open or the
        // pointer is being dragged, so opening the panel never freezes it.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    private func installObservers() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                self?.applyIfNeeded(force: true)
            })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main) { [weak self] _ in
                self?.applyIfNeeded(force: true)
            })
    }

    // MARK: - Tick

    private func tick() {
        guard running else { return }
        let now = Date()
        if let until = pausedUntil, until <= now {
            pausedUntil = nil
            defaults.set(0, forKey: DefaultsKey.nightWarmthPausedUntil)
        }
        let model = Self.model()
        let state = NightWarmthSupport.state(at: now, model: model,
                                             timeZone: .current, pausedUntil: pausedUntil)
        if state.phase != lastPhase {
            // A manual nudge lasts for the phase it was made in. The next
            // scheduled change is the schedule's, not the user's.
            lastPhase = state.phase
            manualOffset = 0
        }
        if phase != state.phase { phase = state.phase }
        let base = state.phase == .paused ? model.dayKelvin : state.targetKelvin
        let target = NightWarmthSupport.clampedKelvin(base + manualOffset)
        if targetKelvin != target { targetKelvin = target }
        let transition: NightWarmthTransition = state.phase == .paused
            ? .fast
            : Self.transition(defaults: defaults)
        advance(toward: target, transition: transition)
    }

    /// Moves the tint at least one step toward the target. A full range fade
    /// takes the whole transition duration, so Slow crosses the presets over
    /// an hour and Fast over twenty seconds.
    private func advance(toward target: Double, transition: NightWarmthTransition) {
        let fullRange = NightWarmthPreset.neutral - NightWarmthPreset.warmest
        let step = fullRange / max(transition.seconds, 1)
        let delta = target - appliedKelvin
        if abs(delta) <= step {
            appliedKelvin = target
        } else {
            appliedKelvin += delta > 0 ? step : -step
        }
        let rounded = appliedKelvin.rounded()
        if currentKelvin != rounded { currentKelvin = rounded }
        applyIfNeeded()
    }

    private func applyIfNeeded(force: Bool = false) {
        let key = String(Int((appliedKelvin * 10).rounded()))
        guard force || key != lastAppliedKey else { return }
        lastAppliedKey = key
        apply(kelvin: appliedKelvin)
    }

    // MARK: - Displays

    private func apply(kelvin: Double) {
        let ramp = NightWarmthSupport.ramp(kelvin: kelvin)
        var accepted = false
        var refused = false
        for display in Self.activeDisplays() {
            if setTables(display: display, ramp: ramp) == .success {
                accepted = true
            } else {
                refused = true
            }
        }
        if accepted {
            if !defaults.bool(forKey: DefaultsKey.nightWarmthApplied) {
                defaults.set(true, forKey: DefaultsKey.nightWarmthApplied)
            }
            if !supported { supported = true }
        } else if refused, supported {
            supported = false
        }
    }

    private func restoreDisplays() {
        let identity = NightWarmthSupport.identityRamp
        for display in Self.activeDisplays() {
            _ = setTables(display: display, ramp: identity)
        }
        defaults.set(false, forKey: DefaultsKey.nightWarmthApplied)
    }

    private func setTables(display: CGDirectDisplayID, ramp: NightWarmthRamp) -> CGError {
        ramp.red.withUnsafeBufferPointer { red in
            ramp.green.withUnsafeBufferPointer { green in
                ramp.blue.withUnsafeBufferPointer { blue in
                    guard let redBase = red.baseAddress,
                          let greenBase = green.baseAddress,
                          let blueBase = blue.baseAddress else { return .failure }
                    return CGSetDisplayTransferByTable(display, UInt32(ramp.red.count),
                                                       redBase, greenBase, blueBase)
                }
            }
        }
    }

    private static func activeDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var identifiers = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &identifiers, &count) == .success else { return [] }
        return Array(identifiers.prefix(Int(count)))
    }

    // MARK: - Manual actions

    /// Warmer lowers the kelvin number. The nudge applies to the current
    /// phase and is cleared by the next scheduled change.
    func adjust(warmer: Bool) {
        let model = Self.model()
        let state = NightWarmthSupport.state(at: Date(), model: model,
                                             timeZone: .current, pausedUntil: pausedUntil)
        let base = state.phase == .paused ? model.dayKelvin : state.targetKelvin
        let delta = warmer ? -250.0 : 250.0
        manualOffset = min(max(manualOffset + delta,
                               NightWarmthPreset.warmest - base),
                           NightWarmthPreset.neutral - base)
        tick()
    }

    /// A preset is a temporary target for the current phase, like Warmer and
    /// Cooler, so tapping one never rewrites the schedule.
    func applyPreset(_ kelvin: Double) {
        let model = Self.model()
        let state = NightWarmthSupport.state(at: Date(), model: model,
                                             timeZone: .current, pausedUntil: pausedUntil)
        let base = state.phase == .paused ? model.dayKelvin : state.targetKelvin
        manualOffset = NightWarmthSupport.clampedKelvin(kelvin) - base
        tick()
    }

    func pause(for seconds: TimeInterval) {
        let until = Date().addingTimeInterval(seconds)
        pausedUntil = until
        defaults.set(until.timeIntervalSince1970, forKey: DefaultsKey.nightWarmthPausedUntil)
        tick()
    }

    /// Pauses until the next sunrise, or until the bedtime window ends when
    /// Bedtime is on. Without solar data (a custom schedule) the pause lasts
    /// until the next wake time, which is the closest equivalent the schedule
    /// has to a morning.
    func pauseUntilMorning() {
        let model = Self.model()
        let calendar = NightWarmthSupport.calendar(.current)
        let now = Date()
        var until: Date?
        if model.bedtimeEnabled {
            until = Self.nextOccurrence(of: model.wakeMinutes, after: now, calendar: calendar)
        } else if model.mode == .sun {
            until = NightWarmthSupport.solarEvents(for: now, latitude: model.latitude,
                                                   longitude: model.longitude,
                                                   timeZone: .current).sunrise
            if let sunrise = until, sunrise <= now {
                until = NightWarmthSupport.solarEvents(
                    for: calendar.date(byAdding: .day, value: 1, to: now) ?? now,
                    latitude: model.latitude, longitude: model.longitude,
                    timeZone: .current).sunrise
            }
        }
        if until == nil {
            until = Self.nextOccurrence(of: model.wakeMinutes, after: now, calendar: calendar)
        }
        guard let until else { return }
        pausedUntil = until
        defaults.set(until.timeIntervalSince1970, forKey: DefaultsKey.nightWarmthPausedUntil)
        tick()
    }

    func resume() {
        pausedUntil = nil
        defaults.set(0, forKey: DefaultsKey.nightWarmthPausedUntil)
        tick()
    }

    func resetManualOffset() {
        manualOffset = 0
        tick()
    }

    // MARK: - Preferences

    static func model(defaults: UserDefaults = .standard,
                      timeZone: TimeZone = .current) -> NightWarmthModel {
        let mode = NightWarmthScheduleMode(
            rawValue: defaults.string(forKey: DefaultsKey.nightWarmthScheduleMode) ?? ""
        ) ?? .sun
        let suggested = NightWarmthSupport.suggestedLocation(for: timeZone)
        let hasLocation = defaults.bool(forKey: DefaultsKey.nightWarmthHasLocation)
        return NightWarmthModel(
            mode: mode,
            dayKelvin: NightWarmthSupport.clampedKelvin(
                defaults.double(forKey: DefaultsKey.nightWarmthDayKelvin)),
            eveningKelvin: NightWarmthSupport.clampedKelvin(
                defaults.double(forKey: DefaultsKey.nightWarmthEveningKelvin)),
            bedtimeKelvin: NightWarmthSupport.clampedKelvin(
                defaults.double(forKey: DefaultsKey.nightWarmthBedtimeKelvin)),
            bedtimeEnabled: defaults.bool(forKey: DefaultsKey.nightWarmthBedtimeEnabled),
            bedtimeMinutes: minutes(defaults, key: DefaultsKey.nightWarmthBedtimeMinutes),
            wakeMinutes: minutes(defaults, key: DefaultsKey.nightWarmthWakeMinutes),
            nightStartMinutes: minutes(defaults, key: DefaultsKey.nightWarmthNightStartMinutes),
            nightEndMinutes: minutes(defaults, key: DefaultsKey.nightWarmthNightEndMinutes),
            latitude: hasLocation ? defaults.double(forKey: DefaultsKey.nightWarmthLatitude)
                : suggested.latitude,
            longitude: hasLocation ? defaults.double(forKey: DefaultsKey.nightWarmthLongitude)
                : suggested.longitude,
            hasLocation: hasLocation
        )
    }

    static func transition(defaults: UserDefaults = .standard) -> NightWarmthTransition {
        NightWarmthTransition(rawValue: defaults.integer(forKey: DefaultsKey.nightWarmthTransition))
            ?? .slow
    }

    private static func minutes(_ defaults: UserDefaults, key: String) -> Int {
        let value = defaults.integer(forKey: key)
        return min(max(value, 0), 24 * 60 - 1)
    }

    private static func nextOccurrence(of minutes: Int, after date: Date,
                                       calendar: Calendar) -> Date {
        let today = NightWarmthSupport.date(on: date, minutes: minutes, calendar: calendar)
        if today > date { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
    }
}
