// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit

/// Short, non-activating confirmation after a multi-window tiling press. The
/// action itself is visual, so the note only has to say how many windows took
/// the layout and how many refused; it never takes focus or stays long enough
/// to get in the way.
final class WindowTilingHUD {
    static let shared = WindowTilingHUD()

    private static let minimumSize = CGSize(width: 200, height: 44)
    private static let holdTime: TimeInterval = 1.6

    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    private init() {}

    func show(title: String, detail: String, on screen: NSScreen?) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.show(title: title, detail: detail, on: screen)
            }
            return
        }
        let panel = self.panel ?? makePanel()
        self.panel = panel
        guard let content = panel.contentView as? ContentView else { return }

        content.titleLabel.stringValue = title
        content.detailLabel.stringValue = detail
        let size = content.preferredSize
        panel.setContentSize(size)
        position(panel, size: size, on: screen)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        panel.display()

        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak panel] in
            guard let panel else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                panel.animator().alphaValue = 0
            } completionHandler: {
                panel.orderOut(nil)
            }
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.holdTime, execute: work)
    }

    func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: Self.minimumSize),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.contentView = ContentView(frame: CGRect(origin: .zero, size: Self.minimumSize))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary,
                                    .stationary, .ignoresCycle]
        return panel
    }

    private func position(_ panel: NSPanel, size: CGSize, on preferredScreen: NSScreen?) {
        guard let screen = preferredScreen
                ?? NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
                ?? NSScreen.main
                ?? NSScreen.screens.first
        else { return }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(CGPoint(x: (visible.midX - size.width / 2).rounded(),
                                     y: (visible.minY + 24).rounded()))
    }

    private final class ContentView: NSVisualEffectView {
        let titleLabel = NSTextField(labelWithString: "")
        let detailLabel = NSTextField(labelWithString: "")

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            material = .hudWindow
            blendingMode = .behindWindow
            state = .active
            wantsLayer = true
            layer?.cornerRadius = 10
            layer?.masksToBounds = true

            titleLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
            titleLabel.alignment = .center
            detailLabel.font = .systemFont(ofSize: 10.5)
            detailLabel.textColor = .secondaryLabelColor
            detailLabel.alignment = .center
            for label in [titleLabel, detailLabel] {
                label.translatesAutoresizingMaskIntoConstraints = false
                addSubview(label)
            }
            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 9),
                detailLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
                detailLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9),
            ])
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        var preferredSize: CGSize {
            layoutSubtreeIfNeeded()
            let width = max(titleLabel.fittingSize.width, detailLabel.fittingSize.width) + 32
            let height = titleLabel.fittingSize.height + detailLabel.fittingSize.height + 20
            return CGSize(width: max(WindowTilingHUD.minimumSize.width, width.rounded(.up)),
                          height: max(WindowTilingHUD.minimumSize.height, height.rounded(.up)))
        }
    }
}
