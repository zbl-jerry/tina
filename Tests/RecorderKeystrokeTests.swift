// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// The key overlay's rules that can be checked without a keyboard or a
/// permission: what is stored, which press is on screen, how keys are named,
/// and that the picture pipeline actually draws what the track says.
enum RecorderKeystrokeTests {
    static func run(_ suite: TestSuite) {
        suite.expect(Defaults.registeredDefaults[DefaultsKey.recorderKeystrokesEnabled] as? Bool == false,
                     "the key overlay ships off, like every permission-elevated recorder option")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.recorderKeystrokePlacement] as? String
                        == RecorderKeystrokePlacement.bottomTrailing.rawValue
                     && Defaults.registeredDefaults[DefaultsKey.recorderKeystrokeSize] as? String
                        == RecorderKeystrokeSize.medium.rawValue
                     && Defaults.registeredDefaults[DefaultsKey.recorderKeystrokeTheme] as? String
                        == RecorderKeystrokeTheme.dark.rawValue
                     && Defaults.registeredDefaults[DefaultsKey.recorderKeystrokeDwell] as? Double == 2,
                     "the overlay starts in the bottom right, medium, dark, for two seconds")
        suite.expect(SettingsBackupSupport.exportKeys().isSuperset(
                        of: [DefaultsKey.recorderKeystrokesEnabled,
                             DefaultsKey.recorderKeystrokePlacement,
                             DefaultsKey.recorderKeystrokeSize,
                             DefaultsKey.recorderKeystrokeDwell,
                             DefaultsKey.recorderKeystrokeTheme]),
                     "the overlay choices travel with a settings backup")

        // MARK: Placement

        suite.expect(RecorderKeystrokePlacement.allCases.count == 5
                     && RecorderKeystrokePlacement.topLeading.anchor == .topLeading
                     && RecorderKeystrokePlacement.bottomTrailing.anchor == .bottomTrailing
                     && RecorderKeystrokePlacement.cursor.anchor == nil,
                     "four corners map to caption anchors and the pointer has none")

        // The live row belongs to the recorded area, not the display: a
        // window recording must show its row inside that window.
        let window = CGRect(x: 900, y: 200, width: 500, height: 320)
        let rowSize = CGSize(width: 180, height: 64)
        func inside(_ point: CGPoint) -> Bool {
            point.x >= window.minX && point.x + rowSize.width <= window.maxX
                && point.y >= window.minY && point.y + rowSize.height <= window.maxY
        }
        for placement in RecorderKeystrokePlacement.allCases {
            let point = RecorderKeystrokeOverlayGeometry.origin(
                for: rowSize, placement: placement, anchor: window,
                pointer: CGPoint(x: 5_000, y: 5_000))
            suite.expect(inside(point),
                         "\(placement.rawValue) keeps the live row inside a window recording")
        }
        let nearBottomLeft = RecorderKeystrokeOverlayGeometry.origin(
            for: rowSize, placement: .bottomLeading, anchor: window,
            pointer: .zero)
        suite.expect(nearBottomLeft.x < window.midX && nearBottomLeft.y < window.midY,
                     "bottom leading means the recorded area's bottom left, not the display's")
        let followingPointer = RecorderKeystrokeOverlayGeometry.origin(
            for: rowSize, placement: .cursor, anchor: window,
            pointer: CGPoint(x: window.midX, y: window.midY))
        suite.expect(inside(followingPointer)
                     && followingPointer.x > window.midX && followingPointer.y > window.midY,
                     "a pointer-following row is placed beside the pointer and kept inside the recording")
        let tinyRegion = CGRect(x: 10, y: 10, width: 40, height: 30)
        let tinyOrigin = RecorderKeystrokeOverlayGeometry.origin(
            for: rowSize, placement: .bottomTrailing, anchor: tinyRegion, pointer: .zero)
        suite.expect(tinyOrigin.x >= tinyRegion.minX && tinyOrigin.y >= tinyRegion.minY,
                     "a row larger than its recording still starts inside the area")

        // MARK: Style

        var style = RecorderKeystrokeStyle()
        style.dwell = .nan
        suite.expect(style.sanitized.dwell == 2,
                     "a broken dwell falls back to two seconds")
        style.dwell = 100
        suite.expect(style.sanitized.dwell == RecorderKeystrokeStyle.dwellRange.upperBound,
                     "a dwell beyond the range is clamped")
        style.dwell = -3
        suite.expect(style.sanitized.dwell == RecorderKeystrokeStyle.dwellRange.lowerBound,
                     "a negative dwell is clamped")
        suite.expect(RecorderKeystrokeSize.small.fraction < RecorderKeystrokeSize.medium.fraction
                     && RecorderKeystrokeSize.medium.fraction < RecorderKeystrokeSize.large.fraction,
                     "the three sizes grow in order")

        // MARK: Track

        let track = RecorderKeystrokeTrack(events: [
            RecorderKeystrokeEvent(time: 2, keys: ["⌘", "C"]),
            RecorderKeystrokeEvent(time: 0.5, keys: ["⇥"]),
            RecorderKeystrokeEvent(time: 1, keys: []),
            RecorderKeystrokeEvent(time: .infinity, keys: ["X"]),
            RecorderKeystrokeEvent(time: 0.75, keys: ["⌃", "⌥", "⇧", "⌘", "4", "extra", "too", "many"]),
        ]).normalized(duration: 3)
        suite.expect(track.events.count == 3
                     && track.events[0].time == 0.5
                     && track.events[1].time == 0.75
                     && track.events[2].time == 2,
                     "a track sorts its presses, drops empty and non-finite ones and keeps the recording's range")
        let trimmed = RecorderKeystrokeTrack(events: [
            RecorderKeystrokeEvent(time: 0.75, keys: ["⌃", "⌥", "⇧", "⌘", "4", "extra", "too", "many"]),
        ]).normalized(duration: 3)
        suite.expect(trimmed.events.first?.keys.count == RecorderKeystrokeEvent.maximumKeys
                     && trimmed.events.first?.keys.last == "4",
                     "a press keeps only the first five caps")

        suite.expect(track.activeEventIndex(at: 0.4) == nil,
                     "no cap row is on screen before the first press")
        suite.expect(track.activeEventIndex(at: 0.5) == 0
                     && track.activeEventIndex(at: 1.4) == 1,
                     "a press stays for its dwell, and a newer one takes over")
        suite.expect(track.activeEventIndex(at: 2.5) == 2
                     && track.activeEventIndex(at: 4.1) == nil,
                     "the row clears once its dwell has passed")
        let overlapping = RecorderKeystrokeTrack(style: RecorderKeystrokeStyle(dwell: 4),
                                                 events: [
                                                     RecorderKeystrokeEvent(time: 1, keys: ["A"]),
                                                     RecorderKeystrokeEvent(time: 2, keys: ["B"]),
                                                 ])
        suite.expect(overlapping.activeEventIndex(at: 2.5) == 1,
                     "a newer press replaces the older one instead of queueing")

        let encoded = track.encoded()
        let decoded = RecorderKeystrokeTrack.decoded(encoded)
        suite.expect(decoded.events == track.events && decoded.style == track.style,
                     "a track survives its JSON round trip")
        suite.expect(RecorderKeystrokeTrack.decoded(Data("not a track".utf8)).isEmpty,
                     "anything that is not a track decodes as empty rather than failing a recording")

        // MARK: Labels

        let modifiers = RecorderKeystrokeLabel.modifiers(
            [.maskCommand, .maskShift, .maskAlternate, .maskControl])
        suite.expect(modifiers == ["⌃", "⌥", "⇧", "⌘"],
                     "modifiers print in the order macOS uses")
        suite.expect(RecorderKeystrokeLabel.key(keyCode: Int64(kVK_Return), characters: nil) == "↩"
                     && RecorderKeystrokeLabel.key(keyCode: Int64(kVK_Tab), characters: nil) == "⇥"
                     && RecorderKeystrokeLabel.key(keyCode: Int64(kVK_Escape), characters: nil) == "⎋"
                     && RecorderKeystrokeLabel.key(keyCode: Int64(kVK_LeftArrow), characters: nil) == "←"
                     && RecorderKeystrokeLabel.key(keyCode: Int64(kVK_F5), characters: nil) == "F5"
                     && RecorderKeystrokeLabel.key(keyCode: Int64(kVK_ANSI_Keypad9), characters: nil) == "9",
                     "named keys take the symbols the rest of the system uses")
        suite.expect(RecorderKeystrokeLabel.key(keyCode: Int64(kVK_Command), characters: "⌘") == nil
                     && RecorderKeystrokeLabel.key(keyCode: Int64(kVK_CapsLock), characters: nil) == nil,
                     "a modifier on its own is not a row of caps")
        suite.expect(RecorderKeystrokeLabel.keys(keyCode: Int64(kVK_ANSI_4),
                                                 flags: [.maskCommand, .maskShift],
                                                 characters: "$") == ["⇧", "⌘", "4"],
                     "⇧⌘4 shows the digit, not the shifted symbol")

        // MARK: Renderer and plan

        let sprite = RecorderKeystrokeRenderer.image(keys: ["⌘", "⇧", "4"],
                                                     style: RecorderKeystrokeStyle(),
                                                     canvasHeight: 1080)
        suite.expect(sprite != nil && (sprite?.width ?? 0) > 0,
                     "a key row rasterizes for the export")
        let smallSprite = RecorderKeystrokeRenderer.image(
            keys: ["⌘", "⇧", "4"],
            style: RecorderKeystrokeStyle(size: .small),
            canvasHeight: 1080)
        suite.expect((smallSprite?.width ?? 0) < (sprite?.width ?? 0),
                     "a smaller size draws a smaller row")

        let keys = RecorderKeystrokeTrack(events: [
            RecorderKeystrokeEvent(time: 0.5, keys: ["⌘", "4"]),
            RecorderKeystrokeEvent(time: 1.5, keys: ["⇥"]),
        ])
        if let plan = RecorderComposer.makePlan(document: RecorderEditDocument(),
                                                track: RecorderPointerTrack(),
                                                keystrokes: keys,
                                                sourceSize: CGSize(width: 640, height: 400),
                                                frameRate: 30,
                                                duration: 3) {
            let framesWithKeys = plan.keystrokeActive.filter { $0 >= 0 }
            suite.expect(!framesWithKeys.isEmpty,
                         "a recording with presses produces a composition")
            suite.expect(plan.keystrokeSprites.count == keys.events.count,
                         "the plan prepares one raster per press")
            suite.expect(plan.keystrokeOrigins.contains(where: { $0 != .zero }),
                         "the plan places the row")
            suite.expect(plan.keystrokeOpacity.contains(where: { $0 > 0.99 })
                         && plan.keystrokeOpacity.contains(where: { $0 == 0 }),
                         "the row is solid inside its dwell and absent outside it")
        } else {
            suite.expect(false, "a recording with presses should not fall back to the plain path")
        }
    }
}
