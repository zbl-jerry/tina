// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AVFoundation
import CoreVideo

/// Captures the camera for a recording. One session feeds both the bubble's
/// preview layer and the sidecar track the composer draws from, so the camera
/// is opened once. Late frames are dropped rather than queued: the recording
/// wants the newest face, not every face it missed.
final class RecorderCameraCapture: NSObject, @unchecked Sendable {

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.tina.recorder.camera",
                                      qos: .userInitiated)
    private var configured = false
    private var observers: [NSObjectProtocol] = []
    private let interruptionLock = NSLock()
    private var reportedInterruption = false
    private var stopped = false
    /// Called once when the device or session goes away mid-recording. The
    /// recording keeps going without the bubble.
    var onInterruption: (() -> Void)?
    /// Every delivered frame, on the capture queue, for the sidecar track the
    /// composer later draws the bubble from.
    var onFrame: ((CMSampleBuffer) -> Void)?

    /// The session the floating bubble shows. It is the same one delivering
    /// frames to the sidecar track.
    var previewSession: AVCaptureSession { session }

    // MARK: - Devices

    /// Cameras the system currently offers, in the order it lists them.
    /// Continuity Camera is included so an iPhone can be the bubble without
    /// any extra setup.
    static func devices() -> [AVCaptureDevice] {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified)
        return session.devices
    }

    /// The remembered camera when it is still attached, otherwise the first
    /// one. A backup restored on another Mac carries an ID this Mac does not
    /// know, which must not cost the feature.
    static func device(matching uniqueID: String) -> AVCaptureDevice? {
        if !uniqueID.isEmpty,
           let remembered = AVCaptureDevice(uniqueID: uniqueID),
           remembered.hasMediaType(.video) {
            return remembered
        }
        return devices().first
    }

    // MARK: - Lifecycle

    func start(deviceID: String) async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard configure(deviceID: deviceID) else {
                    continuation.resume(returning: false)
                    return
                }
                observeInterruptions()
                session.startRunning()
                continuation.resume(returning: session.isRunning)
            }
        }
    }

    func stop() async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                interruptionLock.withLock { stopped = true }
                if session.isRunning { session.stopRunning() }
                removeObservers()
                continuation.resume()
            }
        }
    }

    /// A device unplugged, another app taking the camera, or the system
    /// interrupting capture all end the same way: no more frames, one notice,
    /// and a recording that carries on.
    private func observeInterruptions() {
        removeObservers()
        for name in [AVCaptureSession.runtimeErrorNotification,
                     AVCaptureSession.wasInterruptedNotification] {
            observers.append(NotificationCenter.default.addObserver(
                forName: name, object: session, queue: .main) { [weak self] _ in
                    self?.reportInterruption()
                })
        }
    }

    /// Both notifications can arrive for one unplugged device, and the
    /// recording should hear about it once.
    private func reportInterruption() {
        let shouldReport = interruptionLock.withLock { () -> Bool in
            // A notification already on the main queue when Stop ran says
            // nothing about a recording that has ended.
            guard !reportedInterruption, !stopped else { return false }
            reportedInterruption = true
            return true
        }
        guard shouldReport else { return }
        onInterruption?()
    }

    private func removeObservers() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    private func configure(deviceID: String) -> Bool {
        if configured { return true }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              let device = Self.device(matching: deviceID),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return false }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        // 720p is more than the bubble can show and keeps the pipeline's cost
        // flat on an external 4K camera.
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]
        output.alwaysDiscardsLateVideoFrames = true
        guard session.canAddInput(input), session.canAddOutput(output) else {
            return false
        }
        session.addInput(input)
        session.addOutput(output)
        output.setSampleBufferDelegate(self, queue: queue)
        // Mirroring is decided in the compositor, where it applies to the
        // recorded pixels; the preview layer mirrors itself separately.
        if let connection = output.connection(with: .video),
           connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
        configured = true
        return true
    }
}

extension RecorderCameraCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard CMSampleBufferGetImageBuffer(sampleBuffer) != nil else { return }
        onFrame?(sampleBuffer)
    }
}
