// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Combine
import Darwin
import Foundation

/// Diagnoses installed apps that macOS refuses to open and offers the one
/// safe repair: dropping the download quarantine flag from an app whose
/// signature still verifies. Signature failures and Gatekeeper refusals are
/// reported, never bypassed.
final class AppRepairService: ObservableObject {
    static let shared = AppRepairService()

    enum Phase: Equatable { case idle, scanning, loaded, failed }

    @Published private(set) var candidates: [AppRepairCandidate] = []
    @Published private(set) var phase: Phase = .idle

    private let workQueue = DispatchQueue(label: "com.tina.utils.app-repair", qos: .userInitiated)

    /// Enumerates the top level of the application folders and checks each
    /// bundle. The scan runs off the main thread; callers get the finished
    /// list on the main queue.
    func scan() {
        phase = .scanning
        workQueue.async { [weak self] in
            let found = Self.applicationURLs().compactMap(Self.inspect)
            DispatchQueue.main.async {
                guard let self else { return }
                self.candidates = found
                self.phase = .loaded
            }
        }
    }

    /// Removes the quarantine attribute after re-checking the same conditions
    /// the scan used. Returns the updated candidate, or nil when the bundle
    /// changed underneath the user.
    func removeQuarantine(_ candidate: AppRepairCandidate) -> Bool {
        guard let refreshed = Self.inspect(candidate.url),
              refreshed.canRemoveQuarantine else { return false }
        let result = candidate.url.path.withCString { path in
            removexattr(path, "com.apple.quarantine", 0)
        }
        guard result == 0 else { return false }
        candidates.removeAll { $0.id == candidate.id }
        return true
    }

    static func applicationURLs() -> [URL] {
        let fm = FileManager.default
        var roots: [URL] = []
        if let local = fm.urls(for: .applicationDirectory, in: .localDomainMask).first {
            roots.append(local)
        }
        if let user = fm.urls(for: .applicationDirectory, in: .userDomainMask).first,
           user != roots.first {
            roots.append(user)
        }
        var apps: [URL] = []
        for root in roots {
            guard let entries = try? fm.contentsOfDirectory(at: root,
                                                             includingPropertiesForKeys: nil) else { continue }
            for entry in entries where entry.pathExtension == "app" {
                apps.append(entry)
            }
        }
        return apps
    }

    /// One bundle, three independent answers. A missing quarantine attribute
    /// is a definite "not quarantined"; an unreadable one is not.
    static func inspect(_ url: URL) -> AppRepairCandidate? {
        guard let bundle = Bundle(url: url) else { return nil }
        var issues: Set<AppRepairIssue> = []
        let quarantine = quarantineState(at: url)
        if quarantine == .present { issues.insert(.quarantined) }
        let signatureValid = run("/usr/bin/codesign",
                                 arguments: ["--verify", "--strict", url.path]).status == 0
        if !signatureValid { issues.insert(.invalidSignature) }
        if signatureValid, !gatekeeperAccepts(url) { issues.insert(.notAccepted) }
        guard AppRepairPolicy.isCandidate(issues: issues) else { return nil }
        let name = FileManager.default.displayName(atPath: url.path)
        return AppRepairCandidate(url: url,
                                  bundleIdentifier: bundle.bundleIdentifier,
                                  name: name,
                                  issues: issues,
                                  quarantineReadable: quarantine != .unreadable)
    }

    enum QuarantineState: Equatable {
        case absent, present, unreadable
    }

    static func quarantineState(at url: URL) -> QuarantineState {
        let size = url.path.withCString {
            getxattr($0, "com.apple.quarantine", nil, 0, 0, 0)
        }
        if size > 0 { return .present }
        if size == 0 { return .absent }
        return errno == ENOATTR ? .absent : .unreadable
    }

    /// Same assessment the Disk Image Installer uses before it installs a
    /// copy: an unchanged signature plus Gatekeeper's own answer. A disabled
    /// Gatekeeper (`spctl --status`) is recorded as accepted, because the
    /// system is not going to ask.
    static func gatekeeperAccepts(_ url: URL) -> Bool {
        let status = run("/usr/sbin/spctl", arguments: ["--status"])
        if String(data: status.output, encoding: .utf8)?
            .localizedCaseInsensitiveContains("disabled") == true {
            return true
        }
        return run("/usr/sbin/spctl", arguments: ["-a", "-t", "exec", url.path]).status == 0
    }

    struct CommandResult {
        let status: Int32
        let output: Data
    }

    static func run(_ executable: String, arguments: [String]) -> CommandResult {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return CommandResult(status: -1, output: Data())
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandResult(status: process.terminationStatus, output: data)
    }
}
