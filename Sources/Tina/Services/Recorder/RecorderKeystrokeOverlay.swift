// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit

/// The key row shown on screen while recording.
///
/// It is a non-activating panel excluded from Tina's own capture, because the
/// file gets its key row from the composer instead. Drawing it only here
/// would miss window recordings and the parts of the screen the compositor
/// changes; drawing it only there would leave the person recording without
/// the feedback they turned the feature on for. The two share one drawing.
///
/// Nothing exists before a recording and nothing outlives it. Pause and
/// Secure Event Input clear the row immediately rather than waiting for the
/// next press that would never arrive.
final class RecorderKeystrokeOverlay {

    private var panel: NSPanel?
    private var row: KeyRowView?
    private var screen: NSScreen?
    private var style = RecorderKeystrokeStyle()
    private var hideWork: DispatchWorkItem?
    private var isPaused = false
    private var isSecure = false

    /// The window the capture has to leave out, like the recording pill.
    var excludedWindowNumbers: [Int] {
        guard let number = panel?.windowNumber, number > 0 else { return [] }
        return [number]
    }

    /// Creates the panel ahead of the capture so its window number can be
    /// excluded from the first frame. It stays invisible until a key arrives.
    func prepare(on screen: NSScreen?, style: RecorderKeystrokeStyle) {
        guard panel == nil else { return }
        let host = screen ?? NSScreen.main ?? NSScreen.screens.first
        self.screen = host
        self.style = style.sanitized

        let row = KeyRowView()
        row.style = self.style
        let panel = OverlayPanel(contentRect: CGRect(origin: .zero, size: CGSize(width: 1, height: 1)),
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered,
                                 defer: false)
        panel.contentView = row
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary,
                                    .stationary, .ignoresCycle]
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        self.panel = panel
        self.row = row
    }

    /// Shows one combination and starts its dwell over.
    func present(keys: [String]) {
        guard !keys.isEmpty, !isPaused, !isSecure,
              let panel, let row, let screen else { return }
        hideWork?.cancel()

        row.keys = keys
        row.capHeight = capHeight(on: screen)
        let size = row.measuredSize
        panel.setContentSize(size)
        row.frame = CGRect(origin: .zero, size: size)
        panel.setFrameOrigin(origin(for: size, on: screen))
        row.needsDisplay = true

        if panel.alphaValue < 0.01 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.08
                panel.animator().alphaValue = 1
            }
        }

        let work = DispatchWorkItem { [weak self] in self?.clear() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + style.dwell, execute: work)
    }

    /// Empties the row without tearing the panel down, which keeps the window
    /// that the capture excludes stable for the whole recording.
    func clear() {
        hideWork?.cancel()
        hideWork = nil
        guard let panel else { return }
        row?.keys = []
        row?.needsDisplay = true
        if panel.alphaValue > 0.01 {
            panel.alphaValue = 0
        }
    }

    func setPaused(_ paused: Bool) {
        guard paused != isPaused else { return }
        isPaused = paused
        if paused { clear() }
    }

    func setSecureInput(_ secure: Bool) {
        guard secure != isSecure else { return }
        isSecure = secure
        if secure { clear() }
    }

    func hide() {
        clear()
        panel?.orderOut(nil)
        panel = nil
        row = nil
    }

    private func capHeight(on screen: NSScreen) -> CGFloat {
        max(10, screen.frame.height * style.size.fraction)
    }

    private func origin(for size: CGSize, on screen: NSScreen) -> CGPoint {
        let margin: CGFloat = 24
        let frame = screen.visibleFrame
        func clamped(_ point: CGPoint) -> CGPoint {
            CGPoint(x: min(max(frame.minX + 8, point.x), max(frame.minX + 8, frame.maxX - size.width - 8)),
                    y: min(max(frame.minY + 8, point.y), max(frame.minY + 8, frame.maxY - size.height - 8)))
        }

        switch style.placement {
        case .topLeading:
            return CGPoint(x: frame.minX + margin, y: frame.maxY - size.height - margin)
        case .topTrailing:
            return CGPoint(x: frame.maxX - size.width - margin, y: frame.maxY - size.height - margin)
        case .bottomLeading:
            return CGPoint(x: frame.minX + margin, y: frame.minY + margin)
        case .bottomTrailing:
            return CGPoint(x: frame.maxX - size.width - margin, y: frame.minY + margin)
        case .cursor:
            // Beside and above the pointer, so the row never covers the spot
            // being clicked while the combination is being read.
            let location = NSEvent.mouseLocation
            return clamped(CGPoint(x: location.x + 18, y: location.y + 16))
        }
    }

    private final class KeyRowView: NSView {
        var keys: [String] = []
        var capHeight: CGFloat = 32
        var style = RecorderKeystrokeStyle()

        var measuredSize: CGSize {
            RecorderKeystrokeDrawing.size(keys: keys, capHeight: capHeight)
        }

        override var isOpaque: Bool { false }

        override func draw(_ dirtyRect: NSRect) {
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            RecorderKeystrokeDrawing.draw(keys: keys,
                                          capHeight: capHeight,
                                          theme: style.theme,
                                          in: context)
        }
    }
}
