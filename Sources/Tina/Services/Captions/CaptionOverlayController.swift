// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The floating caption bar. It floats above ordinary windows on every Space,
/// follows the display under the pointer when listening starts, and stays out
/// of the way: only the 22-point grab strip at its top receives clicks, so
/// everything else passes through to the app behind it.
final class CaptionOverlayController {
    private var panel: CaptionBarPanel?
    private var moveObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var defaultsObserver: NSObjectProtocol?
    private var interactionTimer: Timer?
    private var hideWork: DispatchWorkItem?
    private var isPositioning = false
    private var lastFontSize = 0.0
    private var lastMaxLines = 0

    // MARK: - Lifecycle

    func show(service: CaptionService) {
        let panel = self.panel ?? makePanel(service: service)
        self.panel = panel
        let defaults = UserDefaults.standard
        lastFontSize = CaptionSupport.sanitizedFontSize(
            defaults.double(forKey: DefaultsKey.captionsFontSize))
        lastMaxLines = CaptionSupport.sanitizedMaxLines(
            defaults.integer(forKey: DefaultsKey.captionsMaxLines))
        installObservers()
        place(panel, on: pointerScreen(), restoringSavedPosition: true)
        hideWork?.cancel()
        hideWork = nil
        // Click-through is the default; the grab strip is the one region the
        // pointer poll below hands to the window.
        panel.ignoresMouseEvents = true
        if panel.alphaValue < 1 {
            panel.alphaValue = 0
            panel.animator().alphaValue = 1
        }
        panel.orderFrontRegardless()
        startInteractionPolling()
    }

    /// Fades the bar while the Mac stays quiet. The panel remains ordered so
    /// new speech brings it back instantly.
    func setActive(_ active: Bool) {
        guard let panel else { return }
        if active {
            hideWork?.cancel()
            hideWork = nil
            if panel.alphaValue < 1 {
                panel.animator().alphaValue = 1
            }
            if !panel.isVisible { panel.orderFrontRegardless() }
        } else {
            panel.ignoresMouseEvents = true
            panel.animator().alphaValue = 0
        }
    }

    func hide() {
        guard let panel else { return }
        stopInteractionPolling()
        panel.ignoresMouseEvents = true
        hideWork?.cancel()
        panel.animator().alphaValue = 0
        let work = DispatchWorkItem { [weak self, weak panel] in
            guard let self, let panel, panel.alphaValue == 0 else { return }
            panel.orderOut(nil)
            self.hideWork = nil
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    func resetPosition() {
        UserDefaults.standard.set(0.5, forKey: DefaultsKey.captionsOverlayX)
        UserDefaults.standard.set(0.08, forKey: DefaultsKey.captionsOverlayY)
        if let panel {
            place(panel, on: panel.screen ?? pointerScreen(), restoringSavedPosition: true)
        }
    }

    // MARK: - Panel

    private func makePanel(service: CaptionService) -> CaptionBarPanel {
        let size = panelSize(on: pointerScreen())
        let panel = CaptionBarPanel(contentRect: NSRect(origin: .zero, size: size),
                                    styleMask: [.borderless, .nonactivatingPanel],
                                    backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let host = CaptionBarHostingView(rootView: CaptionBarView(service: service))
        host.frame = NSRect(origin: .zero, size: size)
        panel.contentView = host
        return panel
    }

    private func panelSize(on screen: NSScreen) -> NSSize {
        let defaults = UserDefaults.standard
        let visible = screen.visibleFrame
        let width = min(760, max(320, visible.width - 80))
        let fontSize = CaptionSupport.sanitizedFontSize(
            defaults.double(forKey: DefaultsKey.captionsFontSize))
        let lines = CaptionSupport.sanitizedMaxLines(
            defaults.integer(forKey: DefaultsKey.captionsMaxLines))
        let textHeight = CGFloat(lines) * CGFloat(fontSize) * 1.32
        let height = 26 + textHeight + 22 + 20
        return NSSize(width: width, height: ceil(height))
    }

    private func place(_ panel: NSPanel, on screen: NSScreen, restoringSavedPosition: Bool) {
        let defaults = UserDefaults.standard
        let visible = screen.visibleFrame
        let size = panelSize(on: screen)
        isPositioning = true
        defer { isPositioning = false }
        var frame = panel.frame
        frame.size = size
        if restoringSavedPosition {
            let savedX = min(1, max(0, defaults.double(forKey: DefaultsKey.captionsOverlayX)))
            let savedY = min(1, max(0, defaults.double(forKey: DefaultsKey.captionsOverlayY)))
            frame.origin.x = visible.minX + CGFloat(savedX) * visible.width - size.width / 2
            frame.origin.y = visible.minY + CGFloat(savedY) * visible.height
        }
        frame.origin.x = min(max(frame.origin.x, visible.minX + 8),
                             max(visible.minX + 8, visible.maxX - size.width - 8))
        frame.origin.y = min(max(frame.origin.y, visible.minY + 8),
                             max(visible.minY + 8, visible.maxY - size.height - 8))
        panel.setFrame(frame, display: false)
    }

    private func pointerScreen() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.main
            ?? NSScreen.screens.first!
    }

    // MARK: - Interaction

    /// A borderless panel cannot both be click-through and hold a drag handle,
    /// so the window ignores the pointer except while it rests on the 22-point
    /// strip at the top. A short poll is cheaper and more predictable than a
    /// global mouse monitor, and only runs while the bar is on screen.
    private func startInteractionPolling() {
        interactionTimer?.invalidate()
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.updateInteraction()
        }
        RunLoop.main.add(timer, forMode: .common)
        interactionTimer = timer
        updateInteraction()
    }

    private func stopInteractionPolling() {
        interactionTimer?.invalidate()
        interactionTimer = nil
    }

    private func updateInteraction() {
        guard let panel, panel.isVisible else {
            panel?.ignoresMouseEvents = true
            return
        }
        guard panel.alphaValue > 0.05 else {
            panel.ignoresMouseEvents = true
            return
        }
        let mouse = NSEvent.mouseLocation
        let strip = NSRect(x: panel.frame.minX,
                           y: panel.frame.maxY - Self.grabStrip,
                           width: panel.frame.width,
                           height: Self.grabStrip)
        let inside = strip.contains(mouse)
        if panel.ignoresMouseEvents == inside {
            panel.ignoresMouseEvents = !inside
        }
    }

    private static let grabStrip: CGFloat = 22

    // MARK: - Observers

    private func installObservers() {
        if moveObserver == nil {
            moveObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification, object: panel, queue: .main
            ) { [weak self, weak panel] _ in
                guard let self, let panel, !self.isPositioning,
                      let visible = (panel.screen ?? NSScreen.main)?.visibleFrame,
                      visible.width > 0, visible.height > 0 else { return }
                let centerX = (panel.frame.midX - visible.minX) / visible.width
                let bottomY = (panel.frame.minY - visible.minY) / visible.height
                UserDefaults.standard.set(min(1, max(0, centerX)),
                                          forKey: DefaultsKey.captionsOverlayX)
                UserDefaults.standard.set(min(1, max(0, bottomY)),
                                          forKey: DefaultsKey.captionsOverlayY)
            }
        }
        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
            ) { [weak self, weak panel] _ in
                guard let self, let panel, panel.isVisible else { return }
                let screen = panel.screen ?? self.pointerScreen()
                self.place(panel, on: screen, restoringSavedPosition: false)
            }
        }
        if defaultsObserver == nil {
            defaultsObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification, object: nil, queue: .main
            ) { [weak self, weak panel] _ in
                guard let self, let panel, panel.isVisible else { return }
                let defaults = UserDefaults.standard
                let size = CaptionSupport.sanitizedFontSize(
                    defaults.double(forKey: DefaultsKey.captionsFontSize))
                let lines = CaptionSupport.sanitizedMaxLines(
                    defaults.integer(forKey: DefaultsKey.captionsMaxLines))
                guard size != self.lastFontSize || lines != self.lastMaxLines else { return }
                self.lastFontSize = size
                self.lastMaxLines = lines
                self.place(panel, on: panel.screen ?? self.pointerScreen(),
                           restoringSavedPosition: false)
            }
        }
    }
}

/// A borderless panel that never becomes the key window: caption text must not
/// take focus from the meeting or video it is captioning.
final class CaptionBarPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func accessibilitySubrole() -> NSAccessibility.Subrole? { .unknown }
}

/// Only the grab strip accepts the pointer. Everywhere else `hitTest` answers
/// nil, which is what makes the bar click-through without turning the whole
/// window into a non-interactive overlay.
final class CaptionBarHostingView: NSHostingView<CaptionBarView> {
    private static let grabStrip: CGFloat = 22

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = superview.map { convert(point, from: $0) } ?? point
        guard local.y >= bounds.height - Self.grabStrip else { return nil }
        return super.hitTest(point)
    }
}

struct CaptionBarView: View {
    @ObservedObject var service: CaptionService
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.captionsFontSize) private var fontSize = 20.0
    @AppStorage(DefaultsKey.captionsMaxLines) private var maxLines = 2

    private var strings: CaptionFeatureStrings {
        FeatureStrings.captions(l10n.language)
    }

    var body: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(Color.white.opacity(0.34))
                .frame(width: 42, height: 4)
                .padding(.top, 4)
                .accessibilityHidden(true)
            if service.liveText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .semibold))
                    Text(strings.listening)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.82))
                .frame(maxHeight: .infinity)
            } else {
                Text(service.liveText)
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(max(1, maxLines))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(service.liveText)
            }
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                )
        )
        .padding(4)
    }
}
