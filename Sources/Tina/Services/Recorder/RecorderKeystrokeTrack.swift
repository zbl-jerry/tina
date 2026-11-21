// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation
import QuartzCore

/// Where the key overlay sits in the finished picture.
enum RecorderKeystrokePlacement: String, Codable, CaseIterable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing, cursor

    /// The caption anchor that means the same corner, or nil for the pointer.
    var anchor: RecorderTextOverlay.Anchor? {
        switch self {
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        case .cursor: return nil
        }
    }
}

enum RecorderKeystrokeTheme: String, Codable, CaseIterable {
    case dark, light
}

enum RecorderKeystrokeSize: String, Codable, CaseIterable {
    case small, medium, large

    /// Height of one key cap as a share of the picture's height. Tall enough
    /// to read at a glance in a tutorial, small enough not to own the frame.
    var fraction: Double {
        switch self {
        case .small: return 0.045
        case .medium: return 0.06
        case .large: return 0.08
        }
    }
}

/// How the overlay looks. Captured with the recording, not read again at
/// export, so an old recording keeps the look it was made with.
struct RecorderKeystrokeStyle: Codable, Equatable {
    var placement: RecorderKeystrokePlacement = .bottomTrailing
    var size: RecorderKeystrokeSize = .medium
    var dwell: Double = 2
    var theme: RecorderKeystrokeTheme = .dark

    static let dwellRange: ClosedRange<Double> = 0.6...5
    static let dwellChoices: [Double] = [1, 2, 4]

    var sanitized: RecorderKeystrokeStyle {
        var copy = self
        copy.dwell = copy.dwell.isFinite
            ? min(Self.dwellRange.upperBound, max(Self.dwellRange.lowerBound, copy.dwell))
            : 2
        return copy
    }

    /// Reads the choices from the recorder's preferences. Used once per
    /// recording; the track then carries the values it actually used.
    static func fromPreferences() -> RecorderKeystrokeStyle {
        let defaults = UserDefaults.standard
        var style = RecorderKeystrokeStyle()
        style.placement = RecorderKeystrokePlacement(
            rawValue: defaults.string(forKey: DefaultsKey.recorderKeystrokePlacement) ?? "")
            ?? .bottomTrailing
        style.size = RecorderKeystrokeSize(
            rawValue: defaults.string(forKey: DefaultsKey.recorderKeystrokeSize) ?? "")
            ?? .medium
        style.theme = RecorderKeystrokeTheme(
            rawValue: defaults.string(forKey: DefaultsKey.recorderKeystrokeTheme) ?? "")
            ?? .dark
        let dwell = defaults.double(forKey: DefaultsKey.recorderKeystrokeDwell)
        style.dwell = dwell > 0 ? dwell : 2
        return style.sanitized
    }
}

/// One press, as the key caps that describe it. `keys` holds display tokens:
/// modifier glyphs first (`["⌘", "⇧", "4"]`), never the raw event or typed text.
struct RecorderKeystrokeEvent: Codable, Equatable {
    var time: Double
    var keys: [String]

    static let maximumKeys = 5
    static let maximumTokenLength = 12

    func sanitized(duration: Double) -> RecorderKeystrokeEvent? {
        guard duration > 0, time.isFinite else { return nil }
        var copy = self
        copy.time = max(0, min(time, duration))
        copy.keys = keys
            .prefix(Self.maximumKeys)
            .map { String($0.prefix(Self.maximumTokenLength)) }
            .filter { !$0.isEmpty }
        guard !copy.keys.isEmpty else { return nil }
        return copy
    }
}

/// The keys pressed during one recording, in the recording's own time.
///
/// This is the one file beside a take that holds key content, and it exists
/// only there: it is never logged, never put in the video's metadata, never
/// copied into the edit document or a backup, and it is deleted with the
/// take. A recording made without the overlay has no such file at all.
struct RecorderKeystrokeTrack: Codable, Equatable {
    var style: RecorderKeystrokeStyle
    var events: [RecorderKeystrokeEvent]

    init(style: RecorderKeystrokeStyle = RecorderKeystrokeStyle(),
         events: [RecorderKeystrokeEvent] = []) {
        self.style = style
        self.events = events
    }

    var isEmpty: Bool { events.isEmpty }

    func encoded() -> Data? { try? JSONEncoder().encode(self) }

    static func decoded(_ data: Data?) -> RecorderKeystrokeTrack {
        guard let data, let value = try? JSONDecoder().decode(Self.self, from: data)
        else { return RecorderKeystrokeTrack() }
        return value.normalized(duration: .greatestFiniteMagnitude)
    }

    /// Events are put in order, clamped to the recording and capped in amount
    /// so a tampered or runaway file cannot cost more than a recording does.
    func normalized(duration: Double) -> RecorderKeystrokeTrack {
        let limit = duration.isFinite ? duration : .greatestFiniteMagnitude
        var copy = self
        copy.style = style.sanitized
        copy.events = events
            .compactMap { $0.sanitized(duration: limit) }
            .sorted { $0.time < $1.time }
            .prefix(20_000)
            .map { $0 }
        return copy
    }

    /// The event whose key caps are on screen at `time`, if any. Events are
    /// sorted, and the result is the latest one still inside its dwell, so a
    /// fast burst shows the newest combination rather than a queue.
    func activeEventIndex(at time: Double) -> Int? {
        guard !events.isEmpty, time.isFinite else { return nil }
        var low = 0
        var high = events.count - 1
        var candidate: Int?
        while low <= high {
            let middle = (low + high) / 2
            if events[middle].time <= time {
                candidate = middle
                low = middle + 1
            } else {
                high = middle - 1
            }
        }
        guard let candidate else { return nil }
        return time < events[candidate].time + style.dwell ? candidate : nil
    }

    func activeEvent(at time: Double) -> RecorderKeystrokeEvent? {
        activeEventIndex(at: time).map { events[$0] }
    }
}

/// Turns a key press into the key caps a person reads.
///
/// The modifiers are the order macOS itself prints: Control, Option, Shift,
/// Command. The key label comes from the keyboard layout for ordinary keys,
/// so a binder that types ";" shows ";" rather than a key code, while the
/// named keys take the same symbols the rest of the system uses.
enum RecorderKeystrokeLabel {

    static func modifiers(_ flags: CGEventFlags) -> [String] {
        var keys: [String] = []
        if flags.contains(.maskControl) { keys.append("⌃") }
        if flags.contains(.maskAlternate) { keys.append("⌥") }
        if flags.contains(.maskShift) { keys.append("⇧") }
        if flags.contains(.maskCommand) { keys.append("⌘") }
        return keys
    }

    /// The key alone, without its modifiers. Nil for a press that is only a
    /// modifier or that carries nothing printable.
    static func key(keyCode: Int64, characters: String?) -> String? {
        switch Int(keyCode) {
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Space: return "Space"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Escape: return "⎋"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Home: return "↖"
        case kVK_End: return "↘"
        case kVK_PageUp: return "⇞"
        case kVK_PageDown: return "⇟"
        case kVK_Help: return "?"
        case kVK_ANSI_KeypadEnter: return "⌤"
        case kVK_ANSI_KeypadClear: return "⌧"
        case kVK_ANSI_KeypadPlus: return "+"
        case kVK_ANSI_KeypadMinus: return "−"
        case kVK_ANSI_KeypadMultiply: return "×"
        case kVK_ANSI_KeypadDivide: return "÷"
        case kVK_ANSI_KeypadDecimal: return "."
        case kVK_ANSI_KeypadEquals: return "="
        case kVK_ANSI_Keypad0: return "0"
        case kVK_ANSI_Keypad1: return "1"
        case kVK_ANSI_Keypad2: return "2"
        case kVK_ANSI_Keypad3: return "3"
        case kVK_ANSI_Keypad4: return "4"
        case kVK_ANSI_Keypad5: return "5"
        case kVK_ANSI_Keypad6: return "6"
        case kVK_ANSI_Keypad7: return "7"
        case kVK_ANSI_Keypad8: return "8"
        case kVK_ANSI_Keypad9: return "9"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
        case kVK_VolumeUp: return "Volume Up"
        case kVK_VolumeDown: return "Volume Down"
        case kVK_Mute: return "Mute"
        // The modifier keys themselves, and Caps Lock and Fn, carry no
        // combination worth drawing: their state already shows in the other
        // caps, or in nothing at all.
        case kVK_Command, kVK_Shift, kVK_Option, kVK_Control,
             kVK_RightCommand, kVK_RightShift, kVK_RightOption, kVK_RightControl,
             kVK_CapsLock, kVK_Function:
            return nil
        default:
            break
        }
        // Every other key uses the layout's own character. The translation
        // asks for the unmodified character, because Shift has its own cap:
        // ⌘⇧4 reads "4", not "$", and ⌥a reads "A", not "å".
        guard let character = layoutCharacter(for: keyCode) ?? characters else { return nil }
        let trimmed = character
            .replacingOccurrences(of: "\u{7f}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              })
        else { return nil }
        return trimmed.uppercased()
    }

    /// The character a layout prints for a key with no modifiers held, in the
    /// layout the person is actually using.
    private static func layoutCharacter(for keyCode: Int64) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(
                source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = unsafeBitCast(property, to: CFData.self)
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        let layout = unsafeBitCast(bytes, to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 8)
        let status = characters.withUnsafeMutableBufferPointer { buffer -> OSStatus in
            guard let base = buffer.baseAddress else { return -1 }
            return UCKeyTranslate(layout,
                                  UInt16(truncatingIfNeeded: keyCode),
                                  UInt16(kUCKeyActionDisplay),
                                  0,
                                  UInt32(LMGetKbdType()),
                                  OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                  &deadKeyState,
                                  buffer.count,
                                  &length,
                                  base)
        }
        guard status == noErr, length > 0 else { return nil }
        return String(decoding: characters.prefix(length), as: UTF16.self)
    }

    /// The complete row of caps for one fresh press.
    static func keys(keyCode: Int64,
                     flags: CGEventFlags,
                     characters: String?) -> [String]? {
        guard let key = key(keyCode: keyCode, characters: characters) else { return nil }
        let keys = modifiers(flags) + [key]
        return keys.isEmpty ? nil : keys
    }
}

/// Watches the keyboard while a recording runs, only when the person asked
/// for the overlay.
///
/// The tap is listen-only: it never swallows or changes an event. macOS
/// withholds every key from it while Secure Event Input is on, which is
/// exactly the guarantee the overlay needs; the sampler also polls that flag
/// so the overlay is cleared the moment a password field takes it, rather
/// than at the next key press that never arrives.
final class RecorderKeystrokeSampler {
    private let pauseClock: RecorderPauseClock
    private let style: RecorderKeystrokeStyle
    private let lock = NSLock()
    private var events: [RecorderKeystrokeEvent] = []
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var secureTimer: Timer?
    private var isSecure = false
    private var isRunning = false

    /// Called on the main thread for each recorded press, so the live overlay
    /// can show it at the same moment it is added to the track.
    var onKeys: (([String]) -> Void)?
    /// Called when Secure Event Input turns on or off while recording.
    var onSecureInput: ((Bool) -> Void)?

    init(pauseClock: RecorderPauseClock, style: RecorderKeystrokeStyle) {
        self.pauseClock = pauseClock
        self.style = style.sanitized
    }

    /// False when macOS will not give this app the keys: no Input Monitoring
    /// grant, or a tap the system refuses to create. The recording itself
    /// carries on either way.
    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        guard CGPreflightListenEventAccess() else { return false }
        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
        guard let created = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let sampler = Unmanaged<RecorderKeystrokeSampler>
                    .fromOpaque(userInfo).takeUnretainedValue()
                switch type {
                case .tapDisabledByTimeout, .tapDisabledByUserInput:
                    sampler.reenableTap()
                case .keyDown:
                    sampler.handle(event)
                default:
                    break
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        tap = created
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        runLoopSource = source
        // The tap callback runs on the main run loop, where the overlay and
        // the pause clock already live, so no event ever crosses a thread.
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)

        lock.withLock {
            events.removeAll(keepingCapacity: true)
            isRunning = true
        }
        startSecureInputPolling()
        return true
    }

    /// Stops listening and hands over what was collected.
    func stop() -> RecorderKeystrokeTrack {
        lock.withLock { isRunning = false }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            }
            CFMachPortInvalidate(tap)
        }
        tap = nil
        runLoopSource = nil
        secureTimer?.invalidate()
        secureTimer = nil
        publishSecureInput(false)
        return lock.withLock {
            let track = RecorderKeystrokeTrack(style: style, events: events)
            events.removeAll()
            return track.normalized(duration: .greatestFiniteMagnitude)
        }
    }

    private func reenableTap() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func startSecureInputPolling() {
        let timer = Timer(timeInterval: 0.35, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.publishSecureInput(IsSecureEventInputEnabled())
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        secureTimer = timer
    }

    private func publishSecureInput(_ secure: Bool) {
        guard secure != isSecure else { return }
        isSecure = secure
        onSecureInput?(secure)
    }

    private func handle(_ event: CGEvent) {
        guard lock.withLock({ isRunning }) else { return }
        // Secure input hides keys from every tap; asking here as well closes
        // the one frame between the flag turning on and the poll noticing.
        if IsSecureEventInputEnabled() {
            publishSecureInput(true)
            return
        }
        guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let characters = NSEvent(cgEvent: event)?.charactersIgnoringModifiers
        guard let keys = RecorderKeystrokeLabel.keys(keyCode: keyCode,
                                                     flags: event.flags,
                                                     characters: characters),
              let time = pauseClock.eventTime(CACurrentMediaTime())
        else { return }

        lock.withLock {
            guard isRunning else { return }
            // A recording that presses keys for hours must not grow a file
            // without bound. Twenty thousand presses is far beyond a tutorial.
            if events.count < 20_000 {
                events.append(RecorderKeystrokeEvent(time: time, keys: keys))
            }
        }
        onKeys?(keys)
    }

    deinit {
        _ = stop()
    }
}
