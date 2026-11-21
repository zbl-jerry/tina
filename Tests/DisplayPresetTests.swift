// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// The pure half of display presets: identity, validation, mode choice,
/// matching and automatic-rule selection. No CoreGraphics display is touched.
enum DisplayPresetTests {
    static func run(_ suite: TestSuite) {
        identityChecks(suite)
        sanitizationChecks(suite)
        storageChecks(suite)
        modeChoiceChecks(suite)
        matchChecks(suite)
        automaticRuleChecks(suite)
        resolutionComparisonChecks(suite)
    }

    private static func display(fingerprint: String = "1552:41019:0",
                                name: String = "Built-in",
                                builtIn: Bool = true,
                                resolution: DisplayPreset.Resolution? = nil,
                                brightness: Double? = 0.6,
                                volume: Double? = nil,
                                muted: Bool? = nil) -> DisplayPreset.Display {
        DisplayPreset.Display(fingerprint: fingerprint, name: name, isBuiltIn: builtIn,
                              resolution: resolution, brightness: brightness,
                              volume: volume, muted: muted)
    }

    private static func preset(name: String = "Desk",
                               displays: [DisplayPreset.Display]? = nil,
                               main: String? = nil,
                               symbol: String = "display",
                               shortcut: String? = nil,
                               trigger: DisplayPreset.Trigger? = nil) -> DisplayPreset {
        DisplayPreset(id: UUID(), name: name, symbol: symbol,
                      displays: displays ?? [display()],
                      mainDisplayFingerprint: main, shortcut: shortcut, trigger: trigger)
    }

    private static func identityChecks(_ suite: TestSuite) {
        suite.expect(DisplayPresetSupport.isUsable("1552:41019:0"),
                     "an Apple panel identity is usable")
        suite.expect(DisplayPresetSupport.isUsable("4268:1:12345"),
                     "a regular monitor identity is usable")
        suite.expect(DisplayPresetSupport.fingerprint(vendor: 0, model: 0, serial: 0) == nil,
                     "an all-zero fingerprint identifies nothing")
        suite.expect(DisplayPresetSupport.fingerprint(vendor: 1, model: 2, serial: UInt32.max) == nil,
                     "a broadcast serial is not an identity")
        suite.expect(DisplayPresetSupport.fingerprint(vendor: 0x756E_6B6E, model: 1, serial: 2) == nil,
                     "the unknown vendor is not an identity")
        suite.expect(!DisplayPresetSupport.isUsable("a:b:c"),
                     "non-numeric parts are rejected")
        suite.expect(!DisplayPresetSupport.isUsable("1:2"),
                     "a two-part value is not an identity")
        suite.expect(DisplayPresetSupport.sameHardware("4268:1:123", "4268:1:999"),
                     "ports of the same model share hardware")
        suite.expect(!DisplayPresetSupport.sameHardware("4268:1:123", "4268:2:999"),
                     "different models do not share hardware")
        suite.expect(!DisplayPresetSupport.sameHardware(nil, "4268:1:123"),
                     "a missing fingerprint never matches")
    }

    private static func sanitizationChecks(_ suite: TestSuite) {
        suite.expect(DisplayPresetSupport.sanitized(preset(name: "   ")) == nil,
                     "a preset with no name is discarded")
        suite.expect(DisplayPresetSupport.sanitized(preset(displays: [])) == nil,
                     "a preset with no displays is discarded")
        suite.expect(DisplayPresetSupport.sanitized(preset(displays: [display(fingerprint: "0:0:0")])) == nil,
                     "a preset with no identified display is discarded")

        let cleaned = DisplayPresetSupport.sanitized(
            preset(name: "  Desk  ", main: "9:9:9", symbol: "not.a.symbol",
                   shortcut: "not-a-shortcut"))
        suite.expect(cleaned?.name == "Desk", "a name is trimmed")
        suite.expect(cleaned?.symbol == DisplayPresetSupport.defaultSymbol,
                     "an unknown icon falls back to the default")
        suite.expect(cleaned?.shortcut == nil, "an unreadable shortcut is dropped")
        suite.expect(cleaned?.mainDisplayFingerprint == nil,
                     "a main display that is not in the snapshot is dropped")

        let shortcut = DisplayPresetSupport.sanitized(preset(shortcut: "shift+command:27"))
        suite.expect(shortcut?.shortcut == "shift+command:27", "a valid shortcut is kept")

        let clamped = DisplayPresetSupport.sanitized(
            preset(displays: [display(brightness: 2, volume: -1)]))
        suite.expect(clamped?.displays.first?.brightness == 1,
                     "brightness is clamped to the slider range")
        suite.expect(clamped?.displays.first?.volume == 0,
                     "volume is clamped to the slider range")

        let notFinite = DisplayPresetSupport.sanitized(
            preset(displays: [display(brightness: .nan, volume: .infinity)]))
        suite.expect(notFinite?.displays.first?.brightness == nil
                     && notFinite?.displays.first?.volume == nil,
                     "non-finite levels are dropped")

        let badResolution = DisplayPreset.Resolution(width: 0, height: 0,
                                                     pixelWidth: 0, pixelHeight: 0,
                                                     refreshRate: -1)
        let dropped = DisplayPresetSupport.sanitized(
            preset(displays: [display(resolution: badResolution)]))
        suite.expect(dropped?.displays.first?.resolution == nil,
                     "a corrupted resolution drops only that item")
        suite.expect(dropped?.displays.count == 1,
                     "the display entry survives a corrupted resolution")

        let trigger = DisplayPreset.Trigger(fingerprint: "4268:1:123", displayName: "Desk Display",
                                            event: .connected)
        suite.expect(DisplayPresetSupport.sanitized(preset(trigger: trigger))?.trigger == trigger,
                     "a valid automatic rule is kept")
        let badTrigger = DisplayPreset.Trigger(fingerprint: "0:0:0", displayName: "Desk",
                                               event: .connected)
        suite.expect(DisplayPresetSupport.sanitized(preset(trigger: badTrigger))?.trigger == nil,
                     "a rule on an unusable identity is dropped")
    }

    private static func storageChecks(_ suite: TestSuite) {
        suite.expect(DisplayPresetSupport.decode(nil).isEmpty,
                     "no stored data means no presets")
        suite.expect(DisplayPresetSupport.decode(Data([0x00, 0x01])).isEmpty,
                     "unreadable data decodes to no presets")

        let one = preset(name: "Home", displays: [display(volume: 0.4, muted: false)])
        let two = preset(name: "Office", displays: [display(fingerprint: "4268:1:123",
                                                             builtIn: false)])
        let decoded = DisplayPresetSupport.decode(DisplayPresetSupport.encode([one, two]))
        suite.expect(decoded.map(\.name) == ["Home", "Office"],
                     "a round trip keeps the list order")
        suite.expect(decoded.first?.displays.first?.volume == 0.4,
                     "a round trip keeps the saved level")

        var duplicate = preset(name: "Duplicate")
        duplicate.id = one.id
        let deduplicated = DisplayPresetSupport.decode(
            DisplayPresetSupport.encode([one, duplicate]))
        suite.expect(deduplicated.count == 1, "a repeated id is kept once")

        let many = (0..<(DisplayPresetSupport.maximumPresets + 3)).map { index in
            preset(name: "Preset \(index)")
        }
        suite.expect(DisplayPresetSupport.decode(DisplayPresetSupport.encode(many)).count
                     == DisplayPresetSupport.maximumPresets,
                     "the stored list is bounded")
    }

    private static func resolution(_ width: Int, _ height: Int, _ pixelWidth: Int,
                                   _ pixelHeight: Int, _ refresh: Double)
        -> DisplayPreset.Resolution {
        DisplayPreset.Resolution(width: width, height: height,
                                 pixelWidth: pixelWidth, pixelHeight: pixelHeight,
                                 refreshRate: refresh)
    }

    private static func modeChoiceChecks(_ suite: TestSuite) {
        let saved = resolution(1512, 982, 3024, 1964, 60)
        let candidates = [
            resolution(1512, 982, 1512, 982, 60),
            resolution(1512, 982, 3024, 1964, 59.94),
            resolution(1512, 982, 3024, 1964, 60),
        ]
        suite.expect(DisplayPresetSupport.bestModeIndex(for: saved, in: candidates) == 2,
                     "the closest refresh rate wins between identical sizes")
        suite.expect(DisplayPresetSupport.bestModeIndex(for: saved, in: [candidates[0]]) == nil,
                     "a same-size non-Retina mode is not a substitute")

        let refreshless = resolution(1920, 1080, 1920, 1080, 0)
        suite.expect(DisplayPresetSupport.bestModeIndex(
            for: refreshless,
            in: [resolution(1920, 1080, 1920, 1080, 60),
                 resolution(1920, 1080, 1920, 1080, 50)]) == 0,
            "a missing saved refresh rate takes the first size match")

        suite.expect(DisplayPresetSupport.bestModeIndex(
            for: resolution(100, 100, 100, 100, 60), in: []) == nil,
            "no candidates means no match")
        suite.expect(DisplayPresetSupport.bestModeIndex(
            for: resolution(100, 100, 100, 100, 60),
            in: [resolution(200, 200, 200, 200, 60)]) == nil,
            "another size is not a match")
    }

    private static func matchChecks(_ suite: TestSuite) {
        let targets: [(id: CGDirectDisplayID, fingerprint: String?, isBuiltIn: Bool)] = [
            (1, "1552:41019:0", true),
            (2, "4268:1:123", false),
            (3, "4268:1:999", false),
        ]
        var used = Set<CGDirectDisplayID>()
        suite.expect(DisplayPresetSupport.match(display(), among: targets, used: &used) == 1,
                     "the exact fingerprint matches first")
        suite.expect(DisplayPresetSupport.match(
            display(fingerprint: "4268:1:123", builtIn: false), among: targets, used: &used) == 2,
            "an external display matches by identity")
        suite.expect(DisplayPresetSupport.match(
            display(fingerprint: "4268:1:123", builtIn: false), among: targets, used: &used) == 3,
            "the same model with another serial is the next best match")
        suite.expect(DisplayPresetSupport.match(
            display(fingerprint: "1:2:3", builtIn: true), among: targets, used: &used) == nil,
            "a built-in already claimed is not matched twice")

        var builtInUsed = Set<CGDirectDisplayID>()
        suite.expect(DisplayPresetSupport.match(
            display(fingerprint: "1:2:3", builtIn: true), among: targets,
            used: &builtInUsed) == 1,
            "an unknown built-in identity falls back to the only built-in display")
        var none = Set<CGDirectDisplayID>()
        suite.expect(DisplayPresetSupport.match(
            display(fingerprint: "1:2:3", builtIn: false), among: targets, used: &none) == nil,
            "an absent external display does not borrow the built-in one")
    }

    private static func automaticRuleChecks(_ suite: TestSuite) {
        let change = DisplayPresetSupport.changedFingerprints(
            previous: ["a", "b"], current: ["b", "c"])
        suite.expect(change.added == ["c"] && change.removed == ["a"],
                     "a connection is an added identity and a disconnection a removed one")

        let connects = preset(name: "Connect",
                              trigger: .init(fingerprint: "c", displayName: "Desk", event: .connected))
        let disconnects = preset(name: "Disconnect",
                                 trigger: .init(fingerprint: "a", displayName: "Desk", event: .disconnected))
        suite.expect(DisplayPresetSupport.presetToApply([disconnects, connects],
                                                        added: ["c"], removed: [])?.name == "Connect",
                     "a connection applies the preset waiting for it")
        suite.expect(DisplayPresetSupport.presetToApply([disconnects, connects],
                                                        added: [], removed: ["a"])?.name == "Disconnect",
                     "a disconnection applies the preset waiting for it")
        suite.expect(DisplayPresetSupport.presetToApply([connects], added: [], removed: []) == nil,
                     "a change with no matching rule applies nothing")

        let first = preset(name: "First",
                           trigger: .init(fingerprint: "c", displayName: "Desk", event: .connected))
        let second = preset(name: "Second",
                            trigger: .init(fingerprint: "c", displayName: "Desk", event: .connected))
        suite.expect(DisplayPresetSupport.presetToApply([first, second],
                                                        added: ["c"], removed: [])?.name == "First",
                     "the first matching rule in the list wins")
        suite.expect(DisplayPresetSupport.presetToApply([preset()], added: ["c"], removed: []) == nil,
                     "a preset with no rule never applies automatically")
    }

    private static func resolutionComparisonChecks(_ suite: TestSuite) {
        let base = resolution(1512, 982, 3024, 1964, 60)
        suite.expect(DisplayPresetSupport.sameResolution(base,
                                                         resolution(1512, 982, 3024, 1964, 59.94)),
                     "refresh rates within half a hertz are the same mode")
        suite.expect(!DisplayPresetSupport.sameResolution(base,
                                                          resolution(1512, 982, 1512, 982, 60)),
                     "a different backing size is a different mode")
        suite.expect(DisplayPresetSupport.sameResolution(nil, nil),
                     "two displays with no saved resolution match")
        suite.expect(!DisplayPresetSupport.sameResolution(nil, base),
                     "a saved resolution and an absent one differ")
        suite.expect(DisplayPresetSupport.normalizedRefresh(59.94) == 59.94,
                     "a reported refresh rate is kept to two decimals")
        suite.expect(DisplayPresetSupport.normalizedRefresh(0) == 0
                     && DisplayPresetSupport.normalizedRefresh(-1) == 0
                     && DisplayPresetSupport.normalizedRefresh(.nan) == 0,
                     "an unknown refresh rate normalizes to zero")
    }
}
