// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

enum LaunchItemScope: String, Equatable {
    case userAgent
    case systemAgent
    case systemDaemon

    /// Only the current user's own agents can be stopped without an
    /// administrator password. Everything else is listed and explained.
    var isWritable: Bool { self == .userAgent }
}

struct LaunchItem: Identifiable, Equatable {
    let url: URL
    let label: String
    let program: String?
    let scope: LaunchItemScope
    let state: LaunchItemsSupport.ServiceState
    let disabledAtLogin: Bool?
    let plistIdentity: LaunchItemsSupport.PlistIdentity?

    var id: String { url.path }
    var canToggle: Bool { scope.isWritable && plistIdentity != nil }

    func allows(_ action: LaunchItemsSupport.Action) -> Bool {
        canToggle && LaunchItemsSupport.allows(action, state: state, disabledAtLogin: disabledAtLogin,
                                                plist: url)
    }
}

enum LaunchItemsSupport {
    struct AgentFolders {
        let local: URL
        let system: URL
        let cryptex: URL
        let systemOwner: uid_t

        static let standard = AgentFolders(
            local: URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true),
            system: URL(fileURLWithPath: "/System/Library/LaunchAgents", isDirectory: true),
            cryptex: URL(fileURLWithPath: "/System/Volumes/Preboot/Cryptexes/App/System/Library/LaunchAgents",
                        isDirectory: true),
            systemOwner: 0
        )
    }

    enum Action: String, Identifiable {
        case startForSession, stopForSession, enableAtLogin, disableAtLogin

        var id: String { rawValue }
    }

    enum ServiceState: Equatable {
        case unknown, unloaded
        case loaded(path: String, running: Bool)

        func matches(_ plist: URL) -> Bool {
            guard case let .loaded(path, _) = self else { return false }
            return URL(fileURLWithPath: path).standardizedFileURL == plist.standardizedFileURL
        }
    }

    struct PlistIdentity: Equatable {
        let device: Int32
        let inode: UInt64
        let size: Int64
        let modifiedSeconds: Int
        let modifiedNanoseconds: Int
    }

    struct CommandResult {
        let status: Int32
        let output: Data
    }

    typealias Command = ([String]) -> CommandResult
    typealias Plist = (label: String, program: String?, disabled: Bool)

    /// Reads the label and the executable path from a launchd plist. A plist
    /// without a label cannot be identified and is skipped.
    static func parse(_ data: Data) -> Plist? {
        guard let object = try? PropertyListSerialization.propertyList(from: data,
                                                                       options: [],
                                                                       format: nil),
              let dictionary = object as? [String: Any],
              let label = dictionary["Label"] as? String,
              !label.isEmpty, label == label.trimmingCharacters(in: .whitespacesAndNewlines),
              !label.contains("/"), label.rangeOfCharacter(from: .controlCharacters) == nil
        else { return nil }
        let program = (dictionary["Program"] as? String)
            ?? (dictionary["ProgramArguments"] as? [String])?.first
        return (label, program?.isEmpty == true ? nil : program, dictionary["Disabled"] as? Bool ?? false)
    }

    static func readPlist(_ url: URL, systemOwner: uid_t? = nil) -> Plist? {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { return nil }
        if let systemOwner {
            guard info.st_uid == systemOwner, (info.st_mode & 0o022) == 0 else { return nil }
        }
        let reader = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        guard let data = try? reader.readToEnd() else { return nil }
        return parse(data)
    }

    static func entries(in folder: URL) -> [URL]? {
        do {
            return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "plist" }
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        } catch {
            return nil
        }
    }

    private static func peerLabel(_ url: URL, folders: AgentFolders) -> String? {
        if let ordinary = readPlist(url) { return ordinary.label }

        // Stock system agents can point into Apple's App Cryptex. Follow this
        // narrow exception only when reading a peer for label comparison.
        var info = stat()
        guard url.deletingLastPathComponent().standardizedFileURL == folders.system.standardizedFileURL,
              lstat(url.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFLNK,
              info.st_uid == folders.systemOwner else { return nil }
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        guard resolved.deletingLastPathComponent().standardizedFileURL == folders.cryptex.standardizedFileURL,
              resolved.pathExtension == "plist" else { return nil }
        return readPlist(resolved, systemOwner: folders.systemOwner)?.label
    }

    private static func hasUniqueAgentLabel(_ label: String, at selected: URL,
                                            home: URL, folders: AgentFolders) -> Bool {
        for root in [home.appendingPathComponent("Library/LaunchAgents"), folders.local, folders.system] {
            guard let plists = entries(in: root) else { return false }
            for other in plists where other.standardizedFileURL != selected.standardizedFileURL {
                guard let peer = peerLabel(other, folders: folders), peer != label else { return false }
            }
        }
        return true
    }

    /// Resolves which of the three launchd folders a plist belongs to. The
    /// user folder is matched against the given home so tests can use a
    /// fixture.
    static func scope(for url: URL, home: URL) -> LaunchItemScope? {
        let path = url.standardizedFileURL.path
        let homePath = home.standardizedFileURL.path
        if path == homePath + "/Library/LaunchAgents/\(url.lastPathComponent)" {
            return .userAgent
        }
        if path == "/Library/LaunchAgents/\(url.lastPathComponent)" {
            return .systemAgent
        }
        if path == "/Library/LaunchDaemons/\(url.lastPathComponent)" {
            return .systemDaemon
        }
        return nil
    }

    static func ownedPlistIdentity(_ url: URL, home: URL, uid: uid_t) -> PlistIdentity? {
        guard scope(for: url, home: home) == .userAgent,
              url.pathExtension == "plist",
              url.resolvingSymlinksInPath().standardizedFileURL ==
                home.resolvingSymlinksInPath().appendingPathComponent("Library/LaunchAgents")
                    .appendingPathComponent(url.lastPathComponent).standardizedFileURL else { return nil }
        var info = stat()
        guard lstat(url.path, &info) == 0,
              info.st_uid == uid, (info.st_mode & S_IFMT) == S_IFREG else { return nil }
        return PlistIdentity(device: info.st_dev, inode: info.st_ino, size: info.st_size,
                             modifiedSeconds: info.st_mtimespec.tv_sec,
                             modifiedNanoseconds: info.st_mtimespec.tv_nsec)
    }

    static func serviceTarget(uid: uid_t, label: String) -> String { "gui/\(uid)/\(label)" }

    /// launchctl's diagnostic output has no stable schema, so require the
    /// expected target and fields. A failed query is unknown, not unloaded.
    static func serviceState(uid: uid_t, label: String, run: Command) -> ServiceState {
        let target = serviceTarget(uid: uid, label: label)
        let result = run(["print", target])
        guard let output = String(data: result.output, encoding: .utf8) else { return .unknown }
        let lines = output.split(separator: "\n")
        if result.status == 113,
           lines.contains("Could not find service \"\(label)\" in domain for user gui: \(uid)") {
            return .unloaded
        }
        guard result.status == 0, lines.first == "\(target) = {", lines.last == "}" else { return .unknown }
        let pathPrefix = "\tpath = "
        let statePrefix = "\tstate = "
        guard let pathLine = lines.first(where: { $0.hasPrefix(pathPrefix) }),
              let stateLine = lines.first(where: { $0.hasPrefix(statePrefix) })
        else { return .unknown }
        let path = String(pathLine.dropFirst(pathPrefix.count))
        guard path.hasPrefix("/") else { return .unknown }
        return .loaded(path: path, running: stateLine.dropFirst(statePrefix.count) == "running")
    }

    /// The persistent override is independent of the service's loaded state.
    /// An empty, recognized list means there are no overrides.
    static func disabledOverrides(uid: uid_t, run: Command) -> [String: Bool]? {
        let result = run(["print-disabled", "gui/\(uid)"])
        guard result.status == 0,
              let output = String(data: result.output, encoding: .utf8) else { return nil }
        let lines = output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        guard lines.first == "disabled services = {", lines.last == "}" else { return nil }
        var resultByLabel: [String: Bool] = [:]
        for line in lines.dropFirst().dropLast() where !line.isEmpty {
            let labelStart = line.index(after: line.startIndex)
            guard line.first == "\"",
                  let separator = line.range(of: "\" => ", options: .backwards),
                  labelStart < separator.lowerBound else { return nil }
            let label = String(line[labelStart..<separator.lowerBound])
            let state = line[separator.upperBound...]
            switch state {
            case "disabled", "true": resultByLabel[label] = true
            case "enabled", "false": resultByLabel[label] = false
            default: return nil
            }
        }
        return resultByLabel
    }

    static func allows(_ action: Action, state: ServiceState, disabledAtLogin: Bool?, plist: URL) -> Bool {
        switch action {
        case .startForSession: return state == .unloaded && disabledAtLogin == false
        case .stopForSession: return state.matches(plist)
        case .enableAtLogin: return disabledAtLogin == true && (state == .unloaded || state.matches(plist))
        case .disableAtLogin: return disabledAtLogin == false && (state == .unloaded || state.matches(plist))
        }
    }

    static func perform(_ action: Action, uid: uid_t, label: String, plist: URL,
                        defaultDisabled: Bool, run: Command, isCurrent: () -> Bool = { true }) -> Bool {
        let state = serviceState(uid: uid, label: label, run: run)
        let disabledAtLogin = action == .stopForSession ? nil :
            disabledOverrides(uid: uid, run: run).map { $0[label] ?? defaultDisabled }
        guard allows(action, state: state, disabledAtLogin: disabledAtLogin,
                     plist: plist), isCurrent() else { return false }
        let domain = "gui/\(uid)"
        let target = serviceTarget(uid: uid, label: label)
        switch action {
        case .startForSession:
            return run(["bootstrap", domain, plist.path]).status == 0
                && serviceState(uid: uid, label: label, run: run).matches(plist)
        case .stopForSession:
            return run(["bootout", domain, plist.path]).status == 0
                && serviceState(uid: uid, label: label, run: run) == .unloaded
        case .enableAtLogin, .disableAtLogin:
            let disable = action == .disableAtLogin
            return run([disable ? "disable" : "enable", target]).status == 0
                && disabledOverrides(uid: uid, run: run)?[label] == disable
        }
    }

    /// Performs an action only for the confirmed, still-owned user plist.
    /// A login override changes a label, so all peer labels must be known and unique.
    static func perform(_ action: Action, on item: LaunchItem, home: URL, uid: uid_t,
                        folders: AgentFolders = .standard, run: Command) -> Bool {
        guard item.allows(action), let identity = item.plistIdentity,
              ownedPlistIdentity(item.url, home: home, uid: uid) == identity,
              let plist = readPlist(item.url), plist.label == item.label else { return false }
        if action == .enableAtLogin || action == .disableAtLogin {
            guard hasUniqueAgentLabel(item.label, at: item.url, home: home, folders: folders) else { return false }
        }
        return perform(action, uid: uid, label: item.label, plist: item.url,
                       defaultDisabled: plist.disabled, run: run, isCurrent: {
            ownedPlistIdentity(item.url, home: home, uid: uid) == identity
                && readPlist(item.url)?.label == item.label
        })
    }
}
