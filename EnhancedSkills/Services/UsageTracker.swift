import Foundation

final class UsageTracker {
    private let pollInterval: TimeInterval = 45
    private let selfReadWindow: TimeInterval = 5
    private let selfReadCleanupAge: TimeInterval = 120

    private var timer: Timer?
    private var trackedFiles: [(slug: String, provider: String, url: URL)] = []
    private var database: SkillUsageDatabase
    private var selfReadTimestamps: [URL: Date] = [:]
    private let trackerStartedAt = Date()

    // MARK: - CLI log tracking state
    // JSONL streams (Codex/Claude) are tailed incrementally by byte offset.
    private var codexOffsets: [String: UInt64] = [:]
    private var claudeOffsets: [String: UInt64] = [:]
    private var codexLineRemainders: [String: String] = [:]
    private var claudeLineRemainders: [String: String] = [:]

    // Gemini sessions are JSON snapshots rewritten in-place, so we track
    // modified dates + processed message IDs.
    private var geminiSessionModifiedAt: [String: Date] = [:]
    private var processedGeminiMessageIDs: Set<String> = []

    var onStatsUpdated: ((SkillUsageDatabase) -> Void)?

    private static var statsURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".enhanced-skills/usage-stats.json")
    }

    private static var codexSessionsURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".codex/sessions")
    }

    private static var claudeProjectsURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude/projects")
    }

    private static var geminiTmpURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".gemini/tmp")
    }

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    init() {
        self.database = Self.load()
    }

    // MARK: - Persistence

    private static func load() -> SkillUsageDatabase {
        let url = statsURL
        guard let data = try? Data(contentsOf: url) else {
            return SkillUsageDatabase()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(SkillUsageDatabase.self, from: data)) ?? SkillUsageDatabase()
    }

    func save() {
        let url = Self.statsURL
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(database) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - Self-Read Filtering

    func markSelfRead(url: URL) {
        selfReadTimestamps[url] = Date()
        // Advance lastKnownAtime so the next poll doesn't count this as genuine usage
        if let file = trackedFiles.first(where: { $0.url == url }),
           let atime = Self.fileAtime(url) {
            database.records[file.slug]?.entries[file.provider]?.lastKnownAtime = atime
        }
    }

    func markSelfRead(urls: [URL]) {
        let now = Date()
        let urlSet = Set(urls)
        for url in urls {
            selfReadTimestamps[url] = now
        }
        // Advance lastKnownAtime for all known tracked files so the next poll
        // doesn't count the app's own reads as genuine usage
        for file in trackedFiles where urlSet.contains(file.url) {
            if let atime = Self.fileAtime(file.url) {
                database.records[file.slug]?.entries[file.provider]?.lastKnownAtime = atime
            }
        }
    }

    private func isSelfRead(url: URL, atime: Date) -> Bool {
        guard let selfTime = selfReadTimestamps[url] else { return false }
        return abs(atime.timeIntervalSince(selfTime)) < selfReadWindow
    }

    private func cleanupSelfReads() {
        let cutoff = Date().addingTimeInterval(-selfReadCleanupAge)
        selfReadTimestamps = selfReadTimestamps.filter { $0.value > cutoff }
    }

    // MARK: - Lifecycle

    func start(skills: [(slug: String, provider: String, url: URL)]) {
        trackedFiles = skills

        // Record baselines for files we haven't seen before
        recordBaselines()
        initializeLogBaselines()

        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.pollUsage()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        save()
    }

    func updateTrackedFiles(from records: [SkillRecord]) {
        trackedFiles = records.flatMap { record in
            record.skills.map { (provider, skill) in
                (slug: record.slug, provider: provider.rawValue, url: skill.skillMarkdownPath)
            }
        }
    }

    // MARK: - Polling

    private func recordBaselines() {
        let now = Date()
        for file in trackedFiles {
            guard let atime = Self.fileAtime(file.url) else { continue }
            let key = file.slug

            if database.records[key] == nil {
                database.records[key] = SkillUsageRecord(slug: file.slug, entries: [:])
            }

            if database.records[key]?.entries[file.provider] == nil {
                database.records[key]?.entries[file.provider] = SkillUsageEntry(
                    provider: file.provider,
                    usageCount: 0,
                    lastUsed: now,
                    firstSeen: now,
                    lastKnownAtime: atime
                )
            } else {
                // Always sync lastKnownAtime on startup — the initial refresh() reads all
                // files before the tracker exists (so markSelfRead is never called), and
                // stale baseline values from a previous session would cause the first poll
                // to count those reads as genuine usage across every provider.
                database.records[key]?.entries[file.provider]?.lastKnownAtime = atime
            }
        }
        database.lastPollTime = now
        save()
        onStatsUpdated?(database)
    }

    private func pollUsage() {
        cleanupSelfReads()
        let now = Date()
        var changed = false

        for file in trackedFiles {
            guard let atime = Self.fileAtime(file.url) else { continue }
            let key = file.slug

            guard let entry = database.records[key]?.entries[file.provider] else {
                // New file appeared — record baseline
                if database.records[key] == nil {
                    database.records[key] = SkillUsageRecord(slug: file.slug, entries: [:])
                }
                database.records[key]?.entries[file.provider] = SkillUsageEntry(
                    provider: file.provider,
                    usageCount: 0,
                    lastUsed: now,
                    firstSeen: now,
                    lastKnownAtime: atime
                )
                changed = true
                continue
            }

            // Check if atime advanced since last known
            if atime > entry.lastKnownAtime {
                if !isSelfRead(url: file.url, atime: atime) {
                    // Genuine external read detected
                    database.records[key]?.entries[file.provider]?.usageCount += 1
                    database.records[key]?.entries[file.provider]?.lastUsed = now
                }
                database.records[key]?.entries[file.provider]?.lastKnownAtime = atime
                changed = true
            }
        }

        if pollCLILogSignals(now: now) {
            changed = true
        }

        if changed {
            database.lastPollTime = now
            save()
            onStatsUpdated?(database)
        }
    }

    // MARK: - CLI Log Signals

    private func initializeLogBaselines() {
        codexOffsets = baselineOffsets(for: enumerateJSONLFiles(in: Self.codexSessionsURL))
        claudeOffsets = baselineOffsets(for: enumerateJSONLFiles(in: Self.claudeProjectsURL))
        codexLineRemainders.removeAll()
        claudeLineRemainders.removeAll()

        geminiSessionModifiedAt.removeAll()
        processedGeminiMessageIDs.removeAll()
        for url in enumerateGeminiSessionFiles() {
            geminiSessionModifiedAt[url.path] = Self.fileModificationDate(url) ?? .distantPast
        }
    }

    private func baselineOffsets(for files: [URL]) -> [String: UInt64] {
        var offsets: [String: UInt64] = [:]
        for file in files {
            offsets[file.path] = Self.fileSize(file) ?? 0
        }
        return offsets
    }

    private func pollCLILogSignals(now: Date) -> Bool {
        var changed = false

        let codexSlugs = trackedSlugs(for: Provider.codex.rawValue)
        if !codexSlugs.isEmpty, pollCodexLogs(slugs: codexSlugs, now: now) {
            changed = true
        }

        let claudeSlugs = trackedSlugs(for: Provider.claude.rawValue)
        if !claudeSlugs.isEmpty, pollClaudeLogs(slugs: claudeSlugs, now: now) {
            changed = true
        }

        let geminiSlugs = trackedSlugs(for: Provider.gemini.rawValue)
        if !geminiSlugs.isEmpty, pollGeminiLogs(slugs: geminiSlugs, now: now) {
            changed = true
        }

        return changed
    }

    private func pollCodexLogs(slugs: Set<String>, now: Date) -> Bool {
        let files = enumerateJSONLFiles(in: Self.codexSessionsURL)
        let activePaths = Set(files.map(\.path))
        codexOffsets = codexOffsets.filter { activePaths.contains($0.key) }
        codexLineRemainders = codexLineRemainders.filter { activePaths.contains($0.key) }

        var changed = false
        for file in files {
            let path = file.path
            if codexOffsets[path] == nil {
                codexOffsets[path] = 0
            }
            let offset = codexOffsets[path] ?? 0
            let remainder = codexLineRemainders[path] ?? ""
            guard let delta = readJSONLDelta(at: file, fromOffset: offset, remainder: remainder) else { continue }

            codexOffsets[path] = delta.newOffset
            codexLineRemainders[path] = delta.remainder

            for line in delta.lines {
                guard let object = Self.parseJSONObject(line) else { continue }

                // If Codex emits an explicit skill function call, prefer that.
                let invokedSkills = Self.codexInvokedSkills(from: object)
                for skill in invokedSkills {
                    let normalized = SkillInventory.normalize(skill)
                    if slugs.contains(normalized),
                       incrementUsage(slug: normalized, provider: Provider.codex.rawValue, now: now) {
                        changed = true
                    }
                }

                guard let message = Self.codexUserMessage(from: object) else { continue }
                let hits = detectInvokedSlugs(in: message, candidates: slugs)
                for slug in hits where incrementUsage(slug: slug, provider: Provider.codex.rawValue, now: now) {
                    changed = true
                }
            }
        }
        return changed
    }

    private func pollClaudeLogs(slugs: Set<String>, now: Date) -> Bool {
        let files = enumerateJSONLFiles(in: Self.claudeProjectsURL)
        let activePaths = Set(files.map(\.path))
        claudeOffsets = claudeOffsets.filter { activePaths.contains($0.key) }
        claudeLineRemainders = claudeLineRemainders.filter { activePaths.contains($0.key) }

        var changed = false
        for file in files {
            let path = file.path
            if claudeOffsets[path] == nil {
                claudeOffsets[path] = 0
            }
            let offset = claudeOffsets[path] ?? 0
            let remainder = claudeLineRemainders[path] ?? ""
            guard let delta = readJSONLDelta(at: file, fromOffset: offset, remainder: remainder) else { continue }

            claudeOffsets[path] = delta.newOffset
            claudeLineRemainders[path] = delta.remainder

            for line in delta.lines {
                guard let object = Self.parseJSONObject(line) else { continue }

                // High-signal path: explicit Skill tool invocation in Claude logs.
                let invokedSkills = Self.claudeToolInvokedSkills(from: object)
                for skill in invokedSkills {
                    let normalized = SkillInventory.normalize(skill)
                    if slugs.contains(normalized),
                       incrementUsage(slug: normalized, provider: Provider.claude.rawValue, now: now) {
                        changed = true
                    }
                }

                // Fallback path: user slash-style invocations in Claude commands/messages.
                if let userText = Self.claudeUserText(from: object) {
                    let hits = detectInvokedSlugs(in: userText, candidates: slugs)
                    for slug in hits where incrementUsage(slug: slug, provider: Provider.claude.rawValue, now: now) {
                        changed = true
                    }
                }
            }
        }
        return changed
    }

    private func pollGeminiLogs(slugs: Set<String>, now: Date) -> Bool {
        let files = enumerateGeminiSessionFiles()
        let activePaths = Set(files.map(\.path))
        geminiSessionModifiedAt = geminiSessionModifiedAt.filter { activePaths.contains($0.key) }

        var changed = false
        for file in files {
            let path = file.path
            let currentModified = Self.fileModificationDate(file) ?? .distantPast
            let knownModified = geminiSessionModifiedAt[path] ?? .distantPast
            guard currentModified > knownModified else { continue }
            geminiSessionModifiedAt[path] = currentModified

            guard let data = try? Data(contentsOf: file),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let messages = root["messages"] as? [[String: Any]] else { continue }

            for message in messages {
                guard let id = message["id"] as? String else { continue }
                if processedGeminiMessageIDs.contains(id) { continue }
                processedGeminiMessageIDs.insert(id)

                guard (message["type"] as? String) == "user",
                      let timestampRaw = message["timestamp"] as? String,
                      let timestamp = Self.parseISO8601(timestampRaw),
                      timestamp >= trackerStartedAt,
                      let content = message["content"] as? String else { continue }

                let hits = detectInvokedSlugs(in: content, candidates: slugs)
                for slug in hits where incrementUsage(slug: slug, provider: Provider.gemini.rawValue, now: now) {
                    changed = true
                }
            }
        }
        return changed
    }

    @discardableResult
    private func incrementUsage(slug: String, provider: String, now: Date) -> Bool {
        guard trackedFiles.contains(where: { $0.slug == slug && $0.provider == provider }) else { return false }
        if database.records[slug] == nil {
            database.records[slug] = SkillUsageRecord(slug: slug, entries: [:])
        }
        if database.records[slug]?.entries[provider] == nil {
            let baselineAtime = trackedFiles.first(where: { $0.slug == slug && $0.provider == provider })
                .flatMap { Self.fileAtime($0.url) } ?? now
            database.records[slug]?.entries[provider] = SkillUsageEntry(
                provider: provider,
                usageCount: 0,
                lastUsed: now,
                firstSeen: now,
                lastKnownAtime: baselineAtime
            )
        }
        database.records[slug]?.entries[provider]?.usageCount += 1
        database.records[slug]?.entries[provider]?.lastUsed = now
        return true
    }

    private func trackedSlugs(for provider: String) -> Set<String> {
        Set(trackedFiles.filter { $0.provider == provider }.map(\.slug))
    }

    private func detectInvokedSlugs(in text: String, candidates: Set<String>) -> Set<String> {
        guard !candidates.isEmpty else { return [] }
        let lowered = text.lowercased()
        var hits: Set<String> = []

        // Direct slash/$ command style (`/my-skill`, `$my-skill`)
        for token in Self.extractSlashOrDollarTokens(from: lowered) {
            let slug = SkillInventory.normalize(token)
            if candidates.contains(slug) {
                hits.insert(slug)
            }
        }

        // Natural-language invocation cues (`invoke my-skill`, `run my skill`).
        let actionWords = ["invoke", "run", "execute", "trigger"]
        for slug in candidates {
            let spaced = slug.replacingOccurrences(of: "-", with: " ")
            for action in actionWords {
                if lowered.contains("\(action) \(slug)") ||
                   lowered.contains("\(action) /\(slug)") ||
                   lowered.contains("\(action) $\(slug)") ||
                   lowered.contains("\(action) \(spaced)") {
                    hits.insert(slug)
                    break
                }
            }
        }

        return hits
    }

    private static func extractSlashOrDollarTokens(from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"(?<![\w.])[/$]([a-z0-9][a-z0-9._-]{1,})"#) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        return matches.compactMap { match in
            guard match.numberOfRanges >= 2,
                  let tokenRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[tokenRange])
        }
    }

    private static func parseJSONObject(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private static func codexUserMessage(from object: [String: Any]) -> String? {
        guard object["type"] as? String == "event_msg",
              let payload = object["payload"] as? [String: Any],
              payload["type"] as? String == "user_message",
              let message = payload["message"] as? String else {
            return nil
        }
        return message
    }

    private static func codexInvokedSkills(from object: [String: Any]) -> [String] {
        guard object["type"] as? String == "response_item",
              let payload = object["payload"] as? [String: Any],
              payload["type"] as? String == "function_call",
              let functionName = payload["name"] as? String else {
            return []
        }

        let normalizedFunction = functionName.lowercased()
        let isSkillFunction = normalizedFunction == "skill"
            || normalizedFunction == "invoke_skill"
            || normalizedFunction == "use_skill"
        guard isSkillFunction else { return [] }

        guard let argumentsRaw = payload["arguments"] as? String,
              let argumentsData = argumentsRaw.data(using: .utf8),
              let arguments = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] else {
            return []
        }

        if let skill = arguments["skill"] as? String { return [skill] }
        if let name = arguments["name"] as? String { return [name] }
        if let skillName = arguments["skill_name"] as? String { return [skillName] }
        return []
    }

    private static func claudeToolInvokedSkills(from object: [String: Any]) -> [String] {
        guard object["type"] as? String == "assistant",
              let message = object["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else {
            return []
        }

        var skills: [String] = []
        for item in content {
            guard item["type"] as? String == "tool_use",
                  let toolName = item["name"] as? String,
                  toolName.caseInsensitiveCompare("Skill") == .orderedSame,
                  let input = item["input"] as? [String: Any],
                  let skill = input["skill"] as? String else {
                continue
            }
            skills.append(skill)
        }
        return skills
    }

    private static func claudeUserText(from object: [String: Any]) -> String? {
        guard object["type"] as? String == "user",
              let message = object["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return nil
        }
        return content
    }

    private func readJSONLDelta(at url: URL, fromOffset offset: UInt64, remainder: String) -> (lines: [String], newOffset: UInt64, remainder: String)? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let fileSize = (try? handle.seekToEnd()) ?? offset
        let wasTruncated = offset > fileSize
        let safeOffset = min(offset, fileSize)
        if safeOffset < fileSize {
            try? handle.seek(toOffset: safeOffset)
        }
        guard let data = try? handle.readToEnd() else {
            return ([], fileSize, remainder)
        }
        if data.isEmpty {
            return ([], fileSize, wasTruncated ? "" : remainder)
        }

        let chunk = String(decoding: data, as: UTF8.self)
        let previousRemainder = wasTruncated ? "" : remainder
        let combined = previousRemainder + chunk
        if combined.isEmpty {
            return ([], fileSize, "")
        }

        let segments = combined.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let hasTrailingNewline = combined.hasSuffix("\n")
        let complete = segments.dropLast()
        let nextRemainder = hasTrailingNewline ? "" : (segments.last ?? "")

        let lines = complete
            .map { $0.trimmingCharacters(in: .newlines) }
            .filter { !$0.isEmpty }

        return (lines, fileSize, nextRemainder)
    }

    private func enumerateJSONLFiles(in root: URL) -> [URL] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue,
              let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsPackageDescendants]
              ) else {
            return []
        }

        var files: [URL] = []
        for case let url as URL in enumerator {
            if url.pathExtension.lowercased() == "jsonl" {
                files.append(url)
            }
        }
        return files
    }

    private func enumerateGeminiSessionFiles() -> [URL] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: Self.geminiTmpURL.path, isDirectory: &isDir), isDir.boolValue,
              let enumerator = fm.enumerator(
                at: Self.geminiTmpURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsPackageDescendants]
              ) else {
            return []
        }

        var files: [URL] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "json" else { continue }
            guard url.lastPathComponent.hasPrefix("session-"),
                  url.path.contains("/chats/") else { continue }
            files.append(url)
        }
        return files
    }

    private static func fileSize(_ url: URL) -> UInt64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return nil
        }
        return size.uint64Value
    }

    private static func fileModificationDate(_ url: URL) -> Date? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attributes[.modificationDate] as? Date
    }

    private static func parseISO8601(_ value: String) -> Date? {
        if let date = iso8601WithFractional.date(from: value) {
            return date
        }
        return iso8601.date(from: value)
    }

    // MARK: - File Stat

    private static func fileAtime(_ url: URL) -> Date? {
        var statBuf = stat()
        guard stat(url.path, &statBuf) == 0 else { return nil }
        let seconds = TimeInterval(statBuf.st_atimespec.tv_sec)
        let nanos = TimeInterval(statBuf.st_atimespec.tv_nsec) / 1_000_000_000
        return Date(timeIntervalSince1970: seconds + nanos)
    }
}
