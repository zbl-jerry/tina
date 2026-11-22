// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreGraphics
import Foundation

/// Pure window-pinning decisions: candidate filtering, first-run geometry,
/// occlusion pausing, preference sanitizing and the catalog contract. Nothing
/// here touches a real window or a permission.
enum WindowPinningTests {
    static func run(_ suite: TestSuite) {
        frameRate(suite)
        candidates(suite)
        geometry(suite)
        occlusion(suite)
        pausing(suite)
        preferences(suite)
        strings(suite)
        catalog(suite)
    }

    private static func frameRate(_ suite: TestSuite) {
        suite.expect(WindowPinningSupport.sanitizedFrameRate(0) == 1,
                     "a zero frame rate clamps to the slowest supported rate")
        suite.expect(WindowPinningSupport.sanitizedFrameRate(30) == 30,
                     "a supported frame rate is kept")
        suite.expect(WindowPinningSupport.sanitizedFrameRate(240) == 60,
                     "a too-high frame rate clamps to sixty")
        suite.expect(WindowPinningSupport.frameRateRange == 1...60,
                     "the frame-rate range covers one to sixty")
        suite.expect(WindowPinHandoff.sanitized("hover") == .hover
                && WindowPinHandoff.sanitized("click") == .click
                && WindowPinHandoff.sanitized("elsewhere") == .click
                && WindowPinHandoff.sanitized(nil) == .click,
                     "hand-off modes sanitize to click")
    }

    private static func candidates(_ suite: TestSuite) {
        let frame = CGRect(x: 100, y: 100, width: 800, height: 600)
        suite.expect(WindowPinningSupport.isPinnable(
            pid: 42, layer: 0, alpha: 1, frame: frame,
            ownerName: "Notes", activationPolicy: .regular),
                     "a normal application window is pinnable")
        suite.expect(!WindowPinningSupport.isPinnable(
            pid: 42, layer: 3, alpha: 1, frame: frame, ownerName: "Notes"),
                     "floating panels are not offered")
        suite.expect(!WindowPinningSupport.isPinnable(
            pid: 42, layer: 0, alpha: 0, frame: frame, ownerName: "Notes"),
                     "an invisible window is not offered")
        suite.expect(!WindowPinningSupport.isPinnable(
            pid: 42, layer: 0, alpha: 1,
            frame: CGRect(x: 0, y: 0, width: 40, height: 20), ownerName: "Notes"),
                     "a tooltip-sized window is not offered")
        suite.expect(!WindowPinningSupport.isPinnable(
            pid: 42, layer: 0, alpha: 1, frame: frame, ownerName: "Notes", ownPID: 42),
                     "the app never offers its own windows")
        suite.expect(!WindowPinningSupport.isPinnable(
            pid: 42, layer: 0, alpha: 1, frame: frame, ownerName: "Dock"),
                     "system chrome is not offered")
        suite.expect(!WindowPinningSupport.isPinnable(
            pid: 42, layer: 0, alpha: 1, frame: frame, ownerName: "Helper",
            activationPolicy: .accessory),
                     "background helpers are not offered")
        suite.expect(WindowPinningSupport.isPinnable(
            pid: 42, layer: 0, alpha: 1, frame: frame, ownerName: "Notes",
            activationPolicy: nil),
                     "an unknown activation policy does not disqualify a window")
    }

    private static func geometry(_ suite: TestSuite) {
        let fitted = WindowPinningSupport.fittedSize(CGSize(width: 1600, height: 1000),
                                                     usableScreen: CGSize(width: 1000, height: 1000))
        suite.expectClose(fitted.width, 550, "a mirror fits the allowed screen share")
        suite.expectClose(fitted.height, 343.75, "the mirror keeps the source aspect", tol: 0.5)
        let small = WindowPinningSupport.fittedSize(CGSize(width: 400, height: 300),
                                                    usableScreen: CGSize(width: 1600, height: 1200))
        suite.expect(small == CGSize(width: 400, height: 300),
                     "a small source is mirrored at its own size")
        let tiny = WindowPinningSupport.fittedSize(.zero, usableScreen: .zero)
        suite.expect(tiny.width == WindowPinningSupport.minimumPanelWidth,
                     "a degenerate source falls back to the minimum width")
        let wide = WindowPinningSupport.panelSize(forWidth: 400,
                                                  sourceSize: CGSize(width: 800, height: 400))
        suite.expectClose(wide.height, 200 + WindowPinningSupport.headerHeight,
                          "the header sits above the mirrored body")
        let first = WindowPinningSupport.cascadedOrigin(CGPoint(x: 10, y: 20), index: 0)
        let second = WindowPinningSupport.cascadedOrigin(CGPoint(x: 10, y: 20), index: 1)
        let wrapped = WindowPinningSupport.cascadedOrigin(CGPoint(x: 10, y: 20), index: 5)
        suite.expect(first == CGPoint(x: 10, y: 20)
                && second == CGPoint(x: 36, y: -6)
                && wrapped == first,
                     "mirrors cascade and wrap after five")
        let converted = WindowPinningSupport.appKitRect(
            fromWindowServer: CGRect(x: 100, y: 50, width: 300, height: 200),
            mainScreenHeight: 1000)
        suite.expectClose(converted.minX, 100, "the horizontal origin is unchanged")
        suite.expectClose(converted.minY, 750, "the vertical origin flips for AppKit")
        suite.expectClose(converted.height, 200, "the height is unchanged")
        let pixels = WindowPinningSupport.capturePixelSize(
            for: CGRect(x: 0, y: 0, width: 3000, height: 2000), scale: 3)
        suite.expect(pixels.width <= 4096 && pixels.height <= 4096,
                     "capture dimensions are capped")
        suite.expect(pixels.width == 4096,
                     "a too-wide window is capped at the maximum dimension")
    }

    private static func occlusion(_ suite: TestSuite) {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        suite.expect(WindowPinningSupport.isFullyCovered(frame, by: [frame]),
                     "an identical window covers the source")
        suite.expect(WindowPinningSupport.isFullyCovered(
            frame, by: [CGRect(x: 0, y: 0, width: 100, height: 50),
                        CGRect(x: 0, y: 50, width: 100, height: 50)]),
                     "two halves cover the source")
        suite.expect(!WindowPinningSupport.isFullyCovered(
            frame, by: [CGRect(x: 0, y: 0, width: 100, height: 40)]),
                     "a partial cover leaves the source visible")
        suite.expect(!WindowPinningSupport.isFullyCovered(frame, by: []),
                     "no covers means visible")
        suite.expect(WindowPinningSupport.isFullyCovered(
            frame, by: [CGRect(x: -20, y: -20, width: 200, height: 200)]),
                     "a larger window covers the source")
        suite.expect(WindowPinningSupport.isFullyCovered(
            frame, by: [CGRect(x: 0, y: 0, width: 70, height: 100),
                        CGRect(x: 30, y: 0, width: 70, height: 100)]),
                     "overlapping covers are combined")
        suite.expect(!WindowPinningSupport.isFullyCovered(
            frame, by: [CGRect(x: 0, y: 0, width: 70, height: 100),
                        CGRect(x: 80, y: 0, width: 20, height: 100)]),
                     "a gap between covers keeps the source visible")
    }

    private static func pausing(_ suite: TestSuite) {
        suite.expect(WindowPinningSupport.shouldPauseCapture(
            isOnScreen: false, isFullyCovered: false, pauseWhenHidden: true),
                     "an off-screen source pauses capture")
        suite.expect(WindowPinningSupport.shouldPauseCapture(
            isOnScreen: true, isFullyCovered: true, pauseWhenHidden: true),
                     "a fully covered source pauses capture")
        suite.expect(!WindowPinningSupport.shouldPauseCapture(
            isOnScreen: true, isFullyCovered: false, pauseWhenHidden: true),
                     "a visible source keeps capturing")
        suite.expect(!WindowPinningSupport.shouldPauseCapture(
            isOnScreen: false, isFullyCovered: true, pauseWhenHidden: false),
                     "the pause preference is honored")
    }

    private static func preferences(_ suite: TestSuite) {
        suite.expect(Defaults.registeredDefaults[DefaultsKey.windowPinningEnabled] as? Bool == false,
                     "pinning starts switched off")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.windowPinningFrameRate] as? Int
                        == WindowPinningSupport.defaultFrameRate,
                     "the frame rate default is thirty")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.windowPinningHandoff] as? String
                        == WindowPinHandoff.click.rawValue,
                     "the hand-off default is click")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.windowPinningKeepFocus] as? Bool == true,
                     "raising the real window keeps keyboard focus by default")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.windowPinningPauseWhenHidden] as? Bool == true,
                     "capture pauses while the source is hidden by default")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.panelUtilityWindowPinning] as? Bool == true,
                     "the panel tile shows by default")
    }

    private static func strings(_ suite: TestSuite) {
        let languages = AppLanguage.allCases.map {
            ($0, FeatureStrings.windowPinning($0))
        }
        suite.expect(languages.count == 15, "window pinning is translated into every language")
        for (language, text) in languages {
            let values = Mirror(reflecting: text).children.compactMap { $0.value as? String }
            suite.expect(values.count == 33
                    && values.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                         "window pinning strings are complete (\(language.rawValue))")
            suite.expect(values.allSatisfy { !$0.contains("\u{2014}") },
                         "window pinning strings have no em dash (\(language.rawValue))")
            suite.expect(TestFormat.parse(text.frameRateValue)?.arguments == [1: "d"],
                         "the frame-rate label is a counted format (\(language.rawValue))")
            suite.expect(TestFormat.parse(text.pinnedCount)?.arguments == [1: "d"],
                         "the pinned count is a counted format (\(language.rawValue))")
        }
    }

    private static func catalog(_ suite: TestSuite) {
        let feature = AppFeature.windowPinning
        suite.expect(feature.rawValue == "windowPinning",
                     "the availability key keeps its stable identity")
        suite.expect(feature.group == .windowsDock,
                     "window pinning belongs to Windows and Dock")
        suite.expect(feature.permissions == [.screenRecording, .accessibility],
                     "a mirror needs screen recording and accessibility")
        suite.expect(feature.enabledKeys == [DefaultsKey.windowPinningEnabled],
                     "the pinning switch is the feature's enable key")
        suite.expect(!feature.installedByDefault,
                     "window pinning is installed from the hub, not by update")
        suite.expect(!feature.symbolName.isEmpty && feature.symbolName == "pin",
                     "the hub row has its pin symbol")
        suite.expect(feature.availabilityKey == "featureAvailable.windowPinning",
                     "availability is stored under the catalog's shared prefix")
        suite.expect(feature.settingsDestination == FeatureSettingsDestination(.windowPinning),
                     "the feature opens its own Settings page")
        suite.expect(FeatureVisibilitySupport.features(for: .windowPinning) == [.windowPinning],
                     "the page is gated only by its own feature")
        let active = AppFeature.activeFeatures(
            using: .screenRecording,
            isAvailable: { $0 == .windowPinning },
            boolFor: { $0 == DefaultsKey.windowPinningEnabled },
            stringFor: { _ in nil })
        suite.expect(active == [.windowPinning],
                     "an installed and switched-on feature reports Screen Recording use")
        let off = AppFeature.activeFeatures(
            using: .screenRecording,
            isAvailable: { $0 == .windowPinning },
            boolFor: { _ in false },
            stringFor: { _ in nil })
        suite.expect(off.isEmpty,
                     "a switched-off feature does not demand Screen Recording polling")
    }
}
