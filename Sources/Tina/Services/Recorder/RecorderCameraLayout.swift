// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// The camera bubble's shape. A circle is the usual presenter look; a rounded
/// square keeps more of a wide camera frame visible.
enum RecorderCameraShape: String, CaseIterable {
    case circle
    case rounded
}

/// Where the camera bubble sits and how big it is. One value is shared by the
/// floating panel, the settings and the frame compositor, so what is dragged
/// on screen is exactly what lands in the recording.
struct RecorderCameraLayout: Equatable {
    /// Centre as a fraction of the recorded picture, left to right and top to
    /// bottom, the direction the screen counts in.
    var centerX: Double
    var centerY: Double
    /// Side as a fraction of the picture's shorter side, so a circle stays a
    /// circle whatever the recording's aspect is.
    var size: Double
    var shape: RecorderCameraShape
    var mirrored: Bool
    var showsShadow: Bool

    static let sizeRange: ClosedRange<Double> = 0.08...0.5
    static let defaultSize = 0.22
    static let defaultCenterX = 0.86
    static let defaultCenterY = 0.82
    static let roundedCornerFraction: CGFloat = 0.18

    init(centerX: Double = RecorderCameraLayout.defaultCenterX,
         centerY: Double = RecorderCameraLayout.defaultCenterY,
         size: Double = RecorderCameraLayout.defaultSize,
         shape: RecorderCameraShape = .circle,
         mirrored: Bool = true,
         showsShadow: Bool = true) {
        self.centerX = centerX
        self.centerY = centerY
        self.size = size
        self.shape = shape
        self.mirrored = mirrored
        self.showsShadow = showsShadow
    }

    /// Finite, in range and inside the picture. A value read from preferences
    /// written by an older or edited build still opens somewhere sensible.
    func sanitized(for source: CGSize = CGSize(width: 1920, height: 1080)) -> RecorderCameraLayout {
        var copy = self
        copy.size = size.isFinite
            ? min(Self.sizeRange.upperBound, max(Self.sizeRange.lowerBound, size))
            : Self.defaultSize
        copy.centerX = centerX.isFinite ? centerX : Self.defaultCenterX
        copy.centerY = centerY.isFinite ? centerY : Self.defaultCenterY
        return copy.fitted(to: source)
    }

    /// The bubble's side in pixels (or points, for the panel) at this picture
    /// size.
    func side(in source: CGSize) -> CGFloat {
        let shorter = min(source.width, source.height)
        guard shorter.isFinite, shorter > 0 else { return 0 }
        let fraction = size.isFinite
            ? min(Self.sizeRange.upperBound, max(Self.sizeRange.lowerBound, size))
            : Self.defaultSize
        return (shorter * CGFloat(fraction)).rounded()
    }

    /// The bubble's centre in the picture's top-left coordinates.
    func center(in source: CGSize) -> CGPoint {
        CGPoint(x: CGFloat(centerX.isFinite ? centerX : 0.5) * source.width,
                y: CGFloat(centerY.isFinite ? centerY : 0.5) * source.height)
    }

    /// The bubble's rectangle in the picture's top-left coordinates. Always
    /// inside the picture: a drag that reaches an edge stops there instead of
    /// letting the video show half a circle.
    func rect(in source: CGSize) -> CGRect {
        let side = self.side(in: source)
        guard side > 0, source.width > 0, source.height > 0 else { return .zero }
        let center = self.center(in: source)
        let x = min(max(0, center.x - side / 2), max(0, source.width - side))
        let y = min(max(0, center.y - side / 2), max(0, source.height - side))
        return CGRect(x: x, y: y, width: side, height: side)
    }

    /// Swaps the centre for one that keeps the whole bubble inside the
    /// picture. `center` is in the picture's top-left coordinates.
    func moved(to center: CGPoint, in source: CGSize) -> RecorderCameraLayout {
        guard source.width > 0, source.height > 0,
              center.x.isFinite, center.y.isFinite else { return self }
        var copy = self
        let side = self.side(in: source)
        let halfX = min(0.5, max(0, side / (2 * source.width)))
        let halfY = min(0.5, max(0, side / (2 * source.height)))
        copy.centerX = clamped(Double(center.x / source.width), halfX, 1 - halfX)
        copy.centerY = clamped(Double(center.y / source.height), halfY, 1 - halfY)
        return copy
    }

    /// A new size, clamped to the range the picture can hold, around the same
    /// centre.
    func resized(to newSize: Double, in source: CGSize) -> RecorderCameraLayout {
        guard newSize.isFinite else { return self }
        var copy = self
        copy.size = min(Self.sizeRange.upperBound, max(Self.sizeRange.lowerBound, newSize))
        return copy.fitted(to: source)
    }

    /// The same layout with its centre pulled inside the picture for the
    /// current size.
    func fitted(to source: CGSize) -> RecorderCameraLayout {
        guard source.width > 0, source.height > 0 else { return self }
        return moved(to: center(in: source), in: source)
    }

    func cornerRadius(in side: CGFloat) -> CGFloat {
        guard side > 0 else { return 0 }
        switch shape {
        case .circle: return side / 2
        case .rounded: return side * Self.roundedCornerFraction
        }
    }

    private func clamped(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        guard lower <= upper else { return (lower + upper) / 2 }
        return min(upper, max(lower, value))
    }
}

/// The live layout, readable from the writer queue while the bubble may be
/// dragged on the main thread.
final class RecorderCameraLayoutBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: RecorderCameraLayout

    init(_ layout: RecorderCameraLayout) {
        stored = layout
    }

    var layout: RecorderCameraLayout {
        get {
            lock.lock()
            defer { lock.unlock() }
            return stored
        }
        set {
            lock.lock()
            stored = newValue
            lock.unlock()
        }
    }
}
