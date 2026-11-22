// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AVFoundation
import CoreMedia
import Foundation
import Speech

/// Copies the tap's interleaved PCM into a buffer Speech can consume. The tap
/// reuses its memory as soon as the audio callback returns, so the copy has to
/// happen before the callback ends.
enum CaptionAudioBuffer {
    static func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let description = CMSampleBufferGetFormatDescription(sampleBuffer),
              var stream = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee,
              stream.mFormatID == kAudioFormatLinearPCM,
              stream.mFormatFlags & kAudioFormatFlagIsFloat != 0,
              let format = AVAudioFormat(streamDescription: &stream)
        else { return nil }
        let frames = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(frames))
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(frames)
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer, at: 0, frameCount: Int32(frames), into: buffer.mutableAudioBufferList)
        return status == noErr ? buffer : nil
    }
}

/// One recognizer session. Speech is confined to its own serial queue; state
/// reaches the UI on the main queue. A request is rotated before the system
/// engine's own limit, and the partial line it had is committed first so a
/// rotation never swallows the end of a sentence.
final class CaptionRecognizer: @unchecked Sendable {
    enum Failure: Error, Equatable {
        case denied
        case unavailable
        case onDeviceUnavailable
        case failed(String)
    }

    var onPartial: ((String) -> Void)?
    var onFinal: (([CaptionSegment]) -> Void)?
    var onFailure: ((Failure) -> Void)?

    private let recognizer: SFSpeechRecognizer
    private let sessionStartedAt: Date
    private let queue = DispatchQueue(label: "com.tina.captions.recognizer", qos: .userInitiated)
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var requestStartedAt = Date()
    private var requestBase: TimeInterval = 0
    private var committedEnd: TimeInterval = 0
    private var currentPartial = ""
    private var lastCommittedText = ""
    private var consecutiveRestarts = 0
    private var stopped = false
    private var rotationTimer: DispatchSourceTimer?

    init?(locale: Locale, sessionStartedAt: Date) {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            return nil
        }
        self.recognizer = recognizer
        self.sessionStartedAt = sessionStartedAt
    }

    var supportsOnDeviceRecognition: Bool {
        recognizer.supportsOnDeviceRecognition
    }

    var locale: Locale { recognizer.locale }

    // MARK: - Lifecycle

    func start() {
        queue.async { [self] in
            guard !stopped else { return }
            beginRequest()
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + 1, repeating: 1)
            timer.setEventHandler { [weak self] in self?.rotateIfNeeded() }
            rotationTimer = timer
            timer.resume()
        }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        queue.async { [self] in
            guard !stopped, let request else { return }
            request.append(buffer)
        }
    }

    func rotateIfNeeded() {
        guard !stopped else { return }
        guard CaptionSupport.shouldRotate(requestStartedAt: requestStartedAt) else { return }
        flushPartial()
        endCurrentRequest()
        beginRequest()
    }

    /// Stops taking new audio and releases the open request. The partial line
    /// is committed first; the final callback is not awaited, so stopping is
    /// immediate even when the engine is slow to answer.
    func stop() {
        queue.async { [self] in
            guard !stopped else { return }
            stopped = true
            rotationTimer?.cancel()
            rotationTimer = nil
            flushPartial()
            endCurrentRequest()
            request = nil
            task = nil
        }
    }

    // MARK: - Requests

    private func beginRequest() {
        guard !stopped else { return }
        requestStartedAt = Date()
        requestBase = elapsed()
        currentPartial = ""
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // The issue's promise: the Mac's sound is recognized here and never
        // uploaded. A language without an on-device model is refused when the
        // service checks `supportsOnDeviceRecognition`, not silently sent to
        // a server.
        request.requiresOnDeviceRecognition = true
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }
        self.request = request
        let generation = ObjectIdentifier(request)
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.queue.async {
                self?.handle(result: result, error: error, generation: generation)
            }
        }
    }

    private func endCurrentRequest() {
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }

    private func elapsed() -> TimeInterval {
        max(0, Date().timeIntervalSince(sessionStartedAt))
    }

    // MARK: - Results

    private func handle(result: SFSpeechRecognitionResult?, error: Error?,
                        generation: ObjectIdentifier) {
        guard !stopped, let request, ObjectIdentifier(request) == generation else { return }
        if let result {
            consecutiveRestarts = 0
            let text = CaptionSupport.normalizedText(result.bestTranscription.formattedString)
            if result.isFinal {
                commit(result: result, text: text)
            } else {
                currentPartial = text
                DispatchQueue.main.async { [weak self] in self?.onPartial?(text) }
            }
        }
        guard let error else { return }
        handle(error: error, generation: generation)
    }

    private func commit(result: SFSpeechRecognitionResult, text: String) {
        let pieces = result.bestTranscription.segments.map {
            CaptionSpeechSegment(timestamp: $0.timestamp, duration: $0.duration,
                                 text: $0.substring)
        }
        var segments = CaptionSupport.segments(from: pieces, base: requestBase,
                                               measuredFrom: committedEnd)
        if segments.isEmpty,
           let fallback = CaptionSupport.fallbackSegment(
               text: text,
               start: max(committedEnd, requestBase),
               end: max(committedEnd + 0.5, elapsed())) {
            segments = [fallback]
        }
        guard !segments.isEmpty else { return }
        let joined = segments.map(\.text).joined(separator: " ")
        let key = CaptionSupport.speechKey(joined)
        // A final arriving twice around a rotation is one line, not two.
        guard key != lastCommittedText else { return }
        lastCommittedText = key
        currentPartial = ""
        committedEnd = max(committedEnd, segments.map(\.end).max() ?? committedEnd)
        DispatchQueue.main.async { [weak self] in self?.onFinal?(segments) }
    }

    /// The partial line is the only complete copy once a request is about to
    /// be closed, so it becomes a final line instead of vanishing with the
    /// request.
    private func flushPartial() {
        let text = CaptionSupport.normalizedText(currentPartial)
        let key = CaptionSupport.speechKey(text)
        guard !text.isEmpty, key != lastCommittedText else { return }
        let start = max(committedEnd, requestBase)
        let end = max(start + 0.5, elapsed())
        guard let segment = CaptionSupport.fallbackSegment(text: text, start: start, end: end)
        else { return }
        lastCommittedText = key
        committedEnd = max(committedEnd, segment.end)
        currentPartial = ""
        DispatchQueue.main.async { [weak self] in self?.onFinal?([segment]) }
    }

    // MARK: - Failures

    private func handle(error: Error, generation: ObjectIdentifier) {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            DispatchQueue.main.async { [weak self] in self?.onFailure?(.denied) }
            return
        }
        let nsError = error as NSError
        let isEngineError = nsError.domain == "kAFAssistantErrorDomain"
        // 1101/216 are requests we closed; the rotation already committed
        // their partial. The others end the request early, so its partial is
        // the only copy of the last words.
        if isEngineError, [1101, 216].contains(nsError.code) { return }
        flushPartial()
        // 1110: no speech was recognized; 203: the engine asks for a retry.
        if isEngineError, [203, 1110].contains(nsError.code) {
            if !stopped, request != nil {
                scheduleRestart(generation: generation)
            }
            return
        }
        consecutiveRestarts += 1
        if consecutiveRestarts <= 3, !stopped, request != nil {
            scheduleRestart(generation: generation)
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.onFailure?(.failed(error.localizedDescription))
        }
    }

    private func scheduleRestart(generation: ObjectIdentifier) {
        let request = self.request
        queue.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, !self.stopped, let request,
                  ObjectIdentifier(request) == generation else { return }
            self.endCurrentRequest()
            self.beginRequest()
        }
    }
}
