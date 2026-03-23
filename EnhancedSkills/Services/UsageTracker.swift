import Foundation

final class UsageTracker {
    private let pollInterval: TimeInterval = 45
    private let selfReadWindow: TimeInterval = 5
    private let selfReadCleanupAge: TimeInterval = 120

    private var timer: Timer?
    private var trackedFiles: [(slug: String, provider: String, url: URL)] = []
    private var database: SkillUsageDatabase
    private var selfReadTimestamps: [URL: Date] = [:]
    private var isFirstPoll = true

    var onStatsUpdated: ((SkillUsageDatabase) -> Void)?

    private static var statsURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".enhanced-skills/usage-stats.json")
    }

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
        isFirstPoll = true

        // Record baselines for files we haven't seen before
        recordBaselines()

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

        if changed {
            database.lastPollTime = now
            save()
            onStatsUpdated?(database)
        }
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
