// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import ApplicationServices
import AppKit
import CoreGraphics
import Foundation

/// A session-level keyboard tap that rewrites the keys the user mapped. Only
/// single key-to-key mappings run here; macros, timing and recorded sequences
/// stay out. Without Accessibility the tap is never installed, so no key is
/// ever swallowed. Main thread only, including the tap's callback.
final class InputRemapService {
    static let shared = InputRemapService()

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var rules: [InputRemapRule] = []
    private var presses = InputRemapSupport.Presses()
    private var isCapturingShortcut: () -> Bool = { false }
    /// The frontmost app is read on each fresh press, not its repeat or up.
    var frontmostBundleID: () -> String? = {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private init() {}

    var isRunning: Bool { tap != nil }

    func setRules(_ rules: [InputRemapRule]) {
        self.rules = InputRemapSupport.sanitized(rules)
    }

    /// Installs the tap. Returns false when Accessibility is missing or the
    /// system refuses the tap; callers surface that instead of pretending.
    @discardableResult
    func start(isCapturingShortcut: @escaping () -> Bool) -> Bool {
        guard AXIsProcessTrusted() else {
            stop()
            return false
        }
        self.isCapturingShortcut = isCapturingShortcut
        guard tap == nil else { return true }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: CGEventMask(mask),
                                          callback: { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let service = Unmanaged<InputRemapService>.fromOpaque(userInfo)
                .takeUnretainedValue()
            return service.handle(type: type, event: event)
        },
                                          userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return false }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }
        self.tap = tap
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        let stoppedTap = tap
        tap = nil
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let stoppedTap {
            CGEvent.tapEnable(tap: stoppedTap, enable: false)
            CFMachPortInvalidate(stoppedTap)
        }
        source = nil
        isCapturingShortcut = { false }
        releaseHeldKeys()
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent> {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // A release may have passed while the filter was disabled.
            // Balance outstanding replacements before starting fresh.
            if let tap, AXIsProcessTrusted() {
                releaseHeldKeys()
                CGEvent.tapEnable(tap: tap, enable: true)
            } else {
                stop()
            }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown || type == .keyUp,
              let keyCode = UInt16(exactly: event.getIntegerValueField(.keyboardEventKeycode)) else {
            return Unmanaged.passUnretained(event)
        }
        let phase: InputRemapSupport.Presses.Phase = type == .keyUp ? .up
            : (event.getIntegerValueField(.keyboardEventAutorepeat) == 0 ? .down : .repeatDown)
        let target = presses.target(for: keyCode, phase: phase) {
            // The recording tap normally owns this key before us. If it
            // could not install, the recorder's view still needs raw keys.
            guard !isCapturingShortcut(), !rules.isEmpty else { return nil }
            return InputRemapSupport.rule(for: keyCode,
                                          modifiers: GlobalShortcutModifiers(cgFlags: event.flags),
                                          bundleID: frontmostBundleID(),
                                          rules: rules)
        }
        guard let target else {
            return Unmanaged.passUnretained(event)
        }
        // A replacement returned from the callback continues after this tap.
        // Reposting it at HID would feed chained rules back into this filter.
        let replacement = Self.replacement(for: event, target: target)
        return replacement === event ? Unmanaged.passUnretained(event) : Unmanaged.passRetained(replacement)
    }

    static func replacement(for event: CGEvent, target: GlobalShortcut) -> CGEvent {
        let replacement = CGEvent(keyboardEventSource: CGEventSource(event: event),
                                  virtualKey: CGKeyCode(target.keyCode),
                                  keyDown: event.type == .keyDown) ?? event
        // A fresh keyboard event avoids stale source-key Unicode; modifying
        // the original is a fallback only if the replacement cannot allocate.
        if replacement === event {
            replacement.setIntegerValueField(.keyboardEventKeycode, value: target.keyCode)
        } else {
            replacement.timestamp = event.timestamp
            replacement.location = event.location
            for field: CGEventField in [.keyboardEventAutorepeat, .keyboardEventKeyboardType, .eventSourceUserData] {
                replacement.setIntegerValueField(field, value: event.getIntegerValueField(field))
            }
        }
        let preservedFlags = event.flags.intersection([.maskAlphaShift, .maskNonCoalesced])
        replacement.flags = preservedFlags.union(target.syntheticEventFlags)
        return replacement
    }

    private func releaseHeldKeys() {
        let targets = presses.finish()
        guard !targets.isEmpty, AXIsProcessTrusted() else { return }
        for target in targets {
            guard let event = CGEvent(keyboardEventSource: nil,
                                      virtualKey: CGKeyCode(target.keyCode), keyDown: false) else { continue }
            event.flags = target.syntheticEventFlags
            event.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
