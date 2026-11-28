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

    /// Reads the label and the executable path from a launchd plist. A plist
    /// without a label cannot be identified and is skipped.
    static func parse(_ data: Data) -> (label: String, program: String?, disabled: Bool)? {
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
            guard line.first == "\"", let separator = line.range(of: "\" => ", options: .backwards)
            else { return nil }
            let label = String(line[line.index(after: line.startIndex)..<separator.lowerBound])
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
}
