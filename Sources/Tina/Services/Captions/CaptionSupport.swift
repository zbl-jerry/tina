// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// One finalized line of a caption session, timed on the session's own clock.
/// A session starts at zero when listening starts, so a recording made hours
/// after the session began still exports a subtitle that starts at 00:00.
struct CaptionSegment: Codable, Equatable, Identifiable {
    var id: UUID
    var start: TimeInterval
    var end: TimeInterval
    var text: String

    init(id: UUID = UUID(), start: TimeInterval, end: TimeInterval, text: String) {
        let safeStart = start.isFinite ? max(0, start) : 0
        let safeEnd = end.isFinite ? max(safeStart, end) : safeStart
        self.id = id
        self.start = safeStart
        self.end = safeEnd
        self.text = CaptionSupport.normalizedText(text)
    }

    var isEmpty: Bool { text.isEmpty }
}

/// Everything one listening run produced. It is written as JSON beside the
/// other sessions; nothing in it leaves the Mac.
struct CaptionSession: Codable, Equatable, Identifiable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var localeIdentifier: String
    var segments: [CaptionSegment]

    init(id: UUID = UUID(), startedAt: Date = Date(), endedAt: Date? = nil,
         localeIdentifier: String, segments: [CaptionSegment] = []) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.localeIdentifier = localeIdentifier
        self.segments = segments
    }

    /// The length of the spoken part, which is what the session row shows.
    /// A session stopped before its first final line has no duration yet.
    var duration: TimeInterval {
        let lastEnd = segments.map(\.end).max() ?? 0
        if lastEnd > 0 { return lastEnd }
        return max(0, endedAt?.timeIntervalSince(startedAt) ?? 0)
    }

    var spokenText: String {
        segments.map(\.text).filter { !$0.isEmpty }.joined(separator: " ")
    }

    var hasContent: Bool { segments.contains { !$0.isEmpty } }
}

enum CaptionExportFormat: String, CaseIterable, Identifiable, Codable {
    case srt
    case markdown
    case plainText

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .srt: return "srt"
        case .markdown: return "md"
        case .plainText: return "txt"
        }
    }
}

/// The text decisions the caption feature makes, kept apart from Speech and
/// AppKit so they can be checked without a microphone or a window.
enum CaptionSupport {
    /// The most a single recognition request is left running. The system
    /// engine ends long requests on its own; rotating before that gives a
    /// clean final line instead of a mid-word cutoff.
    static let recognitionRequestSeconds: TimeInterval = 50

    /// Voice activity that keeps a line on screen before it fades.
    static let silenceFadeSeconds: TimeInterval = 6

    static let fontSizeRange = 12.0...36.0
    static let maxLinesRange = 1...4

    static func sanitizedFontSize(_ value: Double) -> Double {
        guard value.isFinite else { return 20 }
        return min(fontSizeRange.upperBound, max(fontSizeRange.lowerBound, value.rounded()))
    }

    static func sanitizedMaxLines(_ value: Int) -> Int {
        min(maxLinesRange.upperBound, max(maxLinesRange.lowerBound, value))
    }

    static func normalizedText(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Speech's own comparison key: case and punctuation do not make a line
    /// new, but extra words do.
    static func speechKey(_ text: String) -> String {
        normalizedText(text).lowercased().filter {
            $0.isLetter || $0.isNumber || $0 == " "
        }
    }

    /// Appends finalized lines without repeating one the engine already
    /// reported. Around a request restart the engine emits the same sentence
    /// twice, sometimes with the punctuation the second copy added; the
    /// session should read it once. A copy that continues the previous line
    /// replaces it instead of stacking a prefix in front of it.
    static func appending(_ incoming: [CaptionSegment], to existing: [CaptionSegment]) -> [CaptionSegment] {
        var result = existing
        for segment in incoming where !segment.isEmpty {
            guard let last = result.last, segment.start >= last.start else {
                result.append(segment)
                continue
            }
            let oldKey = speechKey(last.text)
            let newKey = speechKey(segment.text)
            if oldKey == newKey {
                result[result.count - 1].end = max(last.end, segment.end)
                continue
            }
            if !oldKey.isEmpty, newKey.hasPrefix(oldKey) {
                result[result.count - 1].text = segment.text
                result[result.count - 1].end = max(last.end, segment.end)
                continue
            }
            result.append(segment)
        }
        return result
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// SRT's comma before the milliseconds is the format, not a locale choice.
    static func srtTimestamp(_ seconds: TimeInterval) -> String {
        let clamped = max(0, seconds)
        let milliseconds = Int((clamped - clamped.rounded(.down)) * 1000)
        let total = Int(clamped.rounded(.down))
        return String(format: "%02d:%02d:%02d,%03d",
                      total / 3600, (total % 3600) / 60, total % 60,
                      min(999, max(0, milliseconds)))
    }

    static func srt(_ session: CaptionSession) -> String {
        var lines: [String] = []
        var index = 1
        for segment in session.segments where !segment.isEmpty {
            let start = srtTimestamp(segment.start)
            let end = srtTimestamp(max(segment.start + 0.001, segment.end))
            lines.append("\(index)")
            lines.append("\(start) --> \(end)")
            lines.append(segment.text)
            lines.append("")
            index += 1
        }
        guard !lines.isEmpty else { return "" }
        return lines.joined(separator: "\n") + "\n"
    }

    static func markdown(_ session: CaptionSession, locale: Locale = .current,
                         timeZone: TimeZone = .current) -> String {
        var lines: [String] = []
        let startFormatter = DateFormatter()
        startFormatter.locale = locale
        startFormatter.timeZone = timeZone
        startFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        lines.append("# \(CaptionSupport.sessionTitle(session, locale: locale, timeZone: timeZone))")
        lines.append("")
        lines.append("- \(CaptionSupport.clock(session.duration))")
        lines.append("")
        for segment in session.segments where !segment.isEmpty {
            lines.append("- **[\(clock(segment.start))]** \(segment.text)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func plainText(_ session: CaptionSession) -> String {
        let lines = session.segments.filter { !$0.isEmpty }.map(\.text)
        guard !lines.isEmpty else { return "" }
        return lines.joined(separator: "\n") + "\n"
    }

    static func export(_ session: CaptionSession, as format: CaptionExportFormat,
                       locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        switch format {
        case .srt: return srt(session)
        case .markdown: return markdown(session, locale: locale, timeZone: timeZone)
        case .plainText: return plainText(session)
        }
    }

    /// "Live Captions 2026-11-22 14.32.05". Colons are legal on APFS but
    /// Finder shows them as slashes, so the name uses dots for the clock.
    static func exportBaseName(_ session: CaptionSession, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "Live Captions \(formatter.string(from: session.startedAt))"
    }

    static func sessionTitle(_ session: CaptionSession, locale: Locale = .current,
                             timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: session.startedAt)
    }

    /// Speech segments measured from the start of one recognition request,
    /// moved onto the session's clock. A result without segment timing still
    /// gets one line covering the time since the previous line ended.
    static func segments(from pieces: [CaptionSpeechSegment],
                         base: TimeInterval,
                         measuredFrom lastEnd: TimeInterval) -> [CaptionSegment] {
        var result: [CaptionSegment] = []
        for piece in pieces {
            let text = normalizedText(piece.text)
            guard !text.isEmpty else { continue }
            let start = base + max(0, piece.timestamp)
            let end = start + max(0.05, piece.duration)
            result.append(CaptionSegment(start: start, end: end, text: text))
        }
        if result.isEmpty { return [] }
        // A first segment that starts before the previous one ended would
        // only happen after a rotation; keep the timeline readable.
        if let first = result.first, first.start < lastEnd {
            let shift = lastEnd - first.start
            result = result.map {
                CaptionSegment(id: $0.id, start: $0.start + shift, end: $0.end + shift, text: $0.text)
            }
        }
        return result
    }

    /// One line for a result the engine returned without usable timing, such
    /// as its final flush when a request is closed.
    static func fallbackSegment(text: String, start: TimeInterval, end: TimeInterval) -> CaptionSegment? {
        let normalized = normalizedText(text)
        guard !normalized.isEmpty else { return nil }
        let safeEnd = end > start ? end : start + 0.5
        return CaptionSegment(start: start, end: safeEnd, text: normalized)
    }

    static func shouldRotate(requestStartedAt: Date, now: Date = Date(),
                             limit: TimeInterval = recognitionRequestSeconds) -> Bool {
        now.timeIntervalSince(requestStartedAt) >= limit
    }
}

/// A piece of Speech's own result, reduced to what the caption timeline needs.
struct CaptionSpeechSegment: Equatable {
    let timestamp: TimeInterval
    let duration: TimeInterval
    let text: String
}

/// Reads and writes sessions in one folder. The default folder is inside the
/// app's Application Support directory; a chosen folder is read and written
/// through the bookmark its chooser stored.
struct CaptionSessionStore {
    let directory: URL
    private let fileManager: FileManager

    init(directory: URL = CaptionSessionStore.defaultDirectory,
         fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tina", isDirectory: true)
            .appendingPathComponent("Captions", isDirectory: true)
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Writes the session, or nothing when it holds no finalized line. An
    /// interrupted or permission-less run must never leave an empty file
    /// that looks like a session.
    @discardableResult
    func save(_ session: CaptionSession) throws -> URL? {
        guard session.hasContent else { return nil }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName(for: session))
        let data = try Self.encoder().encode(session)
        try data.write(to: url, options: .atomic)
        return url
    }

    func loadAll(limit: Int? = nil) -> [CaptionSession] {
        let urls = (try? fileManager.contentsOfDirectory(at: directory,
                                                         includingPropertiesForKeys: nil,
                                                         options: [.skipsHiddenFiles])) ?? []
        let decoder = Self.decoder()
        let sessions = urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { url -> CaptionSession? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(CaptionSession.self, from: data)
            }
            .sorted { $0.startedAt > $1.startedAt }
        guard let limit else { return sessions }
        return Array(sessions.prefix(max(0, limit)))
    }

    func delete(_ session: CaptionSession) throws {
        let url = directory.appendingPathComponent(fileName(for: session))
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    func deleteAll() throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        let urls = try fileManager.contentsOfDirectory(at: directory,
                                                       includingPropertiesForKeys: nil,
                                                       options: [.skipsHiddenFiles])
        for url in urls where url.pathExtension.lowercased() == "json" {
            try fileManager.removeItem(at: url)
        }
    }

    /// The export sits beside the session it came from, so Reveal in Finder
    /// always has one place to show. It never overwrites an earlier export
    /// made in the same second; the session id keeps the names apart.
    func exportURL(for session: CaptionSession, as format: CaptionExportFormat,
                   timeZone: TimeZone = .current) -> URL {
        directory.appendingPathComponent(
            "\(CaptionSupport.exportBaseName(session, timeZone: timeZone)) \(session.id.uuidString.prefix(8)).\(format.fileExtension)"
        )
    }

    @discardableResult
    func export(_ session: CaptionSession, as format: CaptionExportFormat,
                timeZone: TimeZone = .current) throws -> URL? {
        guard session.hasContent else { return nil }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = exportURL(for: session, as: format, timeZone: timeZone)
        let text = CaptionSupport.export(session, as: format, timeZone: timeZone)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// The stable on-disk identity. The session id keeps two runs started in
    /// the same second from replacing one another.
    func fileName(for session: CaptionSession) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "caption-\(formatter.string(from: session.startedAt))-\(session.id.uuidString.prefix(8)).json"
    }
}
