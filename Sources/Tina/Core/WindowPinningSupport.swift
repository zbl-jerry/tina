// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreGraphics

/// What a click (or the pointer resting) on a pinned mirror does. The mirror
/// is never the window: it hands control back to the real one and hides until
/// the pointer leaves that window again.
enum WindowPinHandoff: String, CaseIterable {
    case click
    case hover

    static func sanitized(_ raw: String?) -> WindowPinHandoff {
        guard let raw, let value = WindowPinHandoff(rawValue: raw) else { return .click }
        return value
    }
}

/// One window the picker offers. Bounds are WindowServer bounds: the global
/// coordinate space with its origin at the top left of the main display.
struct WindowPinCandidate: Identifiable, Equatable {
    let windowID: CGWindowID
    let pid: pid_t
    let appName: String
    let title: String
    let bundleIdentifier: String?
    let frame: CGRect

    var id: CGWindowID { windowID }

    var displayTitle: String {
        title.isEmpty ? appName : title
    }
}

/// One window as the WindowServer lists it, ordered front to back like the
/// list it comes from.
struct WindowServerWindowEntry: Equatable {
    let windowID: CGWindowID
    let pid: pid_t
    let layer: Int
    let alpha: Double
    let isOnScreen: Bool
    let frame: CGRect
}

/// Pure decisions for window pinning: which windows may be pinned, how large a
/// mirror starts, when capture can pause, and how a mirror frame maps back to
/// the screen. Everything here is testable without a screen or a permission.
enum WindowPinningSupport {
    static let defaultFrameRate = 30
    static let frameRateRange = 1...60
    /// A window smaller than this is a tooltip or a status item, not something
    /// people mean to keep in front.
    static let minimumPinnableSize = CGSize(width: 120, height: 80)
    /// Mirrors start at most this share of the usable screen.
    static let initialScreenShare: CGFloat = 0.55
    static let minimumPanelWidth: CGFloat = 160
    static let headerHeight: CGFloat = 28
    static let panelCornerRadius: CGFloat = 12
    /// Windows with these owners are chrome of the system, never content.
    static let excludedOwnerNames: Set<String> = [
        "Window Server", "Dock", "Control Center", "Notification Center",
        "SystemUIServer", "Spotlight", "TextInputMenuAgent",
    ]

    static func sanitizedFrameRate(_ value: Int) -> Int {
        min(max(value, frameRateRange.lowerBound), frameRateRange.upperBound)
    }

    /// A normal, opaque, reasonably sized application window. Layer 0 keeps
    /// panels, menus, the Dock and status items out; alpha keeps hidden or
    /// fully transparent windows out.
    static func isPinnable(pid: pid_t, layer: Int, alpha: Double, frame: CGRect,
                           ownerName: String, ownPID: pid_t = ProcessInfo.processInfo.processIdentifier,
                           activationPolicy: NSApplication.ActivationPolicy? = nil) -> Bool {
        guard pid > 0, pid != ownPID, layer == 0, alpha > 0.05,
              frame.width >= minimumPinnableSize.width,
              frame.height >= minimumPinnableSize.height,
              !excludedOwnerNames.contains(ownerName)
        else { return false }
        if let activationPolicy, activationPolicy != .regular {
            return false
        }
        return true
    }

    /// The size a mirror starts at: the source window scaled down until both
    /// sides fit the allowed share of the usable screen.
    static func fittedSize(_ source: CGSize, usableScreen: CGSize,
                           share: CGFloat = initialScreenShare) -> CGSize {
        guard source.width > 0, source.height > 0,
              usableScreen.width > 0, usableScreen.height > 0 else {
            return CGSize(width: minimumPanelWidth, height: minimumPanelWidth)
        }
        let cap = CGSize(width: usableScreen.width * share,
                         height: usableScreen.height * share)
        let scale = min(1, cap.width / source.width, cap.height / source.height)
        return CGSize(width: max(minimumPanelWidth, (source.width * scale).rounded()),
                      height: max(minimumPinnableSize.height, (source.height * scale).rounded()))
    }

    /// Consecutive mirrors cascade instead of stacking invisibly.
    static func cascadedOrigin(_ origin: CGPoint, index: Int,
                               step: CGFloat = 26) -> CGPoint {
        let offset = CGFloat(max(0, index) % 5) * step
        return CGPoint(x: origin.x + offset, y: origin.y - offset)
    }

    /// WindowServer bounds are top-left based; AppKit screen bounds are
    /// bottom-left based with the main display at (0, 0).
    static func appKitRect(fromWindowServer rect: CGRect, mainScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX,
               y: mainScreenHeight - rect.maxY,
               width: rect.width,
               height: rect.height)
    }

    /// Whether `covers` hides every point of `frame`. Windows above the source
    /// are fed in front-to-back order; each one removes its overlap from the
    /// still-visible pieces.
    static func isFullyCovered(_ frame: CGRect, by covers: [CGRect],
                               tolerance: CGFloat = 1) -> Bool {
        guard !frame.isEmpty else { return false }
        var remaining = [frame]
        for cover in covers where !cover.isEmpty {
            var next: [CGRect] = []
            for piece in remaining {
                guard piece.intersects(cover) else {
                    next.append(piece)
                    continue
                }
                next.append(contentsOf: subtract(cover, from: piece))
            }
            remaining = next
            if remaining.isEmpty { return true }
        }
        return remaining.allSatisfy { $0.width <= tolerance || $0.height <= tolerance }
    }

    /// Rectangle difference: the parts of `rect` not covered by `hole`.
    private static func subtract(_ hole: CGRect, from rect: CGRect) -> [CGRect] {
        let overlap = rect.intersection(hole)
        guard !overlap.isNull, !overlap.isEmpty else { return [rect] }
        var pieces: [CGRect] = []
        if overlap.minY > rect.minY {
            pieces.append(CGRect(x: rect.minX, y: rect.minY,
                                 width: rect.width, height: overlap.minY - rect.minY))
        }
        if overlap.maxY < rect.maxY {
            pieces.append(CGRect(x: rect.minX, y: overlap.maxY,
                                 width: rect.width, height: rect.maxY - overlap.maxY))
        }
        if overlap.minX > rect.minX {
            pieces.append(CGRect(x: rect.minX, y: overlap.minY,
                                 width: overlap.minX - rect.minX, height: overlap.height))
        }
        if overlap.maxX < rect.maxX {
            pieces.append(CGRect(x: overlap.maxX, y: overlap.minY,
                                 width: rect.maxX - overlap.maxX, height: overlap.height))
        }
        return pieces.filter { $0.width > 0.5 && $0.height > 0.5 }
    }

    /// Capture dimensions in pixels. A window on a Retina screen is captured
    /// at its backing scale, capped so a huge window cannot allocate an
    /// unreasonable buffer.
    static func capturePixelSize(for frame: CGRect, scale: CGFloat,
                                 maximumDimension: CGFloat = 4096) -> CGSize {
        let factor = min(max(scale, 1), 2)
        let width = min(max(1, (frame.width * factor).rounded()), maximumDimension)
        let height = min(max(1, (frame.height * factor).rounded()), maximumDimension)
        return CGSize(width: width, height: height)
    }

    /// Mirrors only pause for reasons that mean nobody can see the source.
    static func shouldPauseCapture(isOnScreen: Bool, isFullyCovered: Bool,
                                   pauseWhenHidden: Bool) -> Bool {
        guard pauseWhenHidden else { return false }
        return !isOnScreen || isFullyCovered
    }

    /// The body height a panel width implies, keeping the source aspect. The
    /// header sits above the mirrored body and is not part of the aspect.
    static func panelHeight(forWidth width: CGFloat, sourceAspect: CGFloat) -> CGFloat {
        let body = max(1, width) / max(0.05, sourceAspect)
        return (body + headerHeight).rounded()
    }

    /// Largest whole window size that keeps the source aspect at `width`.
    static func panelSize(forWidth width: CGFloat, sourceSize: CGSize) -> CGSize {
        let aspect = max(0.05, sourceSize.width / max(1, sourceSize.height))
        return CGSize(width: max(minimumPanelWidth, width),
                      height: panelHeight(forWidth: max(minimumPanelWidth, width),
                                          sourceAspect: aspect))
    }
}
