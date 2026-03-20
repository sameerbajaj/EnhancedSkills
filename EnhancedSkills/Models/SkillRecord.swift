import Foundation

enum SkillStatus: String, Equatable {
    case synced, needsSync, codexOnly, claudeOnly, openclawOnly, geminiOnly, antigravityOnly, conflict, invalid

    var displayName: String {
        switch self {
        case .synced: return "Synced"
        case .needsSync: return "Needs Sync"
        case .codexOnly: return "Codex Only"
        case .claudeOnly: return "Claude Only"
        case .openclawOnly: return "OpenClaw Only"
        case .geminiOnly: return "Gemini Only"
        case .antigravityOnly: return "Antigravity Only"
        case .conflict: return "Conflict"
        case .invalid: return "Invalid"
        }
    }

    static func onlyStatus(for provider: Provider) -> SkillStatus {
        switch provider {
        case .codex: return .codexOnly
        case .claude: return .claudeOnly
        case .openclaw: return .openclawOnly
        case .gemini: return .geminiOnly
        case .antigravity: return .antigravityOnly
        }
    }
}

struct SkillRecord: Identifiable, Equatable {
    let id: String
    var displayName: String
    var description: String?
    var slug: String
    var skills: [Provider: DiscoveredSkill] = [:]
    var status: SkillStatus
    var syncEnabled: Bool = false
    var tags: [String]
    var lastModified: Date?

    // Convenience accessors for backward compat
    var codexSkill: DiscoveredSkill? { skills[.codex] }
    var claudeSkill: DiscoveredSkill? { skills[.claude] }
    var openclawSkill: DiscoveredSkill? { skills[.openclaw] }
    var geminiSkill: DiscoveredSkill? { skills[.gemini] }
    var antigravitySkill: DiscoveredSkill? { skills[.antigravity] }

    func skill(for provider: Provider) -> DiscoveredSkill? { skills[provider] }

    var preferredPreviewSource: DiscoveredSkill? {
        for p in Provider.allCases {
            if let s = skills[p] { return s }
        }
        return nil
    }

    var totalViolationCount: Int {
        skills.values.reduce(0) {
            $0 + ($1.validationReport?.errorCount ?? 0) + ($1.validationReport?.warningCount ?? 0)
        }
    }

    var hasGuidelineIssues: Bool { totalViolationCount > 0 }

    var githubOrigin: GitHubOrigin? {
        skills.values.first(where: { $0.githubOrigin != nil })?.githubOrigin
    }

    var githubSyncStatus: GitHubSyncStatus {
        let linkedSkills = skills.values.filter { $0.githubOrigin != nil }
        guard !linkedSkills.isEmpty else { return .notLinked }
        let statuses = linkedSkills.map { $0.githubSyncStatus }
        for status in statuses { if case .diverged = status { return .diverged } }
        for status in statuses { if case .error = status { return status } }
        if statuses.contains(.checking) { return .checking }
        if statuses.contains(.localAhead) { return .localAhead }
        if statuses.contains(.remoteAhead) { return .remoteAhead }
        if statuses.contains(.inSync) { return .inSync }
        return .notLinked
    }

    static func == (lhs: SkillRecord, rhs: SkillRecord) -> Bool {
        lhs.id == rhs.id &&
        lhs.displayName == rhs.displayName &&
        lhs.description == rhs.description &&
        lhs.status == rhs.status &&
        lhs.syncEnabled == rhs.syncEnabled &&
        lhs.totalViolationCount == rhs.totalViolationCount &&
        lhs.githubSyncStatus == rhs.githubSyncStatus &&
        lhs.skills.keys == rhs.skills.keys &&
        Provider.allCases.allSatisfy { lhs.skills[$0]?.parseStatus == rhs.skills[$0]?.parseStatus }
    }
}
