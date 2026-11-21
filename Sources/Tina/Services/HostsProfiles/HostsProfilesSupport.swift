// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Darwin
import Foundation

/// One named hosts fragment. Only enabled profiles are written to the system
/// file, in list order. The model is Codable so the whole list travels as one
/// JSON string and participates in settings backups.
struct HostsProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var content: String
    var isEnabled: Bool

    init(id: UUID = UUID(), name: String, content: String = "", isEnabled: Bool = false) {
        self.id = id
        self.name = name
        self.content = content
        self.isEnabled = isEnabled
    }
}

/// A rejected line. Validation is pure and runs before any authorization, so
/// a bad edit can never reach `/etc/hosts`.
struct HostsValidationIssue: Equatable {
    enum Reason: Equatable {
        case invalidAddress
        case missingHostname
        case invalidHostname
        case controlCharacter
        case lineTooLong
        case contentTooLarge
        case reservedMarker
    }

    let profileID: UUID
    let profileName: String
    /// 1-based line number, or 0 for a whole-profile problem.
    let lineNumber: Int
    let reason: Reason
}

/// Everything about hosts profiles that can be decided without touching the
/// disk: parsing, validation, the managed block and its signature. The service
/// adds persistence and the privileged write around this.
enum HostsProfilesSupport {
    static let managedBlockStart = "# >>> Tina hosts profiles >>>"
    static let managedBlockEnd = "# <<< Tina hosts profiles <<<"

    static let maxProfiles = 100
    static let maxContentBytes = 128 * 1024
    static let maxLineLength = 1024
    static let maxBackups = 10

    // MARK: - Validation

    static func validate(_ profiles: [HostsProfile]) -> [HostsValidationIssue] {
        profiles.flatMap(validate)
    }

    static func validate(_ profile: HostsProfile) -> [HostsValidationIssue] {
        var issues: [HostsValidationIssue] = []
        func reject(_ line: Int, _ reason: HostsValidationIssue.Reason) {
            issues.append(HostsValidationIssue(profileID: profile.id,
                                               profileName: profile.name,
                                               lineNumber: line,
                                               reason: reason))
        }

        if profile.content.utf8.count > maxContentBytes {
            reject(0, .contentTooLarge)
            return issues
        }

        for (index, rawLine) in profile.content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated() {
            var line = String(rawLine)
            if line.hasSuffix("\r") { line.removeLast() }
            let number = index + 1

            if line.count > maxLineLength {
                reject(number, .lineTooLong)
                continue
            }
            if line.unicodeScalars.contains(where: {
                ($0.value < 0x20 && $0.value != 0x09) || $0.value == 0x7f
            }) {
                reject(number, .controlCharacter)
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("#") {
                // A pasted marker would split or duplicate the managed block.
                if trimmed == managedBlockStart || trimmed == managedBlockEnd {
                    reject(number, .reservedMarker)
                }
                continue
            }

            // Everything from an unescaped # onward is a comment, as in the
            // system's own parser. A line of only a comment was handled above.
            let code = trimmed.split(separator: "#", maxSplits: 1,
                                     omittingEmptySubsequences: false)
                .first.map(String.init) ?? ""
            let tokens = code.split(whereSeparator: { $0 == " " || $0 == "\t" })
                .map(String.init)
            guard let address = tokens.first else { continue }

            if !isValidAddress(address) {
                reject(number, .invalidAddress)
                continue
            }
            guard tokens.count >= 2 else {
                reject(number, .missingHostname)
                continue
            }
            if tokens.dropFirst().contains(where: { !isValidHostname($0) }) {
                reject(number, .invalidHostname)
            }
        }
        return issues
    }

    /// IPv4 or IPv6, optionally with an IPv6 scope zone such as `%lo0`.
    /// `inet_pton` rejects everything else, which is also what keeps shell
    /// metacharacters, redirections and paths out of the written file.
    static func isValidAddress(_ token: String) -> Bool {
        var address = token
        if let percent = address.firstIndex(of: "%") {
            let zone = String(address[address.index(after: percent)...])
            guard !zone.isEmpty, zone.allSatisfy({
                $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == ".")
            }) else { return false }
            address = String(address[..<percent])
        }
        guard !address.isEmpty else { return false }
        var v4 = in_addr()
        var v6 = in6_addr()
        if inet_pton(AF_INET, address, &v4) == 1 { return true }
        if inet_pton(AF_INET6, address, &v6) == 1 { return true }
        return false
    }

    /// ASCII host names only. This deliberately rejects whitespace, `#`, `;`,
    /// `$`, backticks, quotes, slashes and every other character that could be
    /// read as structure by a parser or a shell.
    static func isValidHostname(_ token: String) -> Bool {
        guard !token.isEmpty, token.count <= 253 else { return false }
        let allowed = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        guard token.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        guard token.first != "-", token.first != "." else { return false }
        guard token.last != "-", token.last != "." else { return false }
        // Every label obeys the same rule, not only the whole name, so
        // `bad-.example` cannot slip through on the middle label.
        return !token.split(separator: ".", omittingEmptySubsequences: false).contains { label in
            label.isEmpty || label.first == "-" || label.last == "-"
        }
    }

    // MARK: - Managed block

    /// The enabled profiles as one block, terminated by a newline. Empty when
    /// nothing is enabled: applying that removes the block and leaves the rest
    /// of the file untouched.
    static func managedBlock(for profiles: [HostsProfile]) -> String {
        let enabled = profiles.filter(\.isEnabled).filter {
            !normalizedContent($0.content).isEmpty
        }
        guard !enabled.isEmpty else { return "" }

        var lines = [managedBlockStart]
        for profile in enabled {
            lines.append("# === \(displayName(profile)) ===")
            lines.append(contentsOf: normalizedContent(profile.content))
        }
        lines.append(managedBlockEnd)
        return lines.joined(separator: "\n") + "\n"
    }

    /// A name safe to place inside a single comment line.
    static func displayName(_ profile: HostsProfile) -> String {
        let flattened = profile.name
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespaces)
        let safe = String(flattened.unicodeScalars.filter { $0.value >= 0x20 && $0.value != 0x7f })
        return safe.isEmpty ? "Hosts" : safe
    }

    /// The profile's own lines with CRLF and trailing whitespace normalized.
    /// Leading and trailing blank lines are dropped so applies stay byte-stable.
    static func normalizedContent(_ content: String) -> [String] {
        var lines = content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                var value = String(line)
                if value.hasSuffix("\r") { value.removeLast() }
                while value.last == " " || value.last == "\t" { value.removeLast() }
                return value
            }
        while let first = lines.first, first.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeFirst()
        }
        while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeLast()
        }
        return lines
    }

    /// The block currently present in a hosts file, or nil when there is none.
    /// An unmatched start or end marker is treated as no usable block.
    static func managedBlock(in hosts: String) -> String? {
        let lines = hosts.components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == managedBlockStart
        }),
        let end = lines[start...].firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == managedBlockEnd
        }),
        end > start else { return nil }
        return lines[start...end].joined(separator: "\n") + "\n"
    }

    /// A hosts file with every managed block removed. nil when a block is
    /// unbalanced, so the caller refuses to write over a file it cannot
    /// reconstruct safely. A stray end marker also refuses.
    static func removingManagedBlock(from hosts: String) -> String? {
        var lines = hosts.components(separatedBy: "\n")
        var index = 0
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed == managedBlockStart {
                guard let end = lines[index...].firstIndex(where: {
                    $0.trimmingCharacters(in: .whitespaces) == managedBlockEnd
                }), end > index else { return nil }
                // `applying` adds one separator line before the block, so
                // removing that line too makes apply and clear symmetrical.
                let start = index > 0
                    && lines[index - 1].trimmingCharacters(in: .whitespaces).isEmpty
                    ? index - 1 : index
                lines.removeSubrange(start...end)
                index = start
                continue
            }
            if trimmed == managedBlockEnd { return nil }
            index += 1
        }
        return lines.joined(separator: "\n")
    }

    /// Removes any old block, appends the new one, and keeps every line the
    /// managed block does not own. nil when the existing file cannot be
    /// parsed safely.
    static func applying(block: String, to hosts: String) -> String? {
        guard let base = removingManagedBlock(from: hosts) else { return nil }
        let trimmed = trimmingTrailingNewlines(base)
        if block.isEmpty {
            return trimmed.isEmpty ? "" : trimmed + "\n"
        }
        return (trimmed.isEmpty ? "" : trimmed + "\n\n") + block
    }

    private static func trimmingTrailingNewlines(_ value: String) -> String {
        var result = value
        while result.hasSuffix("\n") || result.hasSuffix("\r") { result.removeLast() }
        return result
    }

    /// Enabled, non-empty mapping lines, the number the panel reports.
    static func effectiveLineCount(of block: String) -> Int {
        block.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.isEmpty && !trimmed.hasPrefix("#")
        }.count
    }

    /// Whether the file's managed block already matches the enabled profiles.
    /// Derived from the file, not from a stored flag, so it can never claim an
    /// apply that did not land.
    static func isApplied(currentHosts: String, profiles: [HostsProfile]) -> Bool {
        let expected = managedBlock(for: profiles)
        let actual = managedBlock(in: currentHosts) ?? ""
        return expected == actual
    }

    /// FNV-1a over the block. Change detection only, not a security primitive.
    static func signature(_ text: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }

    // MARK: - Backups

    /// Sortable to the second and unique within it.
    static func backupFileName(at date: Date, reason: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return "hosts-\(formatter.string(from: date))-\(reason).bak"
    }

    /// Oldest first; names share one sortable format.
    static func backupsToDelete(_ names: [String], keeping limit: Int) -> [String] {
        guard names.count > limit else { return [] }
        return Array(names.sorted().prefix(names.count - limit))
    }

    // MARK: - Persistence format

    static func decodeProfiles(_ stored: String?) -> [HostsProfile] {
        guard let stored, let data = stored.data(using: .utf8),
              let profiles = try? JSONDecoder().decode([HostsProfile].self, from: data)
        else { return [] }
        return profiles
    }

    static func encodeProfiles(_ profiles: [HostsProfile]) -> String? {
        guard let data = try? JSONEncoder().encode(profiles) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
