// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// Every judgment call of the cleaner in one place: what starts checked in
/// the review list and what never even appears. The rule of thumb is that a
/// find is pre checked only when the evidence is strong and rebuilding the
/// data is cheap; anything based on guessing starts unchecked and waits for
/// the user's eye.
enum CleanerPolicy {
    /// Leftovers are an educated guess against the installed apps oracle, so
    /// they start unchecked and the interface explains what they are.
    static let precheckLeftovers = false

    /// An orphaned startup item needs two independent signals (every
    /// executable gone AND no living owner for its label), so these start
    /// checked; they are the ghosts in Login Items and Extensions.
    static let precheckLoginItems = true

    /// Logs are diagnostic text apps rewrite freely.
    static let precheckLogs = true

    /// Build products and simulator caches regenerate on the next build.
    static let precheckDeveloper = true

    /// Relative to the home folder. Only ever offered when they exist. The
    /// DeviceSupport folders are debug symbol caches Xcode rebuilds on the
    /// next device connection; they quietly grow to tens of gigabytes and
    /// are a classic slice of the storage macOS files under "Other". The
    /// ordinary cache scan owns ~/Library/Caches, including Xcode and SwiftPM.
    static let developerJunkPaths: [String] = [
        "/Library/Developer/Xcode/DerivedData",
        "/Library/Developer/Xcode/DocumentationCache",
        "/Library/Developer/CoreSimulator/Caches",
        "/Library/Developer/Xcode/iOS DeviceSupport",
        "/Library/Developer/Xcode/watchOS DeviceSupport",
        "/Library/Developer/Xcode/tvOS DeviceSupport",
    ]

    /// Release archives are build products the user may still need to upload
    /// or symbolicate. They are listed one bundle at a time, only when older
    /// than the chosen age, and never pre checked. 0 turns the listing off.
    static let xcodeArchivePath = "/Library/Developer/Xcode/Archives"
    static let archiveAgeChoices = [30, 60, 90, 180, 365]
    static let defaultArchiveAgeDays = 90

    static func sanitizedArchiveAgeDays(_ raw: Int) -> Int {
        raw <= 0 ? 0 : min(raw, 3650)
    }

    /// Organizer saves archives inside YYYY-MM-DD folders. Also accept a
    /// bundle placed straight in Archives, but never search other subtrees.
    static func xcodeArchives(at root: URL, ageDays: Int, now: Date = Date(),
                              fileManager: FileManager = .default) -> [URL] {
        let ageDays = sanitizedArchiveAgeDays(ageDays)
        guard ageDays > 0 else { return [] }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey]
        let cutoff = now.addingTimeInterval(-Double(ageDays) * 86_400)
        func properties(_ url: URL) -> URLResourceValues? {
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isDirectory == true, values.isSymbolicLink == false else { return nil }
            return values
        }
        func children(_ url: URL) -> [URL] {
            (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(keys),
                                                   options: [.skipsHiddenFiles])) ?? []
        }
        func isOldArchive(_ url: URL) -> Bool {
            guard url.pathExtension == "xcarchive",
                  let modified = properties(url)?.contentModificationDate else { return false }
            return modified < cutoff
        }

        guard properties(root) != nil else { return [] }
        return children(root).flatMap { entry in
            if isOldArchive(entry) { return [entry] }
            guard entry.lastPathComponent.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#,
                                               options: .regularExpression) != nil,
                  properties(entry) != nil else { return [] }
            return children(entry).filter(isOldArchive)
        }
    }

    /// Everything under the developer paths rebuilds on the next build, so it
    /// starts checked. Archives are the one exception: they are the user's
    /// output, not a cache.
    static func developerIsPrechecked(_ homeRelativePath: String) -> Bool {
        precheckDeveloper && developerJunkPaths.contains(homeRelativePath)
    }

    /// Device backups are the user's safety net: enormous, ancient, and the
    /// other classic tenant of "Other" storage, but never a machine's call
    /// to delete. Every find waits unchecked for the user's eye.
    static let precheckDeviceBackups = false

    /// Forgotten screenshots sit in the user's own folders, so they are
    /// only ever offered, never pre checked: the size is the useful part.
    static let precheckScreenshots = false

    /// How long a screenshot must go untouched to count as forgotten. Zero
    /// turns the search off.
    static let screenshotAgeChoices = [7, 14, 30, 60, 90]
    static let defaultScreenshotAgeDays = 30

    static func sanitizedScreenshotAgeDays(_ raw: Int) -> Int {
        raw <= 0 ? 0 : min(raw, 3650)
    }

    /// Cache folders that never appear in the list at all: this app's own
    /// data and entries known to break things when removed (audio output
    /// loss, blank Settings panels, service sign outs, plugin licensing),
    /// each learned the hard way by the cleaners that came before.
    private static let hiddenCachePrefixes = [
        "com.tina",
        "CloudKit", "com.apple.bird",
        "com.apple.coreaudio", "com.apple.audio.", "coreaudiod",
        "com.apple.systempreferences", "com.apple.controlcenter",
        "com.apple.finder", "com.apple.dock",
        "com.apple.FontRegistry", "com.apple.ATS",
        "com.apple.akd", "com.apple.AuthKit",
        "com.paceap.", "com.native-instruments", "com.fabfilter",
        // This cache also holds installed customizations that cannot be rebuilt.
        "com.spotify.client",
    ]

    /// Third party caches whose content the user paid bandwidth or setup
    /// for (offline media, model and browser downloads): shown, never pre
    /// checked.
    private static let sensitiveCachePrefixes = [
        "ms-playwright",
    ]

    static func isExcludedCacheEntry(_ name: String, audioPluginIDs: Set<String> = []) -> Bool {
        let lowered = name.lowercased()
        // A localization name is not evidence of disposable data. Keep the
        // leftover exclusion when the same entry is visited as caches or logs.
        if lowered.hasSuffix(".localized") { return true }
        if hiddenCachePrefixes.contains(where: { lowered.hasPrefix($0.lowercased()) }) { return true }
        // A plugin can keep its activation in a cache named for its bundle.
        // Other apps from the same vendor still have ordinary caches.
        return !audioPluginIDs.isEmpty && CleanerSupport.looksLikeBundleID(name)
            && CleanerSupport.isOwned(candidate: name, byInstalled: audioPluginIDs)
    }

    /// Plain named cache folders known to be pure downloads or build junk;
    /// anything plain named outside this list stays unchecked because bare
    /// names cannot be attributed (some are the system's own, like the maps
    /// tile cache).
    private static let safePlainNameCaches: Set<String> = [
        "homebrew", "pip", "node-gyp", "yarn", "npm", "google",
        "electron", "cypress", "typescript", "puppeteer",
    ]

    /// Apple's own caches are safe to remove but the system rebuilds them
    /// eagerly (slower first launches, re indexing), so they are listed for
    /// the willing and pre checked for nobody. Third party caches start
    /// checked unless they hold content worth keeping, and plain named
    /// folders only when they are known download or build caches.
    static func precheckCacheEntry(_ name: String, audioPluginIDs: Set<String> = []) -> Bool {
        guard !isExcludedCacheEntry(name, audioPluginIDs: audioPluginIDs) else { return false }
        let lowered = name.lowercased()
        if sensitiveCachePrefixes.contains(where: { lowered.hasPrefix($0.lowercased()) }) { return false }
        if CleanerSupport.looksLikeBundleID(name) {
            return !lowered.hasPrefix("com.apple.")
        }
        return safePlainNameCaches.contains(lowered)
    }
}
