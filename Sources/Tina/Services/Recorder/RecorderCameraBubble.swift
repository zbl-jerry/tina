// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation

/// The live camera bubble shown while recording. It is the placement control
/// and the preview at once: drag it to move, scroll over it to resize. It is
/// one of Tina's own panels, excluded from the capture, so the picture shows
/// the composited bubble instead of this window.
final class RecorderCameraBubble {

    private let capture: RecorderCameraCapture
    private let layoutBox: RecorderCameraLayoutBox
    private let region: RecorderSupport.Region
    private var panel: CameraBubblePanel?
    private var bubbleView: CameraBubbleView?
    /// Called after a drag or resize, in addition to saving the preference for
    /// the next recording, so this recording's timeline learns about it too.
    var onCameraLayoutChange: ((RecorderCameraLayout) -> Void)?

    /// The window the capture has to leave out, so the bubble is not recorded
    /// twice: once floating and once baked in.
    var windowNumber: Int? {
        panel?.windowNumber
    }

    init(capture: RecorderCameraCapture,
         layoutBox: RecorderCameraLayoutBox,
         region: RecorderSupport.Region) {
        self.capture = capture
        self.layoutBox = layoutBox
        self.region = region
    }

    func show() {
        guard panel == nil else { return }
        let layout = layoutBox.layout.fitted(to: region.pixelSize)
        layoutBox.layout = layout

        let frame = Self.frame(for: layout, in: region.anchorRect)
        let view = CameraBubbleView(session: capture.previewSession,
                                    layout: layout,
                                    region: region)
        view.onLayoutChange = { [weak self] newLayout in
            guard let self else { return }
            let fitted = newLayout.fitted(to: self.region.pixelSize)
            self.layoutBox.layout = fitted
            RecorderCameraPreference.save(fitted)
            self.panel?.hasShadow = fitted.showsShadow
            self.panel?.invalidateShadow()
            self.onCameraLayoutChange?(fitted)
        }

        let panel = CameraBubblePanel(contentRect: frame,
                                      styleMask: [.borderless, .nonactivatingPanel],
                                      backing: .buffered,
                                      defer: false)
        panel.contentView = view
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = layout.showsShadow
        panel.level = .statusBar
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary,
                                    .stationary, .ignoresCycle]
        panel.orderFrontRegardless()

        self.panel = panel
        bubbleView = view
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        bubbleView = nil
    }

    /// The bubble's window frame in Cocoa global points: the region is in
    /// points and the layout counts from its top-left corner.
    static func frame(for layout: RecorderCameraLayout,
                      in anchor: CGRect) -> CGRect {
        guard anchor.width > 0, anchor.height > 0 else { return .zero }
        let side = max(24, (min(anchor.width, anchor.height) * CGFloat(layout.size)).rounded())
        let centerX = anchor.minX + CGFloat(layout.centerX) * anchor.width
        let centerY = anchor.maxY - CGFloat(layout.centerY) * anchor.height
        return CGRect(x: (centerX - side / 2).rounded(),
                      y: (centerY - side / 2).rounded(),
                      width: side, height: side)
    }
}

/// A borderless panel that never takes the keyboard. Clicking the bubble must
/// not pull focus away from whatever is being demonstrated.
private final class CameraBubblePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Hosts the camera preview layer and turns drag and scroll into a new
/// layout. The panel's frame is the bubble; the view only draws and reports.
private final class CameraBubbleView: NSView {

    var onLayoutChange: ((RecorderCameraLayout) -> Void)?

    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let region: RecorderSupport.Region
    private var bubbleLayout: RecorderCameraLayout
    private var dragOrigin: (mouse: NSPoint, frame: CGRect)?

    init(session: AVCaptureSession,
         layout: RecorderCameraLayout,
         region: RecorderSupport.Region) {
        self.bubbleLayout = layout
        self.region = region
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
        previewLayer.frame = bounds
        applyMask()
        applyMirroring()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
        applyMask()
        applyMirroring()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        previewLayer.frame = bounds
        applyMask()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyMirroring()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    private func applyMask() {
        let side = min(bounds.width, bounds.height)
        layer?.cornerRadius = bubbleLayout.cornerRadius(in: side)
    }

    private func applyMirroring() {
        guard let connection = previewLayer.connection,
              connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = bubbleLayout.mirrored
    }

    // MARK: - Moving

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragOrigin = (NSEvent.mouseLocation, window.frame)
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragOrigin, let window else { return }
        let mouse = NSEvent.mouseLocation
        var origin = CGPoint(x: dragOrigin.frame.origin.x + mouse.x - dragOrigin.mouse.x,
                            y: dragOrigin.frame.origin.y + mouse.y - dragOrigin.mouse.y)
        let anchor = region.anchorRect
        origin.x = min(max(anchor.minX, origin.x), max(anchor.minX, anchor.maxX - window.frame.width))
        origin.y = min(max(anchor.minY, origin.y), max(anchor.minY, anchor.maxY - window.frame.height))
        window.setFrameOrigin(origin)
    }

    override func mouseUp(with event: NSEvent) {
        dragOrigin = nil
        NSCursor.openHand.set()
        guard let window else { return }
        let anchor = region.anchorRect
        let center = CGPoint(x: window.frame.midX - anchor.minX,
                             y: anchor.maxY - window.frame.midY)
        update(bubbleLayout.moved(to: center, in: anchor.size))
    }

    // MARK: - Resizing

    override func scrollWheel(with event: NSEvent) {
        guard let window else { return }
        let step = event.hasPreciseScrollingDeltas
            ? Double(event.scrollingDeltaY) / 700
            : Double(event.scrollingDeltaY) / 24
        guard step.isFinite, step != 0 else { return }
        let anchor = region.anchorRect
        let resized = bubbleLayout.resized(to: bubbleLayout.size + step, in: region.pixelSize)
        let frame = RecorderCameraBubble.frame(for: resized, in: anchor)
        window.setFrame(frame, display: true)
        window.invalidateShadow()
        update(resized)
    }

    private func update(_ newLayout: RecorderCameraLayout) {
        bubbleLayout = newLayout
        applyMask()
        applyMirroring()
        onLayoutChange?(newLayout)
    }
}
