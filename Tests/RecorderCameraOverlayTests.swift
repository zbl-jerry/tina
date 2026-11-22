// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import CoreVideo
import Foundation

enum RecorderCameraOverlayTests {
    static func run(_ suite: TestSuite) {
        let picture = CGSize(width: 1920, height: 1080)

        // MARK: Defaults

        suite.expect(Defaults.registeredDefaults[DefaultsKey.recorderCameraOverlay] as? Bool == false,
               "the camera bubble ships off")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.recorderCameraMirror] as? Bool == true,
               "a mirrored camera is what a mirror and every call show")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.recorderCameraShadow] as? Bool == true,
               "the bubble has a shadow unless it is turned off")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.recorderCameraShape] as? String
                == RecorderCameraShape.circle.rawValue,
               "the bubble ships as a circle")
        let exported = SettingsBackupSupport.exportKeys()
        suite.expect(exported.contains(DefaultsKey.recorderCameraOverlay)
                && exported.contains(DefaultsKey.recorderCameraDevice)
                && exported.contains(DefaultsKey.recorderCameraCenterX)
                && exported.contains(DefaultsKey.recorderCameraShape)
                && exported.contains(DefaultsKey.recorderCameraMirror),
               "the camera bubble settings travel in a settings backup")
        let fallback = RecorderCameraLayout()
        suite.expectClose(fallback.centerX, RecorderCameraLayout.defaultCenterX,
                          "the default bubble sits towards the right")
        suite.expectClose(fallback.centerY, RecorderCameraLayout.defaultCenterY,
                          "the default bubble sits towards the bottom")
        suite.expectClose(fallback.size, RecorderCameraLayout.defaultSize,
                          "the default bubble is a fifth of the short side")

        // MARK: Geometry

        let side = fallback.side(in: picture)
        suite.expect(side == 238, "the side follows the shorter picture side, rounded")
        let rect = fallback.rect(in: picture)
        suite.expect(rect.width == side && rect.height == side,
               "the bubble is square whatever the picture's aspect is")
        suite.expect(rect.minX >= 0 && rect.minY >= 0
                && rect.maxX <= picture.width && rect.maxY <= picture.height,
               "the default bubble is inside the picture")
        suite.expect(rect.midX > picture.width / 2 && rect.midY > picture.height / 2,
               "the default bubble is in the bottom-right corner")
        let tall = CGSize(width: 1080, height: 1920)
        suite.expect(fallback.side(in: tall) == fallback.side(in: picture),
               "the side depends on the shorter side, not the width")
        suite.expect(RecorderCameraLayout(centerX: 0.82, centerY: 0.82)
                .rect(in: CGSize(width: 1080, height: 1920)).maxY <= 1920,
               "a circular bubble fits a vertical recording too")

        // MARK: Clamping

        let draggedToCorner = fallback.moved(to: CGPoint(x: 0, y: 0), in: picture)
        let cornerRect = draggedToCorner.rect(in: picture)
        suite.expect(cornerRect.minX == 0 && cornerRect.minY == 0,
               "a drag to the top-left stops with the whole bubble visible")
        suite.expect(draggedToCorner.centerX < 0.1 && draggedToCorner.centerY < 0.15,
               "the clamped centre is expressed in normalized coordinates")

        let draggedPastEdge = fallback.moved(to: CGPoint(x: 9999, y: 9999), in: picture)
        let edgeRect = draggedPastEdge.rect(in: picture)
        suite.expect(abs(edgeRect.maxX - picture.width) <= 1
                && abs(edgeRect.maxY - picture.height) <= 1,
               "a drag past the bottom-right edge keeps the bubble inside")

        let grown = fallback.resized(to: 0.9, in: picture)
        suite.expectClose(grown.size, RecorderCameraLayout.sizeRange.upperBound,
                          "a resize stops at the largest allowed bubble")
        let shrunk = fallback.resized(to: 0.01, in: picture)
        suite.expectClose(shrunk.size, RecorderCameraLayout.sizeRange.lowerBound,
                          "a resize stops at the smallest allowed bubble")
        let grownRect = grown.rect(in: picture)
        suite.expect(grownRect.minX >= 0 && grownRect.maxX <= picture.width
                && grownRect.minY >= 0 && grownRect.maxY <= picture.height,
               "growing the bubble keeps it inside the picture")

        let broken = RecorderCameraLayout(centerX: .nan, centerY: .infinity,
                                          size: .nan, shape: .rounded,
                                          mirrored: false, showsShadow: false)
        let cleaned = broken.sanitized(for: picture)
        suite.expect(cleaned.centerX.isFinite && cleaned.centerY.isFinite && cleaned.size.isFinite,
               "an edited or older preference still opens with a usable layout")
        suite.expect(cleaned.shape == .rounded && !cleaned.mirrored && !cleaned.showsShadow,
               "sanitizing keeps the choices that are still valid")

        let noPicture = fallback.moved(to: CGPoint(x: 10, y: 10), in: .zero)
        suite.expect(noPicture == fallback, "a zero-sized picture leaves the layout alone")

        // MARK: Shape and live box

        suite.expectClose(fallback.cornerRadius(in: 200), 100,
                          "a circle is masked with half its side")
        let rounded = RecorderCameraLayout(shape: .rounded)
        suite.expectClose(rounded.cornerRadius(in: 200),
                          200 * RecorderCameraLayout.roundedCornerFraction,
                          "a rounded square keeps its corner proportion")
        suite.expect(RecorderCameraLayout(shape: .circle).cornerRadius(in: 0) == 0,
               "a zero-sized bubble has no corner")

        let box = RecorderCameraLayoutBox(fallback)
        box.layout = draggedToCorner
        suite.expect(box.layout == draggedToCorner,
               "the writer sees the layout the bubble was left at")

        // MARK: Placement timeline

        let firstPlacement = RecorderCameraLayout(centerX: 0.2, centerY: 0.3, size: 0.2,
                                                   shape: .rounded, mirrored: false,
                                                   showsShadow: false)
        let laterPlacement = RecorderCameraLayout(centerX: 0.7, centerY: 0.6, size: 0.3)
        let events = RecorderCameraTrack(events: [
            RecorderCameraLayoutEvent(time: 2, layout: laterPlacement),
            RecorderCameraLayoutEvent(time: 0.5, layout: firstPlacement),
            RecorderCameraLayoutEvent(time: -4, layout: firstPlacement),
            RecorderCameraLayoutEvent(time: 99, layout: laterPlacement),
        ]).normalized(duration: 4)
        suite.expect(events.events.map(\.time) == [0, 0.5, 2, 4],
                     "a camera placement timeline is ordered and clamped to the recording")
        let earlyPlacement = events.layout(at: 0.25)
        let latePlacement = events.layout(at: 3.5)
        suite.expect(earlyPlacement?.shape == .rounded
                && earlyPlacement?.mirrored == false
                && earlyPlacement?.showsShadow == false
                && abs((earlyPlacement?.centerX ?? 0) - 0.2) < 0.001
                && abs((latePlacement?.centerX ?? 0) - 0.7) < 0.001,
                     "the latest drag at or before a moment is the one drawn")
        suite.expect(events.layout(at: -1) == nil
                && RecorderCameraTrack().layout(at: 1) == nil,
                     "a time before the first placement, or a take without a camera, draws nothing")
        let restored = RecorderCameraTrack.decoded(events.encoded())
        suite.expect(restored == events,
                     "the placement timeline survives a save and reopen")

        // MARK: Preferences

        let domain = "com.tina.tests.recorder-camera-overlay"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)

        suite.expect(!RecorderCameraPreference.isEnabled(defaults),
               "the camera bubble is off until it is turned on")
        suite.expect(RecorderCameraPreference.deviceID(defaults).isEmpty,
               "no camera is remembered before one is chosen")
        suite.expect(RecorderCameraPreference.layout(defaults).shape == .circle
                && RecorderCameraPreference.layout(defaults).mirrored,
               "a fresh install opens the default circle")

        defaults.set(true, forKey: DefaultsKey.recorderCameraOverlay)
        defaults.set("camera-1", forKey: DefaultsKey.recorderCameraDevice)
        suite.expect(RecorderCameraPreference.isEnabled(defaults),
               "the switch reads back")
        suite.expect(RecorderCameraPreference.deviceID(defaults) == "camera-1",
               "the chosen camera is remembered")

        let saved = RecorderCameraLayout(centerX: 0.3, centerY: 0.4, size: 0.3,
                                          shape: .rounded, mirrored: false,
                                          showsShadow: false)
        RecorderCameraPreference.save(saved, to: defaults)
        let read = RecorderCameraPreference.layout(defaults)
        suite.expectClose(read.centerX, saved.centerX, "the centre travels", tol: 0.0001)
        suite.expectClose(read.centerY, saved.centerY, "the second centre travels", tol: 0.0001)
        suite.expectClose(read.size, saved.size, "the size travels", tol: 0.0001)
        suite.expect(read.shape == .rounded && !read.mirrored && !read.showsShadow,
               "shape, mirror and shadow travel")

        defaults.set("triangle", forKey: DefaultsKey.recorderCameraShape)
        suite.expect(RecorderCameraPreference.layout(defaults).shape == .circle,
               "an unknown shape falls back to the circle")
        defaults.set("not a number", forKey: DefaultsKey.recorderCameraSize)
        suite.expectClose(RecorderCameraPreference.layout(defaults).size,
                          RecorderCameraLayout.defaultSize,
                          "a corrupted size falls back to the default")

        defaults.removePersistentDomain(forName: domain)

        // MARK: Compositing

        // A solid screen and a camera whose halves differ, so placement,
        // shape and mirroring can be read back from the composed pixels
        // without a camera device. Coordinates are top-left, like the screen.
        let screenBlue: (UInt8, UInt8, UInt8, UInt8) = (255, 0, 0, 255)
        if let screen = buffer(width: 320, height: 180, fill: screenBlue),
           let redCamera = buffer(width: 160, height: 160, fill: (0, 0, 255, 255)),
           let halvedCamera = halvedBuffer(width: 160, height: 160,
                                           left: (0, 0, 255, 255),
                                           right: (0, 255, 0, 255)) {
            let compositor = RecorderCameraCompositor()
            let center = RecorderCameraLayout(centerX: 0.5, centerY: 0.5, size: 0.5,
                                               shape: .circle, mirrored: false,
                                               showsShadow: false)
            if let composed = compositor.compose(screen: screen, camera: redCamera,
                                                  layout: center) {
                let corner = pixel(composed, x: 20, y: 20)
                let middle = pixel(composed, x: 160, y: 90)
                let insideCorner = pixel(composed, x: 123, y: 53)
                suite.expect(corner.blue > 180 && corner.red < 80 && corner.green < 80,
                       "outside the bubble the screen is untouched")
                suite.expect(middle.red > 180 && middle.blue < 80 && middle.green < 80,
                       "the bubble draws the camera in its square")
                suite.expect(insideCorner.blue > 140 && insideCorner.red < 100,
                       "a circle leaves the square's corner showing the screen")
            } else {
                suite.expect(false, "a composited frame is produced")
            }

            let rounded = RecorderCameraLayout(centerX: 0.5, centerY: 0.5, size: 0.5,
                                                shape: .rounded, mirrored: false,
                                                showsShadow: false)
            if let composed = compositor.compose(screen: screen, camera: redCamera,
                                                  layout: rounded) {
                let insideCorner = pixel(composed, x: 123, y: 53)
                suite.expect(insideCorner.red > 140 && insideCorner.blue < 100,
                       "a rounded square keeps more of the camera's corner")
            } else {
                suite.expect(false, "a rounded composite is produced")
            }

            let mirrored = RecorderCameraLayout(centerX: 0.5, centerY: 0.5, size: 0.5,
                                                 shape: .rounded, mirrored: true,
                                                 showsShadow: false)
            if let composed = compositor.compose(screen: screen, camera: halvedCamera,
                                                  layout: mirrored) {
                let left = pixel(composed, x: 126, y: 90)
                suite.expect(left.green > 140 && left.red < 100,
                       "mirroring swaps the camera's halves in the recording")
            } else {
                suite.expect(false, "a mirrored composite is produced")
            }
            let unmirrored = RecorderCameraLayout(centerX: 0.5, centerY: 0.5, size: 0.5,
                                                   shape: .rounded, mirrored: false,
                                                   showsShadow: false)
            if let composed = compositor.compose(screen: screen, camera: halvedCamera,
                                                  layout: unmirrored) {
                let left = pixel(composed, x: 126, y: 90)
                suite.expect(left.red > 140 && left.green < 100,
                       "without mirroring the camera is drawn as captured")
            } else {
                suite.expect(false, "an unmirrored composite is produced")
            }

            // Replacing the pixels must keep the frame's timing exactly: the
            // writer's pause clock and audio alignment read it.
            var format: CMVideoFormatDescription?
            if CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                                              codecType: kCVPixelFormatType_32BGRA,
                                              width: 320, height: 180,
                                              extensions: nil,
                                              formatDescriptionOut: &format) == noErr,
               let format {
                var timing = CMSampleTimingInfo(
                    duration: CMTime(value: 1, timescale: 60),
                    presentationTimeStamp: CMTime(value: 12_345, timescale: 600),
                    decodeTimeStamp: .invalid)
                var original: CMSampleBuffer?
                if CMSampleBufferCreateReadyWithImageBuffer(
                    allocator: kCFAllocatorDefault, imageBuffer: screen,
                    formatDescription: format, sampleTiming: &timing,
                    sampleBufferOut: &original) == noErr,
                   let original,
                   let rebuilt = RecorderCameraSample.composited(original, imageBuffer: screen) {
                    suite.expect(CMSampleBufferGetImageBuffer(rebuilt) != nil,
                           "the rebuilt frame still carries pixels")
                    suite.expect(CMTimeCompare(CMSampleBufferGetPresentationTimeStamp(rebuilt),
                                               timing.presentationTimeStamp) == 0,
                           "the rebuilt frame keeps its presentation time")
                    suite.expect(CMTimeCompare(CMSampleBufferGetDuration(rebuilt),
                                               timing.duration) == 0,
                           "the rebuilt frame keeps its duration")
                } else {
                    suite.expect(false, "a sample buffer is rebuilt around composed pixels")
                }
            } else {
                suite.expect(false, "a BGRA video format is created")
            }

            let tiny = RecorderCameraLayout(centerX: 0.5, centerY: 0.5, size: 0.5)
            if let tinyScreen = buffer(width: 10, height: 10, fill: screenBlue) {
                suite.expect(compositor.compose(screen: tinyScreen, camera: redCamera,
                                                 layout: tiny) == nil,
                       "a picture too small to hold a bubble is left alone")
            } else {
                suite.expect(false, "a tiny screen buffer is created")
            }
        } else {
            suite.expect(false, "synthetic screen and camera buffers are created")
        }

        // MARK: Composer

        // The bubble is a separate picture track now, so the composer has to
        // draw it after the zoom and the card fit. A bottom-right bubble and
        // a zoom aimed at the top-left would lose it if it were still baked
        // into the screen pixels.
        var cameraDocument = RecorderEditDocument()
        cameraDocument.showsPointer = false
        cameraDocument.zoomEnabled = true
        cameraDocument.zoomSegments = [RecorderTimeline.ZoomSegment(start: 0, end: 3,
                                                                   amount: 2,
                                                                   focusX: 0.1, focusY: 0.1)]
        let bubbleLayout = RecorderCameraLayout(centerX: 0.9, centerY: 0.9, size: 0.3,
                                                shape: .circle, mirrored: false,
                                                showsShadow: false)
        let cameraTimeline = RecorderCameraTrack(events: [
            RecorderCameraLayoutEvent(time: 0, layout: bubbleLayout),
        ])
        let sourceSize = CGSize(width: 320, height: 180)
        if let plan = RecorderComposer.makePlan(document: cameraDocument,
                                                track: RecorderPointerTrack(),
                                                camera: cameraTimeline,
                                                sourceSize: sourceSize,
                                                frameRate: 30,
                                                duration: 3) {
            suite.expect(plan.showsCamera && plan.cameraLayouts.contains { $0 != nil },
                         "a camera track makes the composer draw the bubble")
            suite.expect((plan.zoom.max() ?? 1) > 1.5,
                         "the fixture really zooms, so the bubble has something to survive")
            let composer = RecorderComposer(plan: plan)
            let source = CIImage(color: CIColor(red: 0, green: 0, blue: 1, alpha: 1))
                .cropped(to: CGRect(origin: .zero, size: sourceSize))
            let camera = CIImage(color: CIColor(red: 1, green: 0, blue: 0, alpha: 1))
                .cropped(to: CGRect(x: 0, y: 0, width: 160, height: 160))
            let frame = composer.render(source, camera: camera, at: 1.2)
            let width = Int(plan.canvasSize.width)
            let height = Int(plan.canvasSize.height)
            let pixels = rendered(frame, size: plan.canvasSize)
            var red = 0, blue = 0, redLeft = 0
            var redSumX = 0, redSumY = 0
            for y in 0..<height {
                for x in 0..<width {
                    let offset = (y * width + x) * 4
                    let r = Int(pixels[offset])
                    let g = Int(pixels[offset + 1])
                    let b = Int(pixels[offset + 2])
                    if r > 180, g < 80, b < 80 {
                        red += 1
                        redSumX += x
                        redSumY += y
                        if x < width / 2 { redLeft += 1 }
                    } else if b > 180, r < 80 {
                        blue += 1
                    }
                }
            }
            suite.expect(red > 500 && redLeft == 0 && blue > 1_000,
                         "the bubble is drawn over the zoomed picture instead of being cropped out")
            let centroidX = red > 0 ? redSumX / red : 0
            let centroidY = red > 0 ? redSumY / red : 0
            suite.expect(centroidX > width / 2,
                         "the bubble keeps the recorded area's right side")
            suite.expect(centroidY < height / 3 || centroidY > height * 2 / 3,
                         "the bubble stays in a corner of the finished picture")
        } else {
            suite.expect(false, "a camera track should not fall back to the plain path")
        }
    }

    private static func rendered(_ image: CIImage, size: CGSize) -> [UInt8] {
        let width = Int(size.width)
        let height = Int(size.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        CIContext(options: [.cacheIntermediates: false]).render(
            image,
            toBitmap: &bytes,
            rowBytes: width * 4,
            bounds: CGRect(origin: .zero, size: size),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB())
        return bytes
    }

    private static func buffer(width: Int, height: Int,
                               fill: (UInt8, UInt8, UInt8, UInt8)) -> CVPixelBuffer? {
        guard let buffer = makeBuffer(width: width, height: height) else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        for row in 0..<height {
            let pixels = base.advanced(by: row * rowBytes)
                .assumingMemoryBound(to: UInt8.self)
            for column in 0..<width {
                let pixel = pixels.advanced(by: column * 4)
                pixel[0] = fill.0
                pixel[1] = fill.1
                pixel[2] = fill.2
                pixel[3] = fill.3
            }
        }
        return buffer
    }

    private static func halvedBuffer(width: Int, height: Int,
                                     left: (UInt8, UInt8, UInt8, UInt8),
                                     right: (UInt8, UInt8, UInt8, UInt8)) -> CVPixelBuffer? {
        guard let buffer = makeBuffer(width: width, height: height) else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        for row in 0..<height {
            let pixels = base.advanced(by: row * rowBytes)
                .assumingMemoryBound(to: UInt8.self)
            for column in 0..<width {
                let value = column < width / 2 ? left : right
                let pixel = pixels.advanced(by: column * 4)
                pixel[0] = value.0
                pixel[1] = value.1
                pixel[2] = value.2
                pixel[3] = value.3
            }
        }
        return buffer
    }

    private static func makeBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attributes: [String: Any] = [kCVPixelBufferIOSurfacePropertiesKey as String: [:]]
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                  kCVPixelFormatType_32BGRA,
                                  attributes as CFDictionary, &buffer) == kCVReturnSuccess
        else { return nil }
        return buffer
    }

    private static func pixel(_ buffer: CVPixelBuffer,
                              x: Int, y: Int) -> (red: Int, green: Int, blue: Int) {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return (0, 0, 0) }
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        let pixel = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
            .advanced(by: x * 4)
        // BGRA in memory.
        return (Int(pixel[2]), Int(pixel[1]), Int(pixel[0]))
    }
}
