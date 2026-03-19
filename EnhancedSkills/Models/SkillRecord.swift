import Foundation

enum SkillStatus: String, Equatable {
    case synced, codexOnly, claudeOnly, conflict, invalid

    var displayName: String {
        switch self {
        case .synced: return "Synced"
        case .codexOnly: return "Codex Only"
        case .claudeOnly: return "Claude Only"
        case .conflict: return "Conflict"
        case .invalid: return "Invalid"
        }
    }
}

struct SkillRecord: Identifiable, Equatable {
    let id: String
    var displayName: String
    var description: String?
    var slug: String
    var codexSkill: DiscoveredSkill?
    var claudeSkill: DiscoveredSkill?
    var status: SkillStatus
    var tags: [String]
    var lastModified: Date?

    var preferredPreviewSource: DiscoveredSkill? { codexSkill ?? claudeSkill }

    var totalViolationCount: Int {
        (codexSkill?.validationReport?.totalCount ?? 0) +
        (claudeSkill?.validationReport?.totalCount ?? 0)
    }

    var hasGuidelineIssues: Bool { totalViolationCount > 0 }

    static func == (lhs: SkillRecord, rhs: SkillRecord) -> Bool {
        lhs.id == rhs.id
    }
}
