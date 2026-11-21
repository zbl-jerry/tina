// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// Putting entries into a root-owned system file is the risky part of hosts
/// profiles, so validation, block composition and backup retention are pure
/// functions and pinned here without touching `/etc/hosts`.
enum HostsProfilesTests {
    private static func profile(_ content: String,
                                enabled: Bool = true,
                                name: String = "Test") -> HostsProfile {
        HostsProfile(name: name, content: content, isEnabled: enabled)
    }

    private static func reasons(_ content: String) -> [HostsValidationIssue.Reason] {
        HostsProfilesSupport.validate(profile(content)).map(\.reason)
    }

    static func run(_ suite: TestSuite) {
        // MARK: Valid input

        let valid = """
        # Local overrides

        127.0.0.1 localhost
        127.0.0.1 api.local app.local # inline comment
        10.0.0.5 gateway.internal.
        """.replacingOccurrences(of: "gateway.internal.", with: "gateway.internal")
        suite.expect(HostsProfilesSupport.validate(profile(valid)).isEmpty,
                     "IPv4 entries, comments, blank lines and inline comments validate")
        suite.expect(HostsProfilesSupport.validate(profile(
            "::1 localhost\nfe80::1%lo0 localhost\n2001:db8::1 service.example")).isEmpty,
                     "IPv6, scoped IPv6 and multiple host names validate")
        suite.expect(HostsProfilesSupport.validate(profile(
            "  127.0.0.1\tspaced.local   ")).isEmpty,
                     "tabs and surrounding whitespace are accepted")
        suite.expect(HostsProfilesSupport.validate(profile("")).isEmpty,
                     "an empty profile is valid, it just contributes nothing")

        // MARK: Invalid addresses and host names

        suite.expect(reasons("999.1.1.1 api") == [.invalidAddress],
                     "an out-of-range IPv4 address is rejected")
        suite.expect(reasons("1.2.3 api") == [.invalidAddress],
                     "an incomplete IPv4 address is rejected")
        suite.expect(reasons("127.0.0.1") == [.missingHostname],
                     "an address with no host name is rejected")
        suite.expect(reasons("127.0.0.1 bad/host") == [.invalidHostname],
                     "a slash in a host name is rejected")
        suite.expect(reasons("127.0.0.1 a..b") == [.invalidHostname],
                     "empty labels are rejected")
        suite.expect(reasons("127.0.0.1 -bad.example") == [.invalidHostname],
                     "a label cannot start with a hyphen")
        suite.expect(reasons("127.0.0.1 bad-.example") == [.invalidHostname],
                     "a label cannot end with a hyphen")
        suite.expect(reasons("127.0.0.1 *.example.com") == [.invalidHostname],
                     "wildcards are rejected")

        for injected in ["evil;rm -rf /", "foo>bar", "$(whoami)", "`id`",
                         "../../etc/passwd", "a|b", "a&b", "a\nb"] {
            let issues = reasons("127.0.0.1 \(injected)")
            suite.expect(!issues.isEmpty, "\(injected.debugDescription) never validates")
        }

        suite.expect(reasons("127.0.0.1 api\u{0007}.local") == [.controlCharacter],
                     "a control character is reported, not pasted through")
        suite.expect(reasons(HostsProfilesSupport.managedBlockStart) == [.reservedMarker],
                     "a pasted managed block marker is refused")
        suite.expect(reasons(HostsProfilesSupport.managedBlockEnd) == [.reservedMarker],
                     "a pasted managed block end marker is refused")
        suite.expect(reasons("127.0.0.1 " + String(repeating: "a", count: 2000)) == [.lineTooLong],
                     "an overlong line is refused")
        suite.expect(reasons(String(repeating: "127.0.0.1 a\n", count: 20_000)).first == .contentTooLarge,
                     "an overlong profile is refused before line parsing")

        // MARK: Direct address and host-name checks

        for address in ["0.0.0.0", "255.255.255.255", "::", "::1", "fd00::1",
                        "2001:db8::1", "fe80::1%en0", "fe80::1%lo0"] {
            suite.expect(HostsProfilesSupport.isValidAddress(address),
                         "\(address) is a valid address")
        }
        for address in ["", "1.2.3", "256.1.1.1", "1.2.3.4.5", "example.com",
                        "fe80::1%", "fe80::1%en 0", "::gg"] {
            suite.expect(!HostsProfilesSupport.isValidAddress(address),
                         "\(address.debugDescription) is not a valid address")
        }
        for host in ["example.com", "api", "a_b", "API.LOCAL", "xn--bcher-kva.example"] {
            suite.expect(HostsProfilesSupport.isValidHostname(host), "\(host) is a valid host name")
        }
        for host in ["", "a..b", "-a", "a-", ".a", "a.", "a b", "a/b", "a:b",
                     "*.example.com", String(repeating: "a", count: 254)] {
            suite.expect(!HostsProfilesSupport.isValidHostname(host),
                         "\(host.debugDescription) is not a valid host name")
        }

        // MARK: Managed block

        let local = profile("127.0.0.1 api.local\n127.0.0.1 app.local", name: "Local")
        let staging = profile("10.0.0.5 api.example.com", name: "Staging")
        let disabled = profile("192.168.1.10 ignored.local", enabled: false, name: "Disabled")
        let block = HostsProfilesSupport.managedBlock(for: [local, staging, disabled])
        suite.expect(block.hasPrefix(HostsProfilesSupport.managedBlockStart + "\n"),
                     "the block opens with the reserved marker")
        suite.expect(block.hasSuffix(HostsProfilesSupport.managedBlockEnd + "\n"),
                     "the block closes with the reserved marker")
        suite.expect(block.contains("# === Local ===\n127.0.0.1 api.local\n127.0.0.1 app.local"),
                     "enabled profiles keep their order and name")
        suite.expect(block.contains("# === Staging ===\n10.0.0.5 api.example.com"),
                     "the second enabled profile follows the first")
        suite.expect(!block.contains("ignored.local"),
                     "a disabled profile is not written")
        suite.expect(HostsProfilesSupport.managedBlock(for: [disabled]).isEmpty,
                     "with nothing enabled there is no block")

        suite.expect(HostsProfilesSupport.effectiveLineCount(of: block) == 3,
                     "only mapping lines count as active, not headers or comments")

        // Applying keeps the rest of the system file byte-identical.
        let system = "127.0.0.1 localhost\n255.255.255.255 broadcasthost\n"
        let applied = HostsProfilesSupport.applying(block: block, to: system)
        suite.expect(applied?.hasPrefix(system) == true,
                     "the system's own lines stay at the top of the file")
        suite.expect(applied?.contains(HostsProfilesSupport.managedBlockStart) == true,
                     "the managed block is appended")
        suite.expect(HostsProfilesSupport.removingManagedBlock(from: applied ?? "") == system,
                     "removing the block returns the original file")

        // Reapplying replaces the old block instead of stacking a second one.
        let replacement = HostsProfilesSupport.managedBlock(for: [staging])
        let reapplied = HostsProfilesSupport.applying(block: replacement, to: applied ?? "")
        suite.expect(reapplied?.components(separatedBy: HostsProfilesSupport.managedBlockStart).count == 2,
                     "a second apply leaves exactly one managed block")
        suite.expect(reapplied?.contains("api.local") == false
                && reapplied?.contains("10.0.0.5 api.example.com") == true,
                     "the new block replaces the old contents")
        suite.expect(reapplied?.contains("127.0.0.1 localhost") == true,
                     "reapplying still keeps the system's own lines")

        // Clearing: an empty block removes the managed section only.
        let cleared = HostsProfilesSupport.applying(block: "", to: reapplied ?? "")
        suite.expect(cleared == system,
                     "clearing the block restores the file without touching other lines")

        // Unbalanced or stray markers refuse to proceed.
        let unbalanced = "127.0.0.1 localhost\n\(HostsProfilesSupport.managedBlockStart)\n1.1.1.1 a\n"
        suite.expect(HostsProfilesSupport.removingManagedBlock(from: unbalanced) == nil,
                     "an unterminated managed block is refused")
        suite.expect(HostsProfilesSupport.applying(block: block, to: unbalanced) == nil,
                     "no write is offered over an unterminated block")
        let stray = "127.0.0.1 localhost\n\(HostsProfilesSupport.managedBlockEnd)\n"
        suite.expect(HostsProfilesSupport.removingManagedBlock(from: stray) == nil,
                     "a stray end marker is refused")

        // CRLF input is normalized before it reaches the block.
        let crlf = HostsProfilesSupport.managedBlock(for: [profile("1.1.1.1 a\r\n2.2.2.2 b\r\n")])
        suite.expect(!crlf.contains("\r"), "CRLF content is normalized to LF")

        // Derived state.
        suite.expect(HostsProfilesSupport.isApplied(currentHosts: applied ?? "",
                                                    profiles: [local, staging, disabled]),
                     "the file matches the enabled profiles after applying")
        suite.expect(!HostsProfilesSupport.isApplied(currentHosts: applied ?? "",
                                                     profiles: [staging]),
                     "changing the enabled set makes the state not applied")
        suite.expect(HostsProfilesSupport.managedBlock(in: applied ?? "") == block,
                     "the block can be read back from the file")

        // Signature: stable and sensitive to content.
        suite.expect(HostsProfilesSupport.signature(block) == HostsProfilesSupport.signature(block),
                     "the same block has the same signature")
        suite.expect(HostsProfilesSupport.signature(block) != HostsProfilesSupport.signature(replacement),
                     "a different block has a different signature")

        // MARK: Backup naming and retention

        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let first = HostsProfilesSupport.backupFileName(at: base, reason: "apply")
        let second = HostsProfilesSupport.backupFileName(
            at: base.addingTimeInterval(1.5), reason: "restore")
        suite.expect(first < second, "backup names sort by time")
        suite.expect(first.hasPrefix("hosts-") && first.hasSuffix("-apply.bak"),
                     "an apply backup is named for what it preceded")
        suite.expect(second.hasSuffix("-restore.bak"),
                     "a restore backup is named for what it preceded")

        let names = (0..<14).map { "hosts-20260101-0000\(String(format: "%02d", $0))-000-x.bak" }
        let deleted = HostsProfilesSupport.backupsToDelete(names, keeping: 10)
        suite.expect(deleted == Array(names.prefix(4)),
                     "retention removes the four oldest and keeps the newest ten")
        suite.expect(HostsProfilesSupport.backupsToDelete(names, keeping: 20).isEmpty,
                     "retention does nothing while the count fits")

        // MARK: Stored format

        let stored = [local, disabled]
        let encoded = HostsProfilesSupport.encodeProfiles(stored) ?? ""
        suite.expect(HostsProfilesSupport.decodeProfiles(encoded) == stored,
                     "profiles round-trip through the stored JSON")
        suite.expect(HostsProfilesSupport.decodeProfiles(nil).isEmpty
                && HostsProfilesSupport.decodeProfiles("not json").isEmpty,
                     "missing or corrupt stored data reads as an empty list")

        // MARK: Copy

        var fields = 0
        for language in AppLanguage.allCases {
            let strings = FeatureStrings.hostsProfiles(language)
            let values = Mirror(reflecting: strings).children.compactMap { $0.value as? String }
            fields = values.count
            suite.expect(values.allSatisfy { !$0.isEmpty },
                         "every hosts profile string is filled in \(language.rawValue)")
            suite.expect(values.allSatisfy { !$0.contains("\u{2014}") },
                         "no em-dash in visible hosts profile copy (\(language.rawValue))")
            suite.expect(strings.adminPrompt.contains("%") == false,
                         "the administrator prompt has no unbound format placeholders (\(language.rawValue))")
        }
        suite.expect(fields >= 40, "the strings set is complete, got \(fields) fields")
        suite.expect(FeatureStrings.hostsProfiles(.zhHans).title != FeatureStrings.hostsProfiles(.enUS).title,
                     "the Chinese title is translated")

        // MARK: Defaults

        suite.expect(Defaults.registeredDefaults[DefaultsKey.panelUtilityHostsProfiles] as? Bool == true,
                     "the hosts row ships visible like its siblings")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.hostsProfilesData] as? String == "",
                     "an empty profile list is the registered default")
        suite.expect(!SettingsBackupSupport.exportKeys().isDisjoint(with: [DefaultsKey.hostsProfilesData]),
                     "profiles travel in settings backups")
    }
}
