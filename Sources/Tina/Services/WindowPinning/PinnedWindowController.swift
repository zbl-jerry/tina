// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import CoreImage
import CoreMedia
import ScreenCaptureKit

/// One pinned window: its floating mirror, its capture stream, and the
/// hand-off state that lets the pointer and keyboard reach the real window.
final class PinnedWindowController {
    let windowID: CGWindowID
    let pid: pid_t
    let title: String
    let appName: String

    private weak var service: WindowPinningService?
    private let panel: WindowPinPanel
    private let capture: WindowPinCapture
    private var sourceFrame: CGRect
    private var sourceSize: CGSize
    private var isUserPaused = false
    private var isVisibilityPaused = false
    private var isHandedOff = false
    private var handedOffAt: TimeInterval = 0
    private var restoreTimer: Timer?
    private var hoverWorkItem: DispatchWorkItem?
    private var restartWorkItem: DispatchWorkItem?
    private var consecutiveFailures = 0

    init(candidate: WindowPinCandidate, service: WindowPinningService) {
        self.windowID = candidate.windowID
        self.pid = candidate.pid
        self.title = candidate.title
        self.appName = candidate.appName
        self.service = service
        self.capture = WindowPinCapture(windowID: candidate.windowID)
        self.sourceFrame = candidate.frame
        self.sourceSize = candidate.frame.size
        panel = WindowPinPanel(candidate: candidate)
        panel.onClick = { [weak self] in self?.handOff() }
        panel.onUnpin = { [weak self] in
            guard let self else { return }
            service.unpin(self.windowID)
        }
        panel.onTogglePause = { [weak self] in self?.toggleUserPause() }
        panel.onHandOff = { [weak self] in self?.handOff() }
        panel.onCloseAll = { [weak self] in
            self?.service?.unpinAll()
        }
        panel.onHoverEnter = { [weak self] in self?.hoverEntered() }
        panel.onHoverExit = { [weak self] in self?.hoverExited() }
        capture.onFrame = { [weak self] image in
            self?.consecutiveFailures = 0
            self?.panel.update(image: image)
        }
        capture.onFailure = { [weak self] in
            self?.captureDidFail()
        }
    }

    var isSummaryPaused: Bool { isUserPaused || isVisibilityPaused }

    func start(cascadeIndex: Int) {
        let screen = NSScreen.screens.first { screen in
            let mainHeight = NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
            let rect = WindowPinningSupport.appKitRect(fromWindowServer: sourceFrame,
                                                       mainScreenHeight: mainHeight)
            return screen.visibleFrame.intersects(rect)
        } ?? NSScreen.main
        let usable = screen?.visibleFrame.size ?? CGSize(width: 1280, height: 800)
        let bodySize = WindowPinningSupport.fittedSize(sourceSize, usableScreen: usable)
        let size = WindowPinningSupport.panelSize(forWidth: bodySize.width, sourceSize: sourceSize)
        let mainHeight = NSScreen.screens.first?.frame.maxY ?? screen?.frame.maxY ?? 0
        let sourceRect = WindowPinningSupport.appKitRect(fromWindowServer: sourceFrame,
                                                         mainScreenHeight: mainHeight)
        let centered = CGPoint(x: sourceRect.midX - size.width / 2,
                               y: sourceRect.midY - size.height / 2)
        let origin = WindowPinningSupport.cascadedOrigin(centered, index: cascadeIndex)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.setSourceSize(sourceSize)
        panel.setPaused(false)
        panel.orderFrontRegardless()
        panel.apply(handoff: service?.handoff ?? .click)
        syncCapture()
    }

    func stop() {
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        restartWorkItem?.cancel()
        restartWorkItem = nil
        restoreTimer?.invalidate()
        restoreTimer = nil
        capture.stop()
        panel.orderOut(nil)
        panel.close()
    }

    func applyPreferences() {
        panel.apply(handoff: service?.handoff ?? .click)
        restartWorkItem?.cancel()
        // A frame-rate slider fires on every step. Rebuilding the stream per
        // step would spend more time starting capture than showing it, so the
        // newest rate is applied once the drag settles.
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.capture.isRunning else { return }
            self.capture.restart(frameRate: self.service?.frameRate
                                    ?? WindowPinningSupport.defaultFrameRate,
                                 pixelSize: self.capturedPixelSize)
        }
        restartWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
        syncCapture()
    }

    /// Called once per service poll. Closes a pin whose window is gone, pauses
    /// capture while the source cannot be seen, and keeps the mirror aspect in
    /// step with a resized window.
    func update(snapshot: WindowServerSnapshot) {
        guard let entry = snapshot.allByID[windowID] else {
            service?.candidateClosed(windowID)
            return
        }
        guard let onScreenIndex = snapshot.orderedOnScreen.firstIndex(where: { $0.windowID == windowID })
        else {
            isVisibilityPaused = true
            syncCapture()
            panel.setPaused(isSummaryPaused)
            service?.notifyPinChanged()
            return
        }
        let live = snapshot.orderedOnScreen[onScreenIndex]
        if live.frame.size != sourceFrame.size {
            sourceFrame = live.frame
            sourceSize = live.frame.size
            panel.setSourceSize(sourceSize)
            if capture.isRunning {
                capture.restart(frameRate: service?.frameRate ?? WindowPinningSupport.defaultFrameRate,
                                pixelSize: capturedPixelSize)
            }
        } else {
            sourceFrame = live.frame
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let covers = snapshot.orderedOnScreen.prefix(onScreenIndex)
            .filter { $0.layer == 0 && $0.alpha > 0.85 && $0.pid != ownPID }
            .map(\.frame)
        let covered = WindowPinningSupport.isFullyCovered(entry.frame, by: covers)
        let pause = WindowPinningSupport.shouldPauseCapture(
            isOnScreen: true,
            isFullyCovered: covered,
            pauseWhenHidden: service?.pausesWhenHidden ?? true)
        let changed = pause != isVisibilityPaused
        isVisibilityPaused = pause
        if changed {
            syncCapture()
            panel.setPaused(isSummaryPaused)
            service?.notifyPinChanged()
        }
    }

    func toggleUserPause() {
        isUserPaused.toggle()
        panel.setPaused(isSummaryPaused)
        syncCapture()
        service?.notifyPinChanged()
    }

    // MARK: Capture

    private var capturedPixelSize: CGSize {
        let scale = NSScreen.screens.first { screen in
            let mainHeight = NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
            let rect = WindowPinningSupport.appKitRect(fromWindowServer: sourceFrame,
                                                       mainScreenHeight: mainHeight)
            return screen.visibleFrame.intersects(rect)
        }?.backingScaleFactor ?? 2
        return WindowPinningSupport.capturePixelSize(for: sourceFrame, scale: scale)
    }

    private func syncCapture() {
        let shouldRun = !isUserPaused && !isVisibilityPaused && !isHandedOff
        if shouldRun, !capture.isRunning {
            capture.start(frameRate: service?.frameRate ?? WindowPinningSupport.defaultFrameRate,
                          pixelSize: capturedPixelSize)
        } else if !shouldRun, capture.isRunning {
            capture.stop()
        }
        panel.setPaused(isSummaryPaused)
    }

    /// A stream can stop on its own when the system drops it, for instance
    /// when another capture starts. One retry after a pause covers that; a
    /// revoked permission or a closed window is handled by the poll, which
    /// stops the retry loop.
    private func captureDidFail() {
        service?.notifyPinChanged()
        guard !isHandedOff, !isUserPaused, !isVisibilityPaused,
              consecutiveFailures < 3 else { return }
        consecutiveFailures += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.syncCapture()
        }
    }

    // MARK: Hand-off

    private func hoverEntered() {
        guard service?.handoff == .hover, !isHandedOff else { return }
        let work = DispatchWorkItem { [weak self] in self?.handOff() }
        hoverWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func hoverExited() {
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
    }

    /// Hands input back to the real window. The mirror disappears, the real
    /// window is raised, and the mirror returns once the pointer leaves that
    /// window again.
    func handOff() {
        guard !isHandedOff else { return }
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        isHandedOff = true
        handedOffAt = ProcessInfo.processInfo.systemUptime
        panel.orderOut(nil)
        capture.stop()
        raiseSourceWindow()
        startRestoreTimer()
    }

    private func raiseSourceWindow() {
        let app = NSRunningApplication(processIdentifier: pid)
        if !(service?.keepsKeyboardFocus ?? true) {
            app?.activate(options: [.activateIgnoringOtherApps])
        }
        guard Permissions.shared.accessibility else { return }
        let axApp = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(axApp, 0.35)
        guard let axWindow = AXWindowResolver.element(for: windowID, in: axApp, pid: pid)
        else {
            app?.activate(options: [.activateIgnoringOtherApps])
            return
        }
        AXUIElementSetMessagingTimeout(axWindow, 0.35)
        AXUIElementSetAttributeValue(axApp, kAXMainWindowAttribute as CFString, axWindow)
        AXUIElementSetAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, axWindow)
        AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(axWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
    }

    private func startRestoreTimer() {
        restoreTimer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkRestore()
        }
        timer.tolerance = 0.03
        RunLoop.main.add(timer, forMode: .common)
        restoreTimer = timer
    }

    private func checkRestore() {
        guard isHandedOff else {
            restoreTimer?.invalidate()
            restoreTimer = nil
            return
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - handedOffAt
        if elapsed > 30 {
            restoreMirror()
            return
        }
        let mainHeight = NSScreen.screens.first?.frame.maxY ?? 0
        guard sourceFrame.width > 0, sourceFrame.height > 0 else {
            if elapsed > 1.5 { restoreMirror() }
            return
        }
        let sourceRect = WindowPinningSupport.appKitRect(fromWindowServer: sourceFrame,
                                                         mainScreenHeight: mainHeight)
        if !sourceRect.insetBy(dx: -20, dy: -20).contains(NSEvent.mouseLocation) {
            restoreMirror()
        }
    }

    private func restoreMirror() {
        restoreTimer?.invalidate()
        restoreTimer = nil
        isHandedOff = false
        panel.orderFrontRegardless()
        syncCapture()
    }
}

// MARK: - Capture

/// One ScreenCaptureKit stream feeding a mirror. Pausing throws the stream
/// away so macOS stops compositing frames entirely; resuming builds a fresh
/// stream against the window's current size and frame rate.
final class WindowPinCapture: NSObject {
    var onFrame: ((CGImage) -> Void)?
    var onFailure: (() -> Void)?

    private let windowID: CGWindowID
    private let queue = DispatchQueue(label: "tina.window-pinning.capture", qos: .userInitiated)
    private let lock = NSLock()
    private var stream: SCStream?
    private var generation = 0
    private var running = false
    private var pendingFrame: CGImage?

    private static let context = CIContext(options: [.cacheIntermediates: false])

    init(windowID: CGWindowID) {
        self.windowID = windowID
        super.init()
    }

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    func start(frameRate: Int, pixelSize: CGSize) {
        let generation: Int
        lock.lock()
        if running {
            lock.unlock()
            return
        }
        self.generation += 1
        generation = self.generation
        running = true
        lock.unlock()
        buildStream(generation: generation, frameRate: frameRate, pixelSize: pixelSize)
    }

    func restart(frameRate: Int, pixelSize: CGSize) {
        stop()
        start(frameRate: frameRate, pixelSize: pixelSize)
    }

    func stop() {
        let oldStream: SCStream?
        lock.lock()
        generation += 1
        running = false
        oldStream = stream
        stream = nil
        lock.unlock()
        if let oldStream {
            Task { try? await oldStream.stopCapture() }
        }
    }

    private func buildStream(generation: Int, frameRate: Int, pixelSize: CGSize) {
        let windowID = windowID
        Task { [weak self] in
            guard let self else { return }
            guard let content = try? await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true),
                let window = content.windows.first(where: { $0.windowID == windowID })
            else {
                self.failed(generation: generation)
                return
            }
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let configuration = SCStreamConfiguration()
            configuration.width = max(1, Int(pixelSize.width))
            configuration.height = max(1, Int(pixelSize.height))
            configuration.minimumFrameInterval = CMTime(
                value: 1, timescale: CMTimeScale(WindowPinningSupport.sanitizedFrameRate(frameRate)))
            configuration.pixelFormat = kCVPixelFormatType_32BGRA
            configuration.colorSpaceName = CGColorSpace.sRGB
            configuration.queueDepth = 3
            configuration.showsCursor = false
            // Output dimensions stay fixed while the panel is alive; the
            // stream is rebuilt on a window resize, so scaling into the
            // current output keeps every frame complete.
            configuration.scalesToFit = true
            configuration.preservesAspectRatio = true
            configuration.captureResolution = .best
            configuration.shouldBeOpaque = true
            configuration.ignoreShadowsDisplay = true
            configuration.ignoreShadowsSingleWindow = true
            let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
            do {
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: self.queue)
                try await stream.startCapture()
            } catch {
                self.failed(generation: generation)
                return
            }
            let accepted = self.lock.withLock { () -> Bool in
                let current = self.running && self.generation == generation
                if current { self.stream = stream }
                return current
            }
            if !accepted {
                try? await stream.stopCapture()
            }
        }
    }

    private func failed(generation: Int) {
        lock.lock()
        let shouldReport = running && self.generation == generation
        if shouldReport { running = false }
        lock.unlock()
        guard shouldReport else { return }
        DispatchQueue.main.async { [weak self] in self?.onFailure?() }
    }

    private func isCurrent(_ stream: SCStream) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return running && self.stream === stream
    }
}

extension WindowPinCapture: SCStreamOutput, SCStreamDelegate {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen, isCurrent(stream), CMSampleBufferIsValid(sampleBuffer),
              Self.carriesPixels(sampleBuffer),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = Self.context.createCGImage(image, from: image.extent) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isCurrent(stream) else { return }
            self.onFrame?(cgImage)
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        lock.lock()
        let shouldReport = running && self.stream === stream
        if shouldReport {
            running = false
            self.stream = nil
        }
        lock.unlock()
        guard shouldReport else { return }
        DispatchQueue.main.async { [weak self] in self?.onFailure?() }
    }

    private static func carriesPixels(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard CMSampleBufferGetImageBuffer(sampleBuffer) != nil else { return false }
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
            let raw = attachments.first?[.status] as? Int,
            let status = SCFrameStatus(rawValue: raw)
        else { return false }
        return status == .complete || status == .started
    }
}

// MARK: - Panel

final class WindowPinPanel: OverlayPanel, NSWindowDelegate {
    private let sourceTitle: String
    private let appName: String
    private let pid: pid_t
    private let content: WindowPinContentView
    private var sourceSize: CGSize

    var onClick: (() -> Void)?
    var onUnpin: (() -> Void)?
    var onTogglePause: (() -> Void)?
    var onHandOff: (() -> Void)?
    var onCloseAll: (() -> Void)?
    var onHoverEnter: (() -> Void)?
    var onHoverExit: (() -> Void)?

    init(candidate: WindowPinCandidate) {
        sourceTitle = candidate.title
        appName = candidate.appName
        pid = candidate.pid
        sourceSize = candidate.frame.size
        content = WindowPinContentView(title: candidate.displayTitle,
                                       appName: candidate.appName,
                                       pid: candidate.pid)
        let initial = NSRect(x: 0, y: 0, width: 420, height: 300)
        super.init(contentRect: initial,
                   styleMask: [.borderless, .nonactivatingPanel, .resizable],
                   backing: .buffered,
                   defer: false)
        isReleasedWhenClosed = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        minSize = NSSize(width: WindowPinningSupport.minimumPanelWidth,
                         height: WindowPinningSupport.minimumPinnableSize.height)
        delegate = self
        contentView = content
        content.onClick = { [weak self] in self?.onClick?() }
        content.onTogglePause = { [weak self] in self?.onTogglePause?() }
        content.onClose = { [weak self] in self?.onUnpin?() }
        content.onHoverEnter = { [weak self] in self?.onHoverEnter?() }
        content.onHoverExit = { [weak self] in self?.onHoverExit?() }
        content.menuProvider = { [weak self] in self?.buildMenu() }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func update(image: CGImage) {
        content.update(image: image)
    }

    func setPaused(_ paused: Bool) {
        content.setPaused(paused)
    }

    func setSourceSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0, size != sourceSize else { return }
        sourceSize = size
        let width = max(WindowPinningSupport.minimumPanelWidth, frame.width)
        let target = WindowPinningSupport.panelSize(forWidth: width, sourceSize: size)
        setFrame(NSRect(origin: frame.origin, size: target), display: true)
    }

    func apply(handoff: WindowPinHandoff) {
        content.handoff = handoff
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        guard sourceSize.width > 0, sourceSize.height > 0 else { return frameSize }
        let width = max(WindowPinningSupport.minimumPanelWidth, frameSize.width)
        return WindowPinningSupport.panelSize(forWidth: width, sourceSize: sourceSize)
    }

    private func buildMenu() -> NSMenu {
        let strings = FeatureStrings.windowPinning(L10n.shared.language)
        let menu = NSMenu()
        func item(_ title: String, _ action: Selector) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        item(strings.useWindow, #selector(menuHandOff))
        item(strings.unpin, #selector(menuUnpin))
        item(strings.pause, #selector(menuTogglePause))
        menu.addItem(.separator())
        item(strings.closeAll, #selector(menuCloseAll))
        return menu
    }

    @objc private func menuHandOff() { onHandOff?() }
    @objc private func menuUnpin() { onUnpin?() }
    @objc private func menuTogglePause() { onTogglePause?() }
    @objc private func menuCloseAll() { onCloseAll?() }
}

/// The mirror's drawing surface: a compact title bar with the source app's
/// icon and title, then the live image. A click on the image hands control
/// back; a drag from anywhere moves the panel.
final class WindowPinContentView: NSView {
    var onClick: (() -> Void)?
    var onTogglePause: (() -> Void)?
    var onClose: (() -> Void)?
    var onHoverEnter: (() -> Void)?
    var onHoverExit: (() -> Void)?
    var menuProvider: (() -> NSMenu?)?
    var handoff: WindowPinHandoff = .click {
        didSet { updateTrackingAreas() }
    }

    private let imageLayer = CALayer()
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let pauseButton = NSButton()
    private let closeButton = NSButton()
    private let statusLabel = NSTextField(labelWithString: "")
    private var paused = false
    private var dragStart: NSPoint?
    private var didDrag = false
    private var tracking: NSTrackingArea?

    init(title: String, appName: String, pid: pid_t) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 1).cgColor
        layer?.cornerRadius = WindowPinningSupport.panelCornerRadius
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.18).cgColor

        imageLayer.contentsGravity = .resizeAspect
        imageLayer.backgroundColor = NSColor.black.cgColor
        imageLayer.masksToBounds = true
        layer?.addSublayer(imageLayer)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image = NSRunningApplication(processIdentifier: pid)?.icon
        addSubview(iconView)

        titleField.stringValue = title
        titleField.font = .systemFont(ofSize: 11, weight: .semibold)
        titleField.textColor = NSColor(calibratedWhite: 0.92, alpha: 1)
        titleField.lineBreakMode = .byTruncatingTail
        titleField.maximumNumberOfLines = 1
        titleField.toolTip = appName
        addSubview(titleField)

        configureButton(pauseButton, symbol: "pause.fill",
                        accessibility: FeatureStrings.windowPinning(L10n.shared.language).pause,
                        action: #selector(togglePause))
        configureButton(closeButton, symbol: "xmark",
                        accessibility: FeatureStrings.windowPinning(L10n.shared.language).close,
                        action: #selector(closePin))
        addSubview(pauseButton)
        addSubview(closeButton)

        statusLabel.stringValue = FeatureStrings.windowPinning(L10n.shared.language).paused
        statusLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        statusLabel.textColor = NSColor(calibratedWhite: 1, alpha: 0.85)
        statusLabel.alignment = .center
        statusLabel.isHidden = true
        addSubview(statusLabel)

        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(title)
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func configureButton(_ button: NSButton, symbol: String,
                                 accessibility: String, action: Selector) {
        button.isBordered = false
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: accessibility)
        button.imagePosition = .imageOnly
        button.contentTintColor = NSColor(calibratedWhite: 0.9, alpha: 0.8)
        button.target = self
        button.action = action
        button.setAccessibilityLabel(accessibility)
    }

    func update(image: CGImage) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.contents = image
        CATransaction.commit()
    }

    func setPaused(_ paused: Bool) {
        guard self.paused != paused else { return }
        self.paused = paused
        statusLabel.isHidden = !paused
        imageLayer.opacity = paused ? 0.42 : 1
        pauseButton.image = NSImage(
            systemSymbolName: paused ? "play.fill" : "pause.fill",
            accessibilityDescription: FeatureStrings.windowPinning(L10n.shared.language)
                .pause)
    }

    override func layout() {
        super.layout()
        let header = WindowPinningSupport.headerHeight
        let body = NSRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - header))
        imageLayer.frame = body
        let midY = bounds.height - header / 2
        iconView.frame = NSRect(x: 10, y: midY - 8, width: 16, height: 16)
        let buttons = CGFloat(20)
        closeButton.frame = NSRect(x: bounds.width - 10 - buttons, y: midY - buttons / 2,
                                   width: buttons, height: buttons)
        pauseButton.frame = NSRect(x: closeButton.frame.minX - 4 - buttons,
                                   y: midY - buttons / 2, width: buttons, height: buttons)
        titleField.frame = NSRect(x: iconView.frame.maxX + 7, y: midY - 8,
                                  width: max(0, pauseButton.frame.minX - iconView.frame.maxX - 14),
                                  height: 16)
        statusLabel.frame = NSRect(x: 0, y: body.midY - 9, width: bounds.width, height: 18)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let header = NSRect(x: 0, y: bounds.height - WindowPinningSupport.headerHeight,
                            width: bounds.width, height: WindowPinningSupport.headerHeight)
        NSColor(calibratedWhite: 0.17, alpha: 1).setFill()
        header.fill()
        NSColor(calibratedWhite: 1, alpha: 0.12).setFill()
        NSRect(x: 0, y: header.minY - 1, width: bounds.width, height: 1).fill()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        guard handoff == .hover else { return }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .activeAlways,
                                            .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverEnter?()
    }

    override func mouseExited(with event: NSEvent) {
        onHoverExit?()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if point.y >= bounds.height - WindowPinningSupport.headerHeight {
            window?.performDrag(with: event)
            return
        }
        dragStart = point
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let point = convert(event.locationInWindow, from: nil)
        if !didDrag, hypot(point.x - start.x, point.y - start.y) > 3 {
            didDrag = true
            window?.performDrag(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragStart = nil
            didDrag = false
        }
        guard !didDrag else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard point.y < bounds.height - WindowPinningSupport.headerHeight else { return }
        if handoff == .hover {
            onHoverExit?()
        }
        onClick?()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        menuProvider?()
    }

    @objc private func togglePause() { onTogglePause?() }
    @objc private func closePin() { onClose?() }
}
