// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// Live captions: the timeline, the three export formats, the session store
/// and the catalog/localization contract. Nothing here needs a microphone,
/// a window or Speech, so the suite runs in CI.
enum CaptionTests {
    static func run(_ suite: TestSuite) {
        textAndTimeline(suite)
        exports(suite)
        store(suite)
        catalog(suite)
        localization(suite)
        backup(suite)
    }

    // MARK: - Text and timeline

    private static func textAndTimeline(_ suite: TestSuite) {
        suite.expect(CaptionSupport.normalizedText("  hello\n  there\tfriend ")
                     == "hello there friend",
                     "whitespace collapses to single spaces")
        suite.expect(CaptionSupport.normalizedText("\n\t ") == "", "whitespace-only is empty")

        let first = CaptionSegment(start: 1, end: 2, text: "Hello")
        let duplicate = CaptionSegment(start: 2, end: 3, text: "Hello")
        let second = CaptionSegment(start: 3, end: 4, text: "World")
        let appended = CaptionSupport.appending([first, duplicate, second], to: [])
        suite.expect(appended.count == 2, "a repeated final line is merged, got \(appended.count)")
        suite.expect(appended.first?.end == 3, "a merged line grows to the newer end")
        suite.expect(CaptionSupport.speechKey("Hello, world!") == "hello world",
                     "case and punctuation do not make a new line")

        let prefix = CaptionSegment(start: 0, end: 1, text: "hello")
        let continued = CaptionSegment(start: 1, end: 2, text: "hello there")
        let merged = CaptionSupport.appending([continued], to: [prefix])
        suite.expect(merged.count == 1 && merged.first?.text == "hello there",
                     "a fuller copy replaces the partial it continues")

        suite.expect(CaptionSupport.clock(0) == "00:00:00", "zero clock")
        suite.expect(CaptionSupport.clock(3661.9) == "01:01:01", "clock floors seconds")
        suite.expect(CaptionSupport.srtTimestamp(3661.257) == "01:01:01,257",
                     "SRT timestamp keeps milliseconds")
        suite.expect(CaptionSupport.srtTimestamp(-4) == "00:00:00,000",
                     "negative times clamp to zero")

        let pieces = [
            CaptionSpeechSegment(timestamp: 0.5, duration: 1.0, text: "  one "),
            CaptionSpeechSegment(timestamp: 2.0, duration: 0.25, text: "two"),
        ]
        let mapped = CaptionSupport.segments(from: pieces, base: 10, measuredFrom: 0)
        suite.expect(mapped.count == 2, "two speech pieces become two segments")
        suite.expect(mapped.first?.start == 10.5 && mapped.first?.end == 11.5,
                     "speech timing moves onto the session clock")
        suite.expect(mapped.first?.text == "one", "speech text is normalized")

        let shifted = CaptionSupport.segments(from: pieces, base: 0, measuredFrom: 5)
        suite.expect(shifted.first?.start == 5, "a segment overlapping the last end shifts later")

        let fallback = CaptionSupport.fallbackSegment(text: "  last words ", start: 3, end: 3)
        suite.expect(fallback?.text == "last words", "fallback normalizes text")
        suite.expect(fallback?.end == 3.5, "fallback grows a zero-length line")
        suite.expect(CaptionSupport.fallbackSegment(text: " ", start: 0, end: 1) == nil,
                     "an empty fallback is no line")

        suite.expect(CaptionSupport.shouldRotate(requestStartedAt: Date(timeIntervalSince1970: 0),
                                                 now: Date(timeIntervalSince1970: 50)),
                     "a request rotates at the limit")
        suite.expect(!CaptionSupport.shouldRotate(requestStartedAt: Date(timeIntervalSince1970: 0),
                                                  now: Date(timeIntervalSince1970: 49.9)),
                     "a request below the limit keeps running")

        suite.expect(CaptionSupport.sanitizedFontSize(2) == 12, "font size clamps low")
        suite.expect(CaptionSupport.sanitizedFontSize(99) == 36, "font size clamps high")
        suite.expect(CaptionSupport.sanitizedFontSize(.nan) == 20, "NaN font size falls back")
        suite.expect(CaptionSupport.sanitizedMaxLines(0) == 1, "line count clamps low")
        suite.expect(CaptionSupport.sanitizedMaxLines(9) == 4, "line count clamps high")
    }

    // MARK: - Exports

    private static func session() -> CaptionSession {
        CaptionSession(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_010),
            localeIdentifier: "en-US",
            segments: [
                CaptionSegment(start: 1, end: 2.5, text: "Hello"),
                CaptionSegment(start: 3661.25, end: 3662, text: "World"),
            ]
        )
    }

    private static func exports(_ suite: TestSuite) {
        let session = session()
        let srt = CaptionSupport.srt(session)
        suite.expect(srt.contains("1\n00:00:01,000 --> 00:00:02,500\nHello"),
                     "SRT writes its first cue")
        suite.expect(srt.contains("2\n01:01:01,250 --> 01:01:02,000\nWorld"),
                     "SRT writes the later cue on the hour")
        suite.expect(srt.hasSuffix("\n\n"), "SRT ends with the blank line between cues")

        let markdown = CaptionSupport.markdown(session)
        suite.expect(markdown.hasPrefix("# "), "Markdown starts with a title")
        suite.expect(markdown.contains("- **[00:00:01]** Hello"), "Markdown carries timestamps")
        suite.expect(markdown.contains("- **[01:01:01]** World"), "Markdown keeps every cue")

        let plain = CaptionSupport.plainText(session)
        suite.expect(plain == "Hello\nWorld\n", "plain text is one line per cue")

        let empty = CaptionSession(localeIdentifier: "en-US")
        suite.expect(CaptionSupport.srt(empty).isEmpty, "an empty session has no SRT")
        suite.expect(CaptionSupport.plainText(empty).isEmpty, "an empty session has no plain text")
        suite.expect(CaptionSupport.export(empty, as: .srt).isEmpty,
                     "exporting an empty session produces no text")

        let name = CaptionSupport.exportBaseName(session, timeZone: TimeZone(secondsFromGMT: 0)!)
        suite.expect(name.hasPrefix("Live Captions "), "the export name is recognizable")
        suite.expect(name.contains("."), "the clock in the name uses dots")
        suite.expect(!name.contains(":"), "the clock in the name never uses a colon")
    }

    // MARK: - Store

    private static func store(_ suite: TestSuite) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("caption-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = CaptionSessionStore(directory: root)

        let empty = CaptionSession(localeIdentifier: "en-US")
        suite.expect((try? store.save(empty)) == .some(nil),
                     "a session with no finalized line is not written")

        let saved = session()
        let url = try? store.save(saved)
        suite.expect(url != nil && FileManager.default.fileExists(atPath: url!.path),
                     "a session with lines is written")

        let loaded = store.loadAll()
        suite.expect(loaded.count == 1, "the saved session reads back")
        suite.expect(loaded.first?.segments == saved.segments, "segments survive the round trip")
        suite.expect(loaded.first?.localeIdentifier == "en-US", "the language survives")
        suite.expect(loaded.first?.startedAt == saved.startedAt, "the start date survives")

        let second = CaptionSession(startedAt: saved.startedAt.addingTimeInterval(60),
                                    localeIdentifier: "fr-FR",
                                    segments: [CaptionSegment(start: 0, end: 1, text: "Bonjour")])
        _ = try? store.save(second)
        suite.expect(store.loadAll(limit: 1).first?.localeIdentifier == "fr-FR",
                     "the newest session sorts first")
        suite.expect(store.loadAll().count == 2, "every session is listed")

        // A corrupt file is ignored rather than blocking the list.
        try? "not json".write(to: root.appendingPathComponent("broken.json"),
                              atomically: true, encoding: .utf8)
        suite.expect(store.loadAll().count == 2, "a corrupt session file is skipped")

        let exportURL = try? store.export(saved, as: .srt)
        suite.expect(exportURL?.pathExtension == "srt", "SRT export uses the srt extension")
        suite.expect((try? String(contentsOf: exportURL!, encoding: .utf8))?.contains("Hello") == true,
                     "the exported file carries the transcript")
        let markdownURL = try? store.export(saved, as: .markdown)
        suite.expect(markdownURL?.pathExtension == "md", "Markdown export uses the md extension")
        let textURL = try? store.export(saved, as: .plainText)
        suite.expect(textURL?.pathExtension == "txt", "plain export uses the txt extension")

        try? store.delete(saved)
        suite.expect(store.loadAll().count == 1, "deleting a session removes its file")

        try? store.deleteAll()
        suite.expect(store.loadAll().isEmpty, "clearing history removes every session")
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        suite.expect(leftovers.allSatisfy { !$0.hasSuffix(".json") },
                     "clearing history leaves no session JSON behind")
        suite.expect(!(leftovers.isEmpty),
                     "clearing history keeps the exported files the user asked for")
    }

    // MARK: - Catalog

    private static func catalog(_ suite: TestSuite) {
        let feature = AppFeature.captions
        suite.expect(feature.group == .sound, "live captions belong to Sound")
        suite.expect(!feature.symbolName.isEmpty, "the feature has a symbol")
        suite.expect(feature.permissions.contains(.audioCapture),
                     "captions read the Mac's sound")
        suite.expect(feature.permissions.contains(.speechRecognition),
                     "captions ask for Speech Recognition")
        suite.expect(!feature.installedByDefault,
                     "a new feature is installed from the hub, never by an update")
        suite.expect(feature.energyProfile == .idle,
                     "an idle caption feature costs no polling")
        suite.expect(feature.enabledKeys == [DefaultsKey.captionsEnabled],
                     "the master switch is the only enable key")

        let role = GlobalShortcutRole.captions
        suite.expect(role.storageKey == DefaultsKey.captionsShortcut,
                     "the shortcut role uses the caption key")
        suite.expect(role.defaultShortcut == .captionsDefault, "the default is the caption default")
        suite.expect(role.requiredEnableKeys == [DefaultsKey.captionsEnabled,
                                                 DefaultsKey.captionsShortcutEnabled],
                     "the shortcut follows the master and its own switch")
        suite.expect(role.feature == .captions, "the shortcut belongs to captions")

        let keys = SettingsBackupSupport.exportKeys()
        suite.expect(keys.contains(DefaultsKey.captionsEnabled), "the master switch is backed up")
        suite.expect(keys.contains(DefaultsKey.captionsShortcut), "the shortcut is backed up")
        suite.expect(keys.contains(DefaultsKey.captionsFontSize), "the caption size is backed up")
        suite.expect(!keys.contains(DefaultsKey.captionsFolderBookmark),
                     "a machine-local folder bookmark never travels in a backup")
        suite.expect(!keys.contains(DefaultsKey.captionsFolderPath),
                     "a folder path from another Mac never travels in a backup")
    }

    // MARK: - Localization

    private static func localization(_ suite: TestSuite) {
        let hub = FeatureStrings.hub(.enUS)
        for language in AppLanguage.allCases {
            let strings = FeatureStrings.captions(language)
            let mirror = Mirror(reflecting: strings)
            for child in mirror.children {
                let name = child.label ?? "field"
                let value = child.value as? String ?? ""
                suite.expect(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                             "\(language.rawValue) caption \(name) is not empty")
            }
            suite.expect(!AppFeature.captions.hubTitle(L10n.shared.s, hub: hub, language: language)
                            .isEmpty,
                         "\(language.rawValue) has a caption title")
        }
    }

    // MARK: - Backup

    private static func backup(_ suite: TestSuite) {
        let keys = SettingsBackupSupport.exportKeys()
        for key in [DefaultsKey.captionsEnabled, DefaultsKey.captionsShortcutEnabled,
                    DefaultsKey.captionsShortcut, DefaultsKey.captionsLocale,
                    DefaultsKey.captionsFontSize, DefaultsKey.captionsMaxLines,
                    DefaultsKey.captionsAutoSave, DefaultsKey.captionsOverlayX,
                    DefaultsKey.captionsOverlayY, DefaultsKey.panelShowCaptions] {
            suite.expect(keys.contains(key), "\(key) travels in a settings backup")
        }
    }
}
