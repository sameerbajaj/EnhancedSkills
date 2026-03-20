import Foundation

// MARK: - Per-Provider Usage Entry

struct SkillUsageEntry: Codable, Equatable {
    var provider: String
    var usageCount: Int
    var lastUsed: Date
    var firstSeen: Date
    var lastKnownAtime: Date
}

// MARK: - Per-Skill Usage Record

struct SkillUsageRecord: Codable, Equatable {
    var slug: String
    var entries: [String: SkillUsageEntry]  // keyed by provider rawValue

    var totalUsageCount: Int {
        entries.values.reduce(0) { $0 + $1.usageCount }
    }

    var lastUsedAcrossProviders: Date? {
        entries.values.map(\.lastUsed).max()
    }
}

// MARK: - Top-Level Database

struct SkillUsageDatabase: Codable, Equatable {
    var version: Int = 1
    var records: [String: SkillUsageRecord] = [:]  // keyed by slug
    var lastPollTime: Date?
}
