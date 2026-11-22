// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AVFoundation
import CoreGraphics
import CoreImage
import CoreVideo

/// Draws the camera bubble into a screen frame. Called once per delivered
/// screen frame on the writer's serial queue, so the encoder never sees a
/// frame without its bubble and no camera frame can arrive halfway through a
/// write.
final class RecorderCameraCompositor {

    private let context = CIContext(options: [.cacheIntermediates: false])
    /// Sprite caches are shared by the live buffer path and by every frame the
    /// export compositor draws on its own threads.
    private let lock = NSLock()
    private var cachedSide: CGFloat = 0
    private var cachedShape: RecorderCameraShape?
    private var cachedMask: CIImage?
    private var cachedShadow: CIImage?
    private var cachedPad: CGFloat = 0

    /// Returns a new BGRA frame with the bubble drawn on it, or nil when the
    /// frame cannot be composed (the writer then keeps the screen frame).
    func compose(screen: CVImageBuffer,
                 camera: CVImageBuffer,
                 layout: RecorderCameraLayout) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(screen)
        let height = CVPixelBufferGetHeight(screen)
        guard width > 0, height > 0 else { return nil }
        let sourceSize = CGSize(width: width, height: height)
        let rect = layout.rect(in: sourceSize)
        let side = rect.width
        guard side >= 8, side.isFinite else { return nil }

        // Core Image counts up from the bottom of the picture; the layout and
        // the floating bubble count down from the top.
        let target = CGRect(x: rect.minX,
                            y: sourceSize.height - rect.maxY,
                            width: rect.width,
                            height: rect.height)

        guard let overlay = overlay(camera: CIImage(cvPixelBuffer: camera),
                                    side: side,
                                    layout: layout) else { return nil }

        var result = CIImage(cvPixelBuffer: screen)
        result = overlay.image
            .transformed(by: CGAffineTransform(translationX: target.minX - overlay.padding,
                                               y: target.minY - overlay.padding))
            .composited(over: result)

        var output: CVPixelBuffer?
        let attributes: [String: Any] = [kCVPixelBufferIOSurfacePropertiesKey as String: [:]]
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                  kCVPixelFormatType_32BGRA,
                                  attributes as CFDictionary, &output) == kCVReturnSuccess,
              let output else { return nil }
        // The screen buffer carried a color space; the fresh buffer does not.
        // Saying it is sRGB keeps the encoder's BT.709 conversion the same as
        // for an untouched frame.
        if let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) {
            CVBufferSetAttachment(output, kCVImageBufferCGColorSpaceKey,
                                  colorSpace, .shouldPropagate)
        }
        context.render(result,
                       to: output,
                       bounds: CGRect(origin: .zero, size: sourceSize),
                       colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return output
    }

    // MARK: - Overlay

    /// The bubble as a transparent image at the origin, with its shadow. The
    /// caller shifts the whole plate into place, so the same drawing serves
    /// the live frame compositor and the editor's per-frame renderer even
    /// though one writes a pixel buffer and the other returns an image.
    func overlay(camera: CIImage,
                 side: CGFloat,
                 layout: RecorderCameraLayout) -> (image: CIImage, padding: CGFloat)? {
        guard side >= 8, side.isFinite else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard let cameraImage = squareCameraImage(camera, side: side, layout: layout),
              let sprites = sprites(side: side, shape: layout.shape) else { return nil }

        let pad = sprites.pad
        let canvas = CGRect(x: 0, y: 0, width: side + pad * 2, height: side + pad * 2)
        let clear = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0))
            .cropped(to: canvas)
        var plate = clear
        if layout.showsShadow, let shadow = sprites.shadow {
            // The plate's own origin sits one `pad` below and left of the
            // bubble, so the shadow image goes down at the plate's corner and
            // only the small downward offset is added.
            plate = shadow
                .transformed(by: CGAffineTransform(translationX: 0,
                                                   y: -side * 0.035))
                .composited(over: plate)
        }
        // Mask and camera must share the origin for the blend; moving the
        // cutout afterwards is what puts it on the recording.
        let cutout = cameraImage
            .applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: clear,
                kCIInputMaskImageKey: sprites.mask,
            ])
            .transformed(by: CGAffineTransform(translationX: pad, y: pad))
        plate = cutout.composited(over: plate)
        return (plate, pad)
    }

    // MARK: - Camera image

    /// Aspect-fills the camera image into a square of `side`, flipping it when
    /// the mirror is on. The returned image sits at the origin; the caller
    /// moves it into place.
    private func squareCameraImage(_ buffer: CVImageBuffer,
                                   side: CGFloat,
                                   layout: RecorderCameraLayout) -> CIImage? {
        squareCameraImage(CIImage(cvPixelBuffer: buffer), side: side, layout: layout)
    }

    private func squareCameraImage(_ image: CIImage,
                                   side: CGFloat,
                                   layout: RecorderCameraLayout) -> CIImage? {
        var image = image
        let extent = image.extent
        guard extent.width > 0, extent.height > 0,
              extent.width.isFinite, extent.height.isFinite else { return nil }
        // Buffers usually start at the origin, but a device may not. Normalize
        // first so a mirror and a centre crop have known coordinates.
        image = image.transformed(by: CGAffineTransform(translationX: -extent.minX,
                                                        y: -extent.minY))
        if layout.mirrored {
            image = image
                .transformed(by: CGAffineTransform(scaleX: -1, y: 1))
                .transformed(by: CGAffineTransform(translationX: extent.width, y: 0))
        }
        let scale = max(side / extent.width, side / extent.height)
        let scaledWidth = extent.width * scale
        let scaledHeight = extent.height * scale
        return image
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(
                translationX: -(scaledWidth - side) / 2,
                y: -(scaledHeight - side) / 2))
            .cropped(to: CGRect(x: 0, y: 0, width: side, height: side))
    }

    // MARK: - Mask and shadow

    private struct Sprites {
        let mask: CIImage
        let shadow: CIImage?
        /// How far the shadow image extends past the bubble on each side.
        let pad: CGFloat
    }

    /// Masks and shadows cost a Core Graphics pass each, and neither changes
    /// while a person drags or between frames, so they are kept until the size
    /// or shape actually changes.
    private func sprites(side: CGFloat, shape: RecorderCameraShape) -> Sprites? {
        if side == cachedSide, shape == cachedShape,
           let mask = cachedMask, let shadow = cachedShadow {
            return Sprites(mask: mask, shadow: shadow, pad: cachedPad)
        }
        guard let mask = Self.shapeMask(side: side, shape: shape) else { return nil }
        let pad = side * 0.14
        let canvas = side + pad * 2
        let blurred = mask
            .transformed(by: CGAffineTransform(translationX: pad, y: pad))
            .applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: side * 0.07,
            ])
            .cropped(to: CGRect(x: 0, y: 0, width: canvas, height: canvas))
        let ink = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0.42))
            .cropped(to: CGRect(x: 0, y: 0, width: canvas, height: canvas))
        let shadow = ink
            .applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: CIImage(color: CIColor(red: 0, green: 0, blue: 0,
                                                                   alpha: 0))
                    .cropped(to: CGRect(x: 0, y: 0, width: canvas, height: canvas)),
                kCIInputMaskImageKey: blurred,
            ])
            .cropped(to: CGRect(x: 0, y: 0, width: canvas, height: canvas))
        cachedSide = side
        cachedShape = shape
        cachedMask = mask
        cachedShadow = shadow
        cachedPad = pad
        return Sprites(mask: mask, shadow: shadow, pad: pad)
    }

    private static func shapeMask(side: CGFloat,
                                  shape: RecorderCameraShape) -> CIImage? {
        let pixels = max(1, Int(side.rounded(.up)))
        guard let context = CGContext(data: nil,
                                      width: pixels,
                                      height: pixels,
                                      bitsPerComponent: 8,
                                      bytesPerRow: pixels,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)
        let radius = shape == .circle ? side / 2 : side * RecorderCameraLayout.roundedCornerFraction
        context.setFillColor(gray: 1, alpha: 1)
        context.addPath(CGPath(roundedRect: bounds,
                               cornerWidth: radius,
                               cornerHeight: radius,
                               transform: nil))
        context.fillPath()
        guard let image = context.makeImage() else { return nil }
        return CIImage(cgImage: image)
    }
}

/// Replaces a video sample buffer's pixels without touching its timing, so
/// the writer's pause clock, retiming and audio alignment stay exactly as they
/// are for an untouched screen frame.
enum RecorderCameraSample {
    static func composited(_ sampleBuffer: CMSampleBuffer,
                           imageBuffer: CVPixelBuffer) -> CMSampleBuffer? {
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }
        var timing = CMSampleTimingInfo()
        guard CMSampleBufferGetSampleTimingInfo(sampleBuffer, at: 0,
                                                timingInfoOut: &timing) == noErr
        else { return nil }
        var output: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
            formatDescription: format,
            sampleTiming: &timing,
            sampleBufferOut: &output) == noErr
        else { return nil }
        return output
    }
}
