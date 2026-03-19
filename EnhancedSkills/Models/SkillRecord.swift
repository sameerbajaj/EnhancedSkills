import Foundation

enum SkillStatus: String, Equatable {
    case synced, codexOnly, claudeOnly, openclawOnly, geminiOnly, antigravityOnly, conflict, invalid

    var displayName: String {
        switch self {
        case .synced: return "Synced"
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
        skills.values.reduce(0) { $0 + ($1.validationReport?.totalCount ?? 0) }
    }

    var hasGuidelineIssues: Bool { totalViolationCount > 0 }

    static func == (lhs: SkillRecord, rhs: SkillRecord) -> Bool {
        lhs.id == rhs.id &&
        lhs.displayName == rhs.displayName &&
        lhs.description == rhs.description &&
        lhs.status == rhs.status &&
        lhs.totalViolationCount == rhs.totalViolationCount &&
        lhs.skills.keys == rhs.skills.keys &&
        Provider.allCases.allSatisfy { lhs.skills[$0]?.parseStatus == rhs.skills[$0]?.parseStatus }
    }
}
