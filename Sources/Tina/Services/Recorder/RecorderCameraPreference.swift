// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// Reads and writes the camera bubble's preferences. The layout is stored
/// field by field rather than as JSON so an older build, a hand-edited plist
/// or a missing key all fall back to one sensible value instead of losing the
/// whole setup.
enum RecorderCameraPreference {
    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: DefaultsKey.recorderCameraOverlay)
    }

    static func deviceID(_ defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: DefaultsKey.recorderCameraDevice) ?? ""
    }

    static func layout(_ defaults: UserDefaults = .standard) -> RecorderCameraLayout {
        let shape = (defaults.string(forKey: DefaultsKey.recorderCameraShape))
            .flatMap(RecorderCameraShape.init(rawValue:)) ?? .circle
        let layout = RecorderCameraLayout(
            centerX: double(defaults, DefaultsKey.recorderCameraCenterX,
                            fallback: RecorderCameraLayout.defaultCenterX),
            centerY: double(defaults, DefaultsKey.recorderCameraCenterY,
                            fallback: RecorderCameraLayout.defaultCenterY),
            size: double(defaults, DefaultsKey.recorderCameraSize,
                         fallback: RecorderCameraLayout.defaultSize),
            shape: shape,
            mirrored: bool(defaults, DefaultsKey.recorderCameraMirror, fallback: true),
            showsShadow: bool(defaults, DefaultsKey.recorderCameraShadow, fallback: true))
        return layout.sanitized()
    }

    static func save(_ layout: RecorderCameraLayout, to defaults: UserDefaults = .standard) {
        let clean = layout.sanitized()
        defaults.set(clean.centerX, forKey: DefaultsKey.recorderCameraCenterX)
        defaults.set(clean.centerY, forKey: DefaultsKey.recorderCameraCenterY)
        defaults.set(clean.size, forKey: DefaultsKey.recorderCameraSize)
        defaults.set(clean.shape.rawValue, forKey: DefaultsKey.recorderCameraShape)
        defaults.set(clean.mirrored, forKey: DefaultsKey.recorderCameraMirror)
        defaults.set(clean.showsShadow, forKey: DefaultsKey.recorderCameraShadow)
    }

    private static func double(_ defaults: UserDefaults, _ key: String,
                               fallback: Double) -> Double {
        guard let number = defaults.object(forKey: key) as? NSNumber else { return fallback }
        return number.doubleValue
    }

    private static func bool(_ defaults: UserDefaults, _ key: String,
                             fallback: Bool) -> Bool {
        guard let number = defaults.object(forKey: key) as? NSNumber else { return fallback }
        return number.boolValue
    }
}
