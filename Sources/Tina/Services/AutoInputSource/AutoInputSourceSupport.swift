// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// What should happen to the input source when an app comes to the front.
/// The kind is stored as a stable string and the source id only travels with a
/// fixed choice, so a rules file stays readable and hand-editable.
struct AutoInputSourceBehavior: Codable, Equatable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case followGlobal
        case fixed
        case rememberLast
        case noSwitch
    }

    var kind: Kind
    var sourceID: String?

    init(kind: Kind, sourceID: String? = nil) {
        self.kind = kind
        let trimmed = sourceID?.trimmingCharacters(in: .whitespacesAndNewlines)
        // A fixed choice without an id is indistinguishable from "do not
        // switch", and keeping a stale id on the other kinds would make a
        // behavior change silently retain the old source.
        self.sourceID = kind == .fixed ? (trimmed?.isEmpty == false ? trimmed : nil) : nil
    }

    static let followGlobal = AutoInputSourceBehavior(kind: .followGlobal)
    static let rememberLast = AutoInputSourceBehavior(kind: .rememberLast)
    static let noSwitch = AutoInputSourceBehavior(kind: .noSwitch)

    static func fixed(_ sourceID: String) -> AutoInputSourceBehavior {
        AutoInputSourceBehavior(kind: .fixed, sourceID: sourceID)
    }

    var fixedSourceID: String? { kind == .fixed ? sourceID : nil }

    /// The global default cannot follow itself, so a stored followGlobal
    /// decays to the safe choice.
    var withoutFollowGlobal: AutoInputSourceBehavior {
        kind == .followGlobal ? .noSwitch : self
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case sourceID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw: String? = ((try? container.decodeIfPresent(String.self,
                                                             forKey: .kind)) ?? nil)
        let kind = raw.flatMap(Kind.init(rawValue:)) ?? .noSwitch
        let sourceID: String? = ((try? container.decodeIfPresent(String.self,
                                                                  forKey: .sourceID)) ?? nil)
        self.init(kind: kind, sourceID: sourceID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind.rawValue, forKey: .kind)
        if kind == .fixed, let sourceID {
            try container.encode(sourceID, forKey: .sourceID)
        }
    }
}

/// The two moments a rule can answer: the first activation after the app
/// launched, and every activation after that.
struct AutoInputSourceTimings: Codable, Equatable {
    var firstActivation: AutoInputSourceBehavior
    var reactivation: AutoInputSourceBehavior

    init(firstActivation: AutoInputSourceBehavior, reactivation: AutoInputSourceBehavior) {
        self.firstActivation = firstActivation
        self.reactivation = reactivation
    }

    static let none = AutoInputSourceTimings(firstActivation: .noSwitch,
                                             reactivation: .noSwitch)

    private enum CodingKeys: String, CodingKey {
        case firstActivation
        case reactivation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        firstActivation = ((try? container.decodeIfPresent(AutoInputSourceBehavior.self,
                                                            forKey: .firstActivation)) ?? nil)
            ?? .noSwitch
        reactivation = ((try? container.decodeIfPresent(AutoInputSourceBehavior.self,
                                                        forKey: .reactivation)) ?? nil)
            ?? .noSwitch
    }

    var withoutFollowGlobal: AutoInputSourceTimings {
        AutoInputSourceTimings(firstActivation: firstActivation.withoutFollowGlobal,
                               reactivation: reactivation.withoutFollowGlobal)
    }

    func behavior(firstActivation isFirst: Bool) -> AutoInputSourceBehavior {
        isFirst ? firstActivation : reactivation
    }
}

/// One app's answer, keyed by bundle id. The display name is cached so the
/// list reads correctly when the app is uninstalled or its bundle is slow to
/// resolve; the bundle id is the identity that actually matches.
struct AutoInputSourceRule: Codable, Equatable, Identifiable {
    var bundleID: String
    var appName: String
    var timings: AutoInputSourceTimings

    var id: String { bundleID }

    init(bundleID: String, appName: String, timings: AutoInputSourceTimings = .none) {
        self.bundleID = bundleID
        self.appName = appName
        self.timings = timings
    }

    private enum CodingKeys: String, CodingKey {
        case bundleID
        case appName
        case timings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = ((try? container.decodeIfPresent(String.self, forKey: .bundleID)) ?? nil) ?? ""
        appName = ((try? container.decodeIfPresent(String.self, forKey: .appName)) ?? nil) ?? ""
        timings = ((try? container.decodeIfPresent(AutoInputSourceTimings.self,
                                                   forKey: .timings)) ?? nil) ?? .none
    }
}

/// Everything the feature persists as configuration: the global default, the
/// apps that never switch, and the per-app rules. Last-used sources are habit
/// on one Mac and are stored separately.
struct AutoInputSourceConfiguration: Codable, Equatable {
    static let format = "tina.auto-input-source"
    static let currentVersion = 1
    static let maxRules = 200
    static let maxExclusions = 200

    var format: String
    var version: Int
    var global: AutoInputSourceTimings
    var excludedBundleIDs: [String]
    var rules: [AutoInputSourceRule]

    init(format: String = AutoInputSourceConfiguration.format,
         version: Int = AutoInputSourceConfiguration.currentVersion,
         global: AutoInputSourceTimings = .none,
         excludedBundleIDs: [String] = [],
         rules: [AutoInputSourceRule] = []) {
        self.format = format
        self.version = version
        self.global = global
        self.excludedBundleIDs = excludedBundleIDs
        self.rules = rules
    }

    static let empty = AutoInputSourceConfiguration()

    private enum CodingKeys: String, CodingKey {
        case format
        case version
        case global
        case excludedBundleIDs
        case rules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        format = ((try? container.decodeIfPresent(String.self, forKey: .format)) ?? nil)
            ?? Self.format
        version = ((try? container.decodeIfPresent(Int.self, forKey: .version)) ?? nil)
            ?? Self.currentVersion
        global = ((try? container.decodeIfPresent(AutoInputSourceTimings.self,
                                                  forKey: .global)) ?? nil) ?? .none
        excludedBundleIDs = ((try? container.decodeIfPresent([String].self,
                                                             forKey: .excludedBundleIDs)) ?? nil) ?? []
        rules = ((try? container.decodeIfPresent([AutoInputSourceRule].self,
                                                 forKey: .rules)) ?? nil) ?? []
    }
}

/// The rules engine, the stored formats and the import contract. Pure, so the
/// precedence and every malformed input can be pinned without a window.
enum AutoInputSourceSupport {
    static let lastSourcesLimit = 200

    // MARK: - Decisions

    enum Decision: Equatable {
        case stay
        case select(String)

        var sourceID: String? {
            if case .select(let id) = self { return id }
            return nil
        }
    }

    /// What the newly active app should get. Precedence is exclusions, then a
    /// per-app rule, then the global default; a target that is already active
    /// is reported as no change so the text input server is not touched for
    /// nothing.
    static func decision(bundleID: String,
                         firstActivation: Bool,
                         configuration: AutoInputSourceConfiguration,
                         lastSources: [String: String],
                         enabledSourceIDs: Set<String>,
                         currentSourceID: String?) -> Decision {
        guard isValidBundleID(bundleID),
              !configuration.excludedBundleIDs.contains(bundleID) else { return .stay }
        let rule = configuration.rules.first { $0.bundleID == bundleID }
        let behavior = rule?.timings.behavior(firstActivation: firstActivation)
            ?? configuration.global.behavior(firstActivation: firstActivation)
        return resolve(behavior,
                       bundleID: bundleID,
                       firstActivation: firstActivation,
                       global: configuration.global,
                       lastSources: lastSources,
                       enabledSourceIDs: enabledSourceIDs,
                       currentSourceID: currentSourceID,
                       followsGlobal: true)
    }

    private static func resolve(_ behavior: AutoInputSourceBehavior,
                                bundleID: String,
                                firstActivation: Bool,
                                global: AutoInputSourceTimings,
                                lastSources: [String: String],
                                enabledSourceIDs: Set<String>,
                                currentSourceID: String?,
                                followsGlobal: Bool) -> Decision {
        switch behavior.kind {
        case .followGlobal:
            // A rule may follow the global default. The global one is stored
            // without followGlobal, and the flag stops a corrupt file from
            // recursing if it is not.
            guard followsGlobal else { return .stay }
            return resolve(global.behavior(firstActivation: firstActivation),
                           bundleID: bundleID, firstActivation: firstActivation,
                           global: global,
                           lastSources: lastSources, enabledSourceIDs: enabledSourceIDs,
                           currentSourceID: currentSourceID, followsGlobal: false)
        case .noSwitch:
            return .stay
        case .fixed:
            guard let id = behavior.fixedSourceID, enabledSourceIDs.contains(id) else {
                return .stay
            }
            return selection(id, currentSourceID: currentSourceID)
        case .rememberLast:
            guard let id = lastSources[bundleID], enabledSourceIDs.contains(id) else {
                return .stay
            }
            return selection(id, currentSourceID: currentSourceID)
        }
    }

    private static func selection(_ id: String, currentSourceID: String?) -> Decision {
        id == currentSourceID ? .stay : .select(id)
    }

    // MARK: - Sanitizing

    static func isValidBundleID(_ id: String) -> Bool {
        guard !id.isEmpty, id.utf8.count <= 200 else { return false }
        return id.utf8.allSatisfy { byte in
            (byte >= 48 && byte <= 57)      // 0-9
                || (byte >= 65 && byte <= 90)   // A-Z
                || (byte >= 97 && byte <= 122)  // a-z
                || byte == 46                   // .
                || byte == 45                   // -
                || byte == 95                   // _
        }
    }

    /// A decoded file is untrusted: drop malformed identities, duplicate apps,
    /// duplicate exclusions, followGlobal in the global default, and anything
    /// past the limits. First occurrence wins, so order stays the user's.
    static func sanitized(_ configuration: AutoInputSourceConfiguration)
        -> AutoInputSourceConfiguration {
        var result = AutoInputSourceConfiguration(
            format: AutoInputSourceConfiguration.format,
            version: min(max(configuration.version, 1), AutoInputSourceConfiguration.currentVersion),
            global: configuration.global.withoutFollowGlobal,
            excludedBundleIDs: [],
            rules: [])

        var excluded = Set<String>()
        for id in configuration.excludedBundleIDs {
            let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidBundleID(trimmed), excluded.insert(trimmed).inserted else { continue }
            result.excludedBundleIDs.append(trimmed)
            if result.excludedBundleIDs.count == AutoInputSourceConfiguration.maxExclusions { break }
        }

        var ruled = Set<String>()
        for rule in configuration.rules {
            let id = rule.bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidBundleID(id), ruled.insert(id).inserted else { continue }
            let name = rule.appName.trimmingCharacters(in: .whitespacesAndNewlines)
            result.rules.append(AutoInputSourceRule(
                bundleID: id,
                appName: String((name.isEmpty ? id : name).prefix(120)),
                timings: rule.timings))
            if result.rules.count == AutoInputSourceConfiguration.maxRules { break }
        }
        return result
    }

    // MARK: - Stored formats

    static func decodeConfiguration(_ raw: String?) -> AutoInputSourceConfiguration {
        guard let raw, !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(AutoInputSourceConfiguration.self,
                                                     from: data)
        else { return .empty }
        return sanitized(decoded)
    }

    static func encodeConfiguration(_ configuration: AutoInputSourceConfiguration) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(sanitized(configuration)),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    static func decodeLastSources(_ raw: String?) -> [String: String] {
        guard let raw, !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return decoded.filter { isValidBundleID($0.key) && !$0.value.isEmpty }
    }

    static func encodeLastSources(_ sources: [String: String]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(sources),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    /// Forget sources the system no longer offers, so a disabled input method
    /// cannot come back as a remembered target.
    static func pruned(_ sources: [String: String],
                       enabledSourceIDs: Set<String>) -> [String: String] {
        var result: [String: String] = [:]
        for (bundleID, sourceID) in sources
        where isValidBundleID(bundleID) && enabledSourceIDs.contains(sourceID) {
            result[bundleID] = sourceID
            if result.count == lastSourcesLimit { break }
        }
        return result
    }

    // MARK: - Rules file

    enum ImportFailure: Error, Equatable {
        case unreadable
        case unsupportedFormat
        case newerVersion
    }

    /// Accepts the file this feature exports, and a hand-written dotfile that
    /// carries the same keys without the envelope. A newer version is refused
    /// rather than half-understood, because a rule the file cannot describe
    /// could switch a source the user did not expect.
    static func importConfiguration(from data: Data) -> Result<AutoInputSourceConfiguration,
                                                              ImportFailure> {
        guard let decoded = try? JSONDecoder().decode(AutoInputSourceConfiguration.self,
                                                      from: data)
        else { return .failure(.unreadable) }
        guard decoded.format == AutoInputSourceConfiguration.format else {
            return .failure(.unsupportedFormat)
        }
        guard decoded.version <= AutoInputSourceConfiguration.currentVersion else {
            return .failure(.newerVersion)
        }
        return .success(sanitized(decoded))
    }

    static func exportData(_ configuration: AutoInputSourceConfiguration) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(sanitized(configuration))) ?? Data()
    }
}
