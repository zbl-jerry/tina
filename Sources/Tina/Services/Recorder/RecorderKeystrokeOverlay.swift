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
    /// The recorded area in Cocoa points. Corners mean the corners of what is
    /// being recorded, not of the whole display, so a window recording shows
    /// its row inside the window.
    private var anchor = CGRect.zero
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
    func prepare(on screen: NSScreen?,
                 region: RecorderSupport.Region,
                 style: RecorderKeystrokeStyle) {
        guard panel == nil else { return }
        let host = screen ?? NSScreen.main ?? NSScreen.screens.first
        self.anchor = region.anchorRect.width > 0 && region.anchorRect.height > 0
            ? region.anchorRect
            : host?.visibleFrame ?? .zero
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
              let panel, let row else { return }
        hideWork?.cancel()

        row.keys = keys
        row.capHeight = capHeight(for: anchor)
        let size = row.measuredSize
        panel.setContentSize(size)
        row.frame = CGRect(origin: .zero, size: size)
        panel.setFrameOrigin(RecorderKeystrokeOverlayGeometry.origin(
            for: size,
            placement: style.placement,
            anchor: anchor,
            pointer: NSEvent.mouseLocation))
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

    private func capHeight(for anchor: CGRect) -> CGFloat {
        // Relative to the recorded area, not the display, so the live row is
        // the size the composer will draw at the same setting.
        max(10, anchor.height * style.size.fraction)
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
