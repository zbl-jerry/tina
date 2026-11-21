// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit

/// The shape of a key row, shared by the live overlay and the pixels that are
/// burned into the file, so what a person sees while recording is the same
/// drawing that lands in the video.
struct RecorderKeystrokeLayout {
    let keys: [String]
    let size: CGSize
    /// One rectangle per key, in the same bottom-left space as the pill.
    let capRects: [CGRect]
    let font: NSFont
    let capRadius: CGFloat
    let pillRadius: CGFloat
    let pillRect: CGRect

    /// `capHeight` is the height of one key cap, which every other distance
    /// is derived from. That keeps the whole row proportional at any size.
    static func make(keys: [String], capHeight: CGFloat) -> RecorderKeystrokeLayout {
        let height = max(12, capHeight)
        let font = NSFont.systemFont(ofSize: max(7, height * 0.5), weight: .semibold)
        let capPadding = height * 0.30
        let gap = height * 0.20
        let padding = height * 0.34

        var widths: [CGFloat] = []
        widths.reserveCapacity(keys.count)
        for key in keys {
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let measured = (key as NSString).size(withAttributes: attributes)
            widths.append(max(height * 0.86, measured.width + capPadding * 2))
        }

        let contentWidth = widths.reduce(0, +)
            + gap * CGFloat(max(0, widths.count - 1))
        let size = CGSize(width: (contentWidth + padding * 2).rounded(.up),
                          height: (height + padding * 2).rounded(.up))
        let pillRect = CGRect(origin: .zero, size: size)

        var rects: [CGRect] = []
        rects.reserveCapacity(keys.count)
        var x = padding
        for width in widths {
            rects.append(CGRect(x: x.rounded(), y: padding.rounded(),
                                width: width.rounded(), height: height))
            x += width + gap
        }

        return RecorderKeystrokeLayout(keys: keys,
                                       size: size,
                                       capRects: rects,
                                       font: font,
                                       capRadius: height * 0.22,
                                       pillRadius: height * 0.30,
                                       pillRect: pillRect)
    }
}

/// The two looks the overlay offers, read from one place so the live pill and
/// the exported one cannot drift apart.
struct RecorderKeystrokePalette {
    let pillFill: CGColor
    let pillStroke: CGColor
    let capFill: CGColor
    let capStroke: CGColor
    let text: NSColor
    let shadow: CGColor

    static func forTheme(_ theme: RecorderKeystrokeTheme) -> RecorderKeystrokePalette {
        switch theme {
        case .dark:
            return RecorderKeystrokePalette(
                pillFill: CGColor(gray: 0.07, alpha: 0.84),
                pillStroke: CGColor(gray: 1, alpha: 0.18),
                capFill: CGColor(gray: 1, alpha: 0.16),
                capStroke: CGColor(gray: 1, alpha: 0.22),
                text: .white,
                shadow: CGColor(gray: 0, alpha: 0.45))
        case .light:
            return RecorderKeystrokePalette(
                pillFill: CGColor(gray: 1, alpha: 0.90),
                pillStroke: CGColor(gray: 0, alpha: 0.14),
                capFill: CGColor(gray: 0, alpha: 0.06),
                capStroke: CGColor(gray: 0, alpha: 0.16),
                text: NSColor(white: 0.12, alpha: 1),
                shadow: CGColor(gray: 0, alpha: 0.35))
        }
    }
}

/// Draws a key row into a rectangle. One function serves the live panel and
/// the offline renderer; only the destination differs.
enum RecorderKeystrokeDrawing {
    static func draw(keys: [String],
                     capHeight: CGFloat,
                     theme: RecorderKeystrokeTheme,
                     in context: CGContext) {
        let layout = RecorderKeystrokeLayout.make(keys: keys, capHeight: capHeight)
        let palette = RecorderKeystrokePalette.forTheme(theme)

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -capHeight * 0.06),
                          blur: capHeight * 0.18,
                          color: palette.shadow)
        context.setFillColor(palette.pillFill)
        context.addPath(CGPath(roundedRect: layout.pillRect,
                               cornerWidth: layout.pillRadius,
                               cornerHeight: layout.pillRadius,
                               transform: nil))
        context.fillPath()
        context.restoreGState()

        context.setStrokeColor(palette.pillStroke)
        context.setLineWidth(max(1, capHeight * 0.02))
        context.addPath(CGPath(roundedRect: layout.pillRect.insetBy(dx: 0.5, dy: 0.5),
                               cornerWidth: layout.pillRadius,
                               cornerHeight: layout.pillRadius,
                               transform: nil))
        context.strokePath()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: layout.font,
            .foregroundColor: palette.text,
        ]
        for (index, rect) in layout.capRects.enumerated() {
            context.setFillColor(palette.capFill)
            context.addPath(CGPath(roundedRect: rect,
                                   cornerWidth: layout.capRadius,
                                   cornerHeight: layout.capRadius,
                                   transform: nil))
            context.fillPath()
            context.setStrokeColor(palette.capStroke)
            context.setLineWidth(max(0.75, capHeight * 0.015))
            context.addPath(CGPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5),
                                   cornerWidth: layout.capRadius,
                                   cornerHeight: layout.capRadius,
                                   transform: nil))
            context.strokePath()

            guard index < layout.keys.count else { continue }
            let string = layout.keys[index] as NSString
            let measured = string.size(withAttributes: attributes)
            let origin = CGPoint(x: rect.midX - measured.width / 2,
                                 y: rect.midY - measured.height / 2)
            string.draw(at: origin, withAttributes: attributes)
        }
    }

    /// The size a row has at a given cap height, without drawing it.
    static func size(keys: [String], capHeight: CGFloat) -> CGSize {
        RecorderKeystrokeLayout.make(keys: keys, capHeight: capHeight).size
    }
}

/// Turns a key row into pixels once. A recording of the same few combinations
/// draws each of them a single time and composites a texture for every frame
/// it is visible, like captions and pictures.
enum RecorderKeystrokeRenderer {

    private static var cache: [String: CGImage] = [:]
    private static let lock = NSLock()

    static func image(keys: [String],
                      style: RecorderKeystrokeStyle,
                      canvasHeight: CGFloat) -> CGImage? {
        guard !keys.isEmpty, canvasHeight.isFinite, canvasHeight > 0 else { return nil }
        let capHeight = max(10, canvasHeight * style.size.fraction)
        let key = "\(keys.joined(separator: "\u{1}"))|\(style.theme.rawValue)|\(Int(capHeight.rounded()))"
        lock.lock()
        if let hit = cache[key] {
            lock.unlock()
            return hit
        }
        lock.unlock()

        let size = RecorderKeystrokeDrawing.size(keys: keys, capHeight: capHeight)
        guard size.width > 0, size.height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil,
                                      width: Int(size.width.rounded(.up)),
                                      height: Int(size.height.rounded(.up)),
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        context.clear(CGRect(origin: .zero, size: size))
        let graphics = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        RecorderKeystrokeDrawing.draw(keys: keys,
                                      capHeight: capHeight,
                                      theme: style.theme,
                                      in: context)
        NSGraphicsContext.restoreGraphicsState()

        guard let image = context.makeImage() else { return nil }
        lock.lock()
        if cache.count > 32 { cache.removeAll() }
        cache[key] = image
        lock.unlock()
        return image
    }

    static func clearCache() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }
}
