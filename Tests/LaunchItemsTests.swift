// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

enum LaunchItemsTests {
    static func run(_ suite: TestSuite) {
        let home = URL(fileURLWithPath: "/Users/fixture")

        func data(_ value: [String: Any]) -> Data {
            (try? PropertyListSerialization.data(fromPropertyList: value,
                                                 format: .xml,
                                                 options: 0)) ?? Data()
        }

        let parsed = LaunchItemsSupport.parse(data([
            "Label": "com.vendor.agent",
            "ProgramArguments": ["/usr/bin/true", "--flag"],
        ]))
        suite.expect(parsed?.label == "com.vendor.agent"
                     && parsed?.program == "/usr/bin/true",
                     "the label and first argument are read")

        let program = LaunchItemsSupport.parse(data([
            "Label": "com.vendor.daemon",
            "Program": "/usr/local/bin/helper",
        ]))
        suite.expect(program?.program == "/usr/local/bin/helper",
                     "a Program key wins over arguments")

        suite.expect(LaunchItemsSupport.parse(data(["Program": "/x"])) == nil,
                     "a plist without a label is not a launch item")
        suite.expect(LaunchItemsSupport.parse(Data("nope".utf8)) == nil,
                     "unreadable data is not a launch item")

        suite.expect(LaunchItemsSupport.scope(
            for: home.appendingPathComponent("Library/LaunchAgents/a.plist"), home: home)
            == .userAgent,
            "the home folder is the writable user scope")
        suite.expect(LaunchItemsSupport.scope(
            for: URL(fileURLWithPath: "/Library/LaunchAgents/a.plist"), home: home)
            == .systemAgent,
            "system agents are read-only")
        suite.expect(LaunchItemsSupport.scope(
            for: URL(fileURLWithPath: "/Library/LaunchDaemons/a.plist"), home: home)
            == .systemDaemon,
            "system daemons are read-only")
        suite.expect(LaunchItemsSupport.scope(
            for: URL(fileURLWithPath: "/tmp/a.plist"), home: home) == nil,
            "an unrelated plist has no launch scope")

        let plist = home.appendingPathComponent("Library/LaunchAgents/com.vendor.agent.plist")
        let user = LaunchItem(url: plist, label: "com.vendor.agent", program: nil, scope: .userAgent,
                              state: .loaded(path: plist.path, running: false), disabledAtLogin: false,
                              plistIdentity: .init(device: 1, inode: 1, size: 1,
                                                   modifiedSeconds: 0, modifiedNanoseconds: 0))
        let daemon = LaunchItem(url: URL(fileURLWithPath: "/d.plist"), label: "d",
                                program: nil, scope: .systemDaemon, state: .unknown,
                                disabledAtLogin: nil, plistIdentity: nil)
        suite.expect(user.canToggle && !daemon.canToggle, "only the user scope can be toggled")
        suite.expect(LaunchItemsSupport.parse(data(["Label": "../another-service"])) == nil,
                     "a plist label cannot redirect the launchd target")
        operation(suite, plist: plist, label: user.label)
        verifyOwnedPlist(suite)
        verifyPersistentPeerGuard(suite)
    }

    private static func operation(_ suite: TestSuite, plist: URL, label: String) {
        let target = "gui/501/\(label)"
        func result(_ status: Int32 = 0, _ output: String = "") -> LaunchItemsSupport.CommandResult {
            .init(status: status, output: Data(output.utf8))
        }
        func loaded(_ path: String? = nil, running: Bool = false) -> LaunchItemsSupport.CommandResult {
            result(0, """
            \(target) = {
            \tpath = \(path ?? plist.path)
            \tstate = \(running ? "running" : "not running")
            }
            """)
        }
        let unloaded = result(113, "Bad request.\nCould not find service \"\(label)\" in domain for user gui: 501")
        let inaccessible = result(112, "Could not find domain for user gui: 501")
        let noOverrides = result(0, "\tdisabled services = {\n\t}")
        let printService = ["print", target]
        let printDisabled = ["print-disabled", "gui/501"]
        let bootout = ["bootout", "gui/501", plist.path]

        var commands: [[String]] = []
        func runAction(_ action: LaunchItemsSupport.Action,
                       replies: [LaunchItemsSupport.CommandResult],
                       current: Bool = true) -> Bool {
            commands = []
            var pending = replies
            return LaunchItemsSupport.perform(action, uid: 501, label: label, plist: plist,
                                              defaultDisabled: false, run: { command in
                commands.append(command)
                return pending.isEmpty ? inaccessible : pending.removeFirst()
            }, isCurrent: { current })
        }
        suite.expect(LaunchItemsSupport.serviceState(uid: 501, label: label, run: { _ in loaded() })
                     == .loaded(path: plist.path, running: false),
                     "an inactive loaded service is distinct from an unloaded service")
        suite.expect(LaunchItemsSupport.serviceState(uid: 501, label: label, run: { _ in inaccessible })
                     == .unknown,
                     "a failed GUI-domain lookup is not a stopped service")
        suite.expect(runAction(.stopForSession, replies: [loaded(), result(), unloaded])
                     && commands == [printService, bootout, printService],
                     "successful Stop verifies the same GUI domain no longer loads the selected path")
        suite.expect(!runAction(.stopForSession, replies: [loaded(), result(), inaccessible])
                     && commands.contains(bootout),
                     "a successful command does not turn a failed verification into success")
        suite.expect(!runAction(.stopForSession, replies: [loaded(), result(5)])
                     && commands == [printService, bootout],
                     "a refused stop is a failure")
        suite.expect(!runAction(.stopForSession, replies: [loaded("/Library/LaunchAgents/other.plist")])
                     && commands == [printService],
                     "a label loaded from a different plist may not be touched")
        suite.expect(!runAction(.stopForSession, replies: [loaded()], current: false)
                     && commands == [printService],
                     "a replaced plist invalidates the confirmed operation")
        suite.expect(runAction(.startForSession, replies: [unloaded, noOverrides, result(), loaded()])
                     && commands == [printService, printDisabled, ["bootstrap", "gui/501", plist.path], printService],
                     "start verifies the matching plist rather than just the label")

        let overriddenDisabled = result(0, "\tdisabled services = {\n\t\t\"\(label)\" => disabled\n\t}")
        let overriddenEnabled = result(0, "\tdisabled services = {\n\t\t\"\(label)\" => enabled\n\t}")
        let malformedOverride = result(0, "disabled services = {\n\" => enabled\n}")
        suite.expect(LaunchItemsSupport.disabledOverrides(uid: 501, run: { _ in malformedOverride }) == nil,
                     "a row with only a closing quote is unknown, not a parser trap")
        suite.expect(runAction(.disableAtLogin, replies: [loaded(), noOverrides, result(), overriddenDisabled])
                     && commands == [printService, printDisabled, ["disable", target], printDisabled],
                     "persistent disable uses and verifies an explicit login override")
        suite.expect(runAction(.disableAtLogin, replies: [unloaded, noOverrides, result(), overriddenDisabled])
                     && commands == [printService, printDisabled, ["disable", target], printDisabled],
                     "preventing future loads does not start an unloaded, separately ownership-checked service")
        suite.expect(runAction(.enableAtLogin, replies: [unloaded, overriddenDisabled, result(), overriddenEnabled])
                     && commands == [printService, printDisabled, ["enable", target], printDisabled],
                     "persistent enable does not silently bootstrap a service")
        suite.expect(!runAction(.disableAtLogin, replies: [loaded(), noOverrides, result(), noOverrides]),
                     "persistent command success without a verified override is inconclusive")
    }

    private static func verifyOwnedPlist(_ suite: TestSuite) {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let folder = home.appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        let plist = folder.appendingPathComponent("agent.plist")
        let link = folder.appendingPathComponent("link.plist")
        defer { try? fileManager.removeItem(at: home) }
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data([0]).write(to: plist)
            let original = LaunchItemsSupport.ownedPlistIdentity(plist, home: home, uid: getuid())
            suite.expect(original != nil, "the selected regular plist belongs to its user")
            try Data([0, 1]).write(to: plist, options: .atomic)
            suite.expect(LaunchItemsSupport.ownedPlistIdentity(plist, home: home, uid: getuid()) != original,
                         "a replacement at the same path invalidates the initial identity")
            try fileManager.createSymbolicLink(at: link, withDestinationURL: plist)
            suite.expect(LaunchItemsSupport.ownedPlistIdentity(link, home: home, uid: getuid()) == nil,
                         "a symbolic link cannot authorize an operation even if its destination is an owned plist")
        } catch {
            suite.expect(false, "the launch-item ownership fixture could not be created: \(error)")
        }
    }

    private static func verifyPersistentPeerGuard(_ suite: TestSuite) {
        let files = FileManager.default
        let root = files.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let home = root.appendingPathComponent("User", isDirectory: true)
        let userFolder = home.appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        let uid = getuid()
        let folders = LaunchItemsSupport.AgentFolders(
            local: root.appendingPathComponent("LocalAgents", isDirectory: true),
            system: root.appendingPathComponent("SystemAgents", isDirectory: true),
            cryptex: root.appendingPathComponent("CryptexAgents", isDirectory: true),
            systemOwner: uid)
        let lookalike = root.appendingPathComponent("CryptexAgents-Untrusted", isDirectory: true)
        let selected = userFolder.appendingPathComponent("selected.plist")
        let systemLink = folders.system.appendingPathComponent("apple.plist")
        let applePlist = folders.cryptex.appendingPathComponent("apple.plist")
        let userLink = userFolder.appendingPathComponent("linked.plist")
        let localLink = folders.local.appendingPathComponent("linked.plist")
        let label = "com.vendor.confirmed"
        let domain = "gui/\(uid)"
        let target = "\(domain)/\(label)"
        defer { try? files.removeItem(at: root) }

        func write(_ label: String, to url: URL) throws {
            let plist = try PropertyListSerialization.data(fromPropertyList: ["Label": label],
                                                           format: .xml,
                                                           options: 0)
            try plist.write(to: url)
            try files.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
        }

        do {
            for folder in [userFolder, folders.local, folders.system, folders.cryptex, lookalike] {
                try files.createDirectory(at: folder, withIntermediateDirectories: true)
            }
            try write(label, to: selected)
            try write("com.apple.unrelated", to: applePlist)
            try files.createSymbolicLink(atPath: systemLink.path,
                                         withDestinationPath: "../CryptexAgents/apple.plist")

            guard let selectedIdentity = LaunchItemsSupport.ownedPlistIdentity(selected, home: home, uid: uid) else {
                suite.expect(false, "the persistent-peer fixture must own its selected regular file")
                return
            }
            func attempt(_ action: LaunchItemsSupport.Action, url: URL, owner: uid_t,
                         folders: LaunchItemsSupport.AgentFolders) -> (success: Bool, commands: [[String]]) {
                var overridesDisabled = action == .enableAtLogin
                let item = LaunchItem(url: url, label: label, program: nil, scope: .userAgent,
                                      state: .unloaded, disabledAtLogin: overridesDisabled,
                                      plistIdentity: selectedIdentity)
                var commands: [[String]] = []
                let success = LaunchItemsSupport.perform(action, on: item, home: home, uid: owner,
                                                         folders: folders, run: { command in
                    commands.append(command)
                    let output: String
                    switch command {
                    case ["print", target]:
                        return .init(status: 113,
                                     output: Data("Could not find service \"\(label)\" in domain for user gui: \(uid)".utf8))
                    case ["print-disabled", domain]:
                        let state = overridesDisabled ? "disabled" : "enabled"
                        output = "disabled services = {\n\"\(label)\" => \(state)\n}"
                    case ["enable", target], ["disable", target]:
                        overridesDisabled = command.first == "disable"
                        output = ""
                    default: return .init(status: 112, output: Data())
                    }
                    return .init(status: 0, output: Data(output.utf8))
                })
                return (success, commands)
            }
            func expectRefusal(_ message: String) {
                let transaction = attempt(.disableAtLogin, url: selected, owner: uid, folders: folders)
                suite.expect(!transaction.success && transaction.commands.isEmpty, message)
            }

            let actions: [(LaunchItemsSupport.Action, String)] = [(.disableAtLogin, "disable"),
                                                                  (.enableAtLogin, "enable")]
            for (action, verb) in actions {
                let transaction = attempt(action, url: selected, owner: uid, folders: folders)
                suite.expect(transaction.success
                             && transaction.commands == [["print", target], ["print-disabled", domain],
                                                          [verb, target], ["print-disabled", domain]],
                             "an unrelated trusted Cryptex peer allows verified same-domain \(verb)")
            }

            try write(label, to: applePlist)
            expectRefusal("a duplicate label behind a trusted system link cannot be changed")
            try write("com.apple.unrelated", to: applePlist)
            try files.setAttributes([.posixPermissions: 0o666], ofItemAtPath: applePlist.path)
            expectRefusal("a group- or other-writable Cryptex target is not trusted")
            try files.setAttributes([.posixPermissions: 0o644], ofItemAtPath: applePlist.path)
            try files.createSymbolicLink(at: localLink, withDestinationURL: applePlist)
            expectRefusal("a local LaunchAgents peer cannot use the system-only link exception")
            try files.removeItem(at: localLink)
            try files.createSymbolicLink(at: userLink, withDestinationURL: applePlist)
            expectRefusal("a user LaunchAgents peer cannot use the system-only link exception")
            try files.removeItem(at: userLink)

            let outside = lookalike.appendingPathComponent("apple.plist")
            try files.removeItem(at: systemLink)
            try write("com.apple.unrelated", to: outside)
            try files.createSymbolicLink(at: systemLink, withDestinationURL: outside)
            expectRefusal("a prefix lookalike outside the Cryptex directory is not trusted")
            try files.removeItem(at: systemLink)
            try files.createSymbolicLink(at: systemLink, withDestinationURL: applePlist)
            try Data("invalid plist".utf8).write(to: applePlist)
            expectRefusal("a trusted link with an unparseable target fails closed")
            try files.removeItem(at: applePlist)
            expectRefusal("an unresolved system link fails closed")
            try write("com.apple.unrelated", to: applePlist)

            let wrongOwner = attempt(.disableAtLogin, url: selected, owner: uid == 0 ? 1 : 0, folders: folders)
            suite.expect(!wrongOwner.success && wrongOwner.commands.isEmpty,
                         "the confirmed plist must belong to the effective fixture user")
            try files.moveItem(at: selected, to: userLink)
            try files.createSymbolicLink(at: selected, withDestinationURL: userLink)
            expectRefusal("a symlink at the confirmed target path cannot authorize persistent changes")
        } catch {
            suite.expect(false, "the persistent-peer launch-item fixture failed: \(error)")
        }
    }
}
