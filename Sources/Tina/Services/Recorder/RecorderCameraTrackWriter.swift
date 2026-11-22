// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AVFoundation
import CoreMedia
import Foundation

/// Writes the camera frames beside the master instead of drawing them into
/// it. The composer then places the bubble after the edit's zoom and aspect
/// fit, so a zoom can never crop the person out of their own recording.
///
/// The track runs on the recording's own clock: samples are retimed through
/// the same pause clock as the screen and the first frame is held at zero, so
/// the camera and the screen line up frame for frame without sharing a file.
/// Frames arriving while the recording is paused are dropped, exactly like the
/// screen's.
final class RecorderCameraTrackWriter: @unchecked Sendable {

    private let url: URL
    private let pauseClock: RecorderPauseClock
    private let queue = DispatchQueue(label: "com.tina.recorder.camera-track",
                                      qos: .userInitiated)
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var frameCount = 0
    private var failed = false
    private var stopped = false
    /// Held so the bubble has a frame at the moment Stop was pressed, even if
    /// the screen sat still for the last second before it.
    private var lastSample: CMSampleBuffer?
    private var lastTime: CMTime = .invalid

    init(url: URL, pauseClock: RecorderPauseClock) {
        self.url = url
        self.pauseClock = pauseClock
    }

    /// Called from the camera's own queue for every delivered frame. Waiting
    /// for the encoder is never allowed here: a frame nobody can take is
    /// simply skipped, like a late screen frame.
    func append(_ sampleBuffer: CMSampleBuffer) {
        queue.async { [self] in
            guard !failed, !stopped, !pauseClock.isPaused,
                  let time = mappedTime(of: sampleBuffer),
                  let retimed = RecorderSampleTiming.retimed(sampleBuffer, to: time)
            else { return }
            if writer == nil, !startWriter(with: sampleBuffer) { return }
            guard let input else { return }
            guard input.isReadyForMoreMediaData else { return }
            if input.append(retimed) {
                frameCount += 1
                lastSample = retimed
                lastTime = time
            } else {
                failed = true
            }
        }
    }

    /// Closes the file once the camera has stopped, so no frame can arrive
    /// afterwards. `end` is the wall-clock moment Stop was pressed, in the
    /// same host clock the camera's samples carry. False means there is no
    /// camera track worth keeping.
    func finish(at end: CMTime) async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                stopped = true
                guard let writer, let input, frameCount > 0, !failed else {
                    writer?.cancelWriting()
                    try? FileManager.default.removeItem(at: url)
                    continuation.resume(returning: false)
                    return
                }
                // Hold the last face on screen until the moment the person
                // stopped, exactly as the screen writer holds its last frame.
                if end.isNumeric, let lastSample {
                    let tail = pauseClock.elapsed(at: end.seconds)
                    if tail.isFinite, tail > lastTime.seconds,
                       input.isReadyForMoreMediaData,
                       let retimed = RecorderSampleTiming.retimed(
                           lastSample,
                           to: CMTime(seconds: tail, preferredTimescale: 600_000_000)) {
                        _ = input.append(retimed)
                    }
                }
                input.markAsFinished()
                writer.finishWriting {
                    self.queue.async {
                        let written = writer.status == .completed
                        if written {
                            try? FileManager.default.setAttributes(
                                [.posixPermissions: 0o600],
                                ofItemAtPath: self.url.path)
                        } else {
                            try? FileManager.default.removeItem(at: self.url)
                        }
                        continuation.resume(returning: written)
                    }
                }
            }
        }
    }

    func cancel() {
        queue.async { [self] in
            stopped = true
            writer?.cancelWriting()
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Timing

    /// The recording's own time for this sample, or nil before the screen
    /// stream has started (the camera comes up first) and while paused.
    private func mappedTime(of sampleBuffer: CMSampleBuffer) -> CMTime? {
        let presentation = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard presentation.isValid, presentation.seconds.isFinite else { return nil }
        let duration = CMSampleBufferGetDuration(sampleBuffer)
        let seconds = duration.isValid && !duration.isIndefinite ? max(0, duration.seconds) : 0
        guard let mapped = pauseClock.sampleTime(start: presentation.seconds,
                                                 duration: seconds)
        else { return nil }
        // The first written frame is held at zero, like the screen's first
        // frame, so a camera that started a beat earlier cannot shift the
        // whole track ahead of the picture.
        guard frameCount > 0 else {
            return CMTime(seconds: 0, preferredTimescale: 600_000_000)
        }
        return CMTime(seconds: max(0, mapped), preferredTimescale: 600_000_000)
    }

    private func startWriter(with sampleBuffer: CMSampleBuffer) -> Bool {
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer) else { return false }
        let dimensions = CMVideoFormatDescriptionGetDimensions(format)
        let width = Int(dimensions.width)
        let height = Int(dimensions.height)
        guard width > 0, height > 0,
              let writer = try? AVAssetWriter(outputURL: url, fileType: .mov)
        else {
            failed = true
            return false
        }
        writer.movieFragmentInterval = CMTime(seconds: 10, preferredTimescale: 600)

        let bitRate = min(6_000_000, RecorderSupport.averageBitRate(width: width,
                                                                    height: height,
                                                                    fps: 30,
                                                                    quality: .balanced))
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate,
                AVVideoExpectedSourceFrameRateKey: 30,
                AVVideoAllowFrameReorderingKey: false,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else {
            failed = true
            return false
        }
        writer.add(input)
        guard writer.startWriting() else {
            failed = true
            return false
        }
        writer.startSession(atSourceTime: .zero)
        self.writer = writer
        self.input = input
        return true
    }
}
