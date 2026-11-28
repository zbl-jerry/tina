// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Combine
import Darwin
import Foundation

/// Diagnose first. Offer a change only for the same confirmed bundle, with a
/// valid recursive signature and an explicit Gatekeeper acceptance.
final class AppRepairService: ObservableObject {
    static let shared = AppRepairService()

    enum Phase: Equatable { case idle, scanning, loaded }

    @Published private(set) var candidates: [AppRepairCandidate] = []
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var repairingID: String?

    private let workQueue = DispatchQueue(label: "com.tina.utils.app-repair", qos: .userInitiated)
    private static let quarantine = "com.apple.quarantine"

    func scan() {
        guard phase != .scanning, repairingID == nil else { return }
        phase = .scanning
        workQueue.async { [weak self] in
            let assessmentEnabled = Self.assessmentIsEnabled()
            let found = Self.applicationURLs().compactMap { Self.inspect($0, assessmentEnabled: assessmentEnabled) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.candidates = found
                self.phase = .loaded
            }
        }
    }

    func removeQuarantine(_ candidate: AppRepairCandidate, completion: @escaping (Bool) -> Void) {
        guard repairingID == nil, phase == .loaded, candidate.canRemoveQuarantine else {
            completion(false)
            return
        }
        repairingID = candidate.id
        workQueue.async { [weak self] in
            let repaired = Self.repairConfirmedBundle(candidate)
            DispatchQueue.main.async {
                guard let self else { return }
                if repaired { self.candidates.removeAll { $0.id == candidate.id } }
                self.repairingID = nil
                completion(repaired)
            }
        }
    }

    private static func repairConfirmedBundle(_ candidate: AppRepairCandidate) -> Bool {
        let fd = openBundle(candidate.url)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        guard identity(of: fd) == candidate.fileIdentity,
              let refreshed = inspect(candidate.url, assessmentEnabled: assessmentIsEnabled()),
              refreshed.canRemoveQuarantine,
              refreshed.fileIdentity == candidate.fileIdentity,
              identity(at: candidate.url) == candidate.fileIdentity else { return false }
        // The descriptor still refers to the exact confirmed object even if
        // another directory takes over its pathname after this check.
        return fremovexattr(fd, quarantine, 0) == 0
    }

    static func identity(at url: URL) -> AppRepairFileIdentity? {
        let fd = openBundle(url)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        return identity(of: fd)
    }

    private static func openBundle(_ url: URL) -> Int32 {
        url.path.withCString { open($0, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC) }
    }

    private static func identity(of fd: Int32) -> AppRepairFileIdentity? {
        var info = stat()
        guard fstat(fd, &info) == 0 else { return nil }
        return AppRepairFileIdentity(device: info.st_dev, inode: info.st_ino,
                                     createdSeconds: info.st_birthtimespec.tv_sec,
                                     createdNanoseconds: info.st_birthtimespec.tv_nsec)
    }

    static func applicationURLs() -> [URL] {
        let fm = FileManager.default
        let roots = [.localDomainMask, .userDomainMask].compactMap {
            fm.urls(for: .applicationDirectory, in: $0).first
        }
        return Set(roots).flatMap { root in
            (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        }.filter { $0.pathExtension == "app" }.sorted { $0.path < $1.path }
    }

    private static func inspect(_ url: URL, assessmentEnabled: Bool) -> AppRepairCandidate? {
        guard let fileIdentity = identity(at: url), let bundle = Bundle(url: url) else { return nil }
        var issues: Set<AppRepairIssue> = []
        let quarantine = quarantineState(at: url)
        if quarantine == .present { issues.insert(.quarantined) }
        let signature = run("/usr/bin/codesign", arguments: signatureArguments(for: url))
        if signature?.status == 0 {
            if assessmentEnabled {
                let result = run("/usr/sbin/spctl", arguments: ["-a", "-t", "exec", url.path])
                switch result?.status {
                case 0: break
                case 3: issues.insert(.notAccepted)
                default: issues.insert(.assessmentUnavailable)
                }
            } else if quarantine == .present {
                issues.insert(.assessmentUnavailable)
            }
        } else if signature == nil {
            issues.insert(.assessmentUnavailable)
        } else {
            issues.insert(.invalidSignature)
        }
        guard AppRepairPolicy.isCandidate(issues: issues), identity(at: url) == fileIdentity else { return nil }
        return AppRepairCandidate(url: url, bundleIdentifier: bundle.bundleIdentifier,
                                  name: FileManager.default.displayName(atPath: url.path),
                                  fileIdentity: fileIdentity, issues: issues,
                                  quarantineReadable: quarantine != .unreadable)
    }

    static func signatureArguments(for url: URL) -> [String] {
        ["--verify", "--deep", "--strict", url.path]
    }

    enum QuarantineState: Equatable { case absent, present, unreadable }

    static func quarantineState(at url: URL) -> QuarantineState {
        let size = url.path.withCString { getxattr($0, quarantine, nil, 0, 0, XATTR_NOFOLLOW) }
        if size >= 0 { return .present }
        return errno == ENOATTR ? .absent : .unreadable
    }

    static func assessmentIsEnabled(status: Int32, output: Data) -> Bool {
        status == 0 && String(data: output, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) == "assessments enabled"
    }

    private static func assessmentIsEnabled() -> Bool {
        guard let result = run("/usr/sbin/spctl", arguments: ["--status"], readStatusText: true) else {
            return false
        }
        return assessmentIsEnabled(status: result.status, output: result.output)
    }

    private struct CommandResult {
        let status: Int32
        let output: Data
    }

    /// Only the one-line Gatekeeper status is captured. Other output is
    /// discarded so a verbose verification cannot block on a full pipe.
    private static func run(_ executable: String, arguments: [String],
                            readStatusText: Bool = false) -> CommandResult? {
        let process = Process()
        let output = readStatusText ? Pipe() : nil
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = (output as Any?) ?? FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "C"
        process.environment = environment
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch { return nil }
        guard finished.wait(timeout: .now() + 15) == .success else {
            if process.isRunning { process.terminate() }
            return nil
        }
        guard process.terminationReason == .exit else { return nil }
        let data = output?.fileHandleForReading.readDataToEndOfFile() ?? Data()
        return CommandResult(status: process.terminationStatus, output: data)
    }
}
