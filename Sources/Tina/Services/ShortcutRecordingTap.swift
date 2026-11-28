// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import ApplicationServices
import CoreGraphics
import Foundation

/// While a shortcut field is listening, every new key press belongs to the field.
/// This active tap swallows key events ahead of the system, other apps'
/// global shortcuts and this app's own menu, and hands them to the field.
/// Without it, typing a combination something answers to performs that action
/// instead of landing in the field: recording Command Q would quit an app,
/// and combinations the system consumes could never be recorded at all.
///
/// The tap lives only while a field records, plus the tails of any keys it
/// captured that are still held. Presses begun outside the field keep their
/// repeats and releases so downstream taps can balance them. Only one field ever
/// records at a time (the ShortcutCapture invariant), so one static tap is
/// enough. Main thread only. Without Accessibility, begin fails and the
/// field falls back to plain view events, which is how it always worked.
enum ShortcutRecordingTap {
    private static var tap: CFMachPort?
    private static var runLoopSource: CFRunLoopSource?
    private static var handler: ((Int64, GlobalShortcutModifiers, CGEventFlags) -> Void)?
    /// Only fresh downs swallowed by this tap own their repeat and release.
    /// Retain ownership if a field starts again before the previous tail ends.
    private static var ownedKeyCodes: Set<Int64> = []
    private static var drainWatchdog: DispatchWorkItem?
    /// This tap sits at the HID head, ahead of the super key's HID tail even
    /// after a restart, so the trigger key arrives bare. Reading it the same way
    /// as the super key lets a field record the combination the way it will be
    /// pressed later, instead of asking for the chosen modifiers by hand.
    private static var superState = SuperKeySupport.State()
    private static var superKeyTap: CFMachPort?
    private static var observingSession = false

    /// Starts swallowing key events and delivering each fresh press to the
    /// handler. Returns false when the tap cannot exist (no Accessibility),
    /// in which case the caller keeps its ordinary event path.
    @discardableResult
    static func begin(_ newHandler: @escaping (Int64, GlobalShortcutModifiers, CGEventFlags) -> Void) -> Bool {
        drainWatchdog?.cancel()
        drainWatchdog = nil
        resetSuperKey()
        // Registered before the Accessibility check: ShortcutCapture.begin() has
        // already switched the global shortcuts off, and the resign must give them back.
        if !observingSession {
            observingSession = true
            SessionActivity.shared.onChange { if !$0 { tearDown(); ShortcutCapture.end() } }
        }
        // A tap the system disabled behind our back reads as dead; rebuild.
        if let tap, !CGEvent.tapIsEnabled(tap: tap) {
            tearDown()
        }
        if tap == nil {
            guard AXIsProcessTrusted() else { return false }
            let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
                | (CGEventMask(1) << CGEventType.keyUp.rawValue)
            guard let created = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: { _, type, event, _ in
                    ShortcutRecordingTap.handle(type: type, event: event)
                },
                userInfo: nil
            ) else { return false }
            tap = created
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: created, enable: true)
        }
        handler = newHandler
        return true
    }

    /// Safe to call twice and when begin failed. The tap lingers while any
    /// swallowed presses still need their matching releases.
    static func end() {
        handler = nil
        guard tap != nil else { return }
        if ownedKeyCodes.isEmpty {
            tearDown()
        } else {
            armDrainWatchdog()
        }
    }

    /// The drain must outlive the key, not the clock: each swallowed
    /// autorepeat pushes the deadline back, so the tap dies after a second of
    /// silence instead of mid-hold, where the key's remaining repeats would
    /// reach the frontmost app as fresh presses of the recorded combination.
    private static func armDrainWatchdog() {
        drainWatchdog?.cancel()
        let watchdog = DispatchWorkItem { tearDown() }
        drainWatchdog = watchdog
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: watchdog)
    }

    private static func tearDown() {
        drainWatchdog?.cancel()
        drainWatchdog = nil
        ownedKeyCodes.removeAll()
        handler = nil
        resetSuperKey()
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    /// A keyboard can disappear on wake and return under the same event tap.
    static func resetSuperKey() {
        superKeyTap = nil
        superState.reset()
    }

    private static func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if SessionActivity.shared.isActive, AXIsProcessTrusted(), let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            } else {
                DispatchQueue.main.async { tearDown(); ShortcutCapture.end() }
            }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown || type == .keyUp else { return Unmanaged.passUnretained(event) }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let isFreshDown = type == .keyDown && !isRepeat
        if type == .keyUp {
            guard ownedKeyCodes.remove(keyCode) != nil else { return Unmanaged.passUnretained(event) }
        } else if isRepeat {
            guard ownedKeyCodes.contains(keyCode) else { return Unmanaged.passUnretained(event) }
        } else if handler != nil {
            ownedKeyCodes.insert(keyCode)
        } else {
            // A new down is not a drain tail, even if an earlier up was lost.
            ownedKeyCodes.remove(keyCode)
            if ownedKeyCodes.isEmpty { tearDown() }
            return Unmanaged.passUnretained(event)
        }

        guard let handler else {
            if ownedKeyCodes.isEmpty { tearDown() }
            else if isRepeat { armDrainWatchdog() }
            return nil
        }

        // Process Super Key only after checking ownership: it also needs the
        // release if its own HID tap saw the down before recording started.
        var heldModifiers: GlobalShortcutModifiers = []
        let keyboard = SuperKeyService.shared.keyboardTapForRecording
        if keyboard !== superKeyTap {
            superState.reset()
            superKeyTap = keyboard
        }
        let modifiers = GlobalShortcutModifiers(cgFlags: event.flags)
        let superEvent: SuperKeySupport.Event
        if keyCode == SuperKeySupport.triggerKeyCode {
            let timestamp = EventTimestamp.nanoseconds(of: event)
            superEvent = type == .keyDown
                ? .triggerDown(isRepeat: isRepeat, hasPrimaryModifiers: !modifiers.isEmpty, timestamp: timestamp)
                : .triggerUp(timestamp: timestamp)
        } else {
            superEvent = .otherKey
        }
        if superState.shouldCapture(superEvent, enabled: keyboard != nil) {
            switch superState.decide(superEvent) {
            case .swallow, .soloTap(repeated: _), .soloHold(repeated: _): return nil
            case .addModifiers: heldModifiers = SuperKeyService.shared.modifiers
            case .pass, .interceptAndRemap: break
            }
        }
        if isFreshDown { handler(keyCode, modifiers.union(heldModifiers), event.flags) }
        return nil
    }
}
