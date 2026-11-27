// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import ApplicationServices
import AppKit
import CoreGraphics
import Foundation

/// A session-level keyboard tap that rewrites the keys the user mapped. Only
/// single key-to-key mappings run here; macros, timing and recorded sequences
/// stay out. Without Accessibility the tap is never installed, so no key is
/// ever swallowed.
final class InputRemapService {
    static let shared = InputRemapService()

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var rules: [InputRemapRule] = []
    /// The frontmost app is read on each press so the exclusion list follows
    /// app switches without another observer.
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
    func start() -> Bool {
        guard tap == nil else { return true }
        guard AXIsProcessTrusted() else { return false }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: CGEventMask(mask),
                                          callback: { proxy, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let service = Unmanaged<InputRemapService>.fromOpaque(userInfo)
                .takeUnretainedValue()
            return service.handle(proxy: proxy, type: type, event: event)
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
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        source = nil
        tap = nil
    }

    /// A disabled tap (timeout, user disable) is re-enabled and the event is
    /// passed through untouched, so a stall never eats input.
    private func handle(proxy: CGEventTapProxy, type: CGEventType,
                        event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        var modifiers: GlobalShortcutModifiers = []
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        guard let rule = InputRemapSupport.rule(for: keyCode,
                                                modifiers: modifiers,
                                                bundleID: frontmostBundleID(),
                                                rules: rules) else {
            return Unmanaged.passUnretained(event)
        }
        let target = InputRemapSupport.target(for: rule)
        let down = type == .keyDown
        guard let synthetic = CGEvent(keyboardEventSource: nil,
                                      virtualKey: CGKeyCode(target.keyCode),
                                      keyDown: down) else {
            return Unmanaged.passUnretained(event)
        }
        var targetFlags: CGEventFlags = []
        if target.modifiers.contains(.control) { targetFlags.insert(.maskControl) }
        if target.modifiers.contains(.option) { targetFlags.insert(.maskAlternate) }
        if target.modifiers.contains(.shift) { targetFlags.insert(.maskShift) }
        if target.modifiers.contains(.command) { targetFlags.insert(.maskCommand) }
        synthetic.flags = targetFlags
        synthetic.post(tap: .cghidEventTap)
        // The original key never reaches the app.
        return nil
    }
}
