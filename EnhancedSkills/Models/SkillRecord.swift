import Foundation

enum SkillStatus: String, Equatable {
    case synced, codexOnly, claudeOnly, openclawOnly, conflict, invalid

    var displayName: String {
        switch self {
        case .synced: return "Synced"
        case .codexOnly: return "Codex Only"
        case .claudeOnly: return "Claude Only"
        case .openclawOnly: return "OpenClaw Only"
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
    var openclawSkill: DiscoveredSkill?
    var status: SkillStatus
    var tags: [String]
    var lastModified: Date?

    var preferredPreviewSource: DiscoveredSkill? { codexSkill ?? claudeSkill ?? openclawSkill }

    var totalViolationCount: Int {
        (codexSkill?.validationReport?.totalCount ?? 0) +
        (claudeSkill?.validationReport?.totalCount ?? 0) +
        (openclawSkill?.validationReport?.totalCount ?? 0)
    }

    var hasGuidelineIssues: Bool { totalViolationCount > 0 }

    static func == (lhs: SkillRecord, rhs: SkillRecord) -> Bool {
        lhs.id == rhs.id &&
        lhs.displayName == rhs.displayName &&
        lhs.description == rhs.description &&
        lhs.status == rhs.status &&
        lhs.totalViolationCount == rhs.totalViolationCount &&
        lhs.codexSkill?.parseStatus == rhs.codexSkill?.parseStatus &&
        lhs.claudeSkill?.parseStatus == rhs.claudeSkill?.parseStatus &&
        lhs.openclawSkill?.parseStatus == rhs.openclawSkill?.parseStatus
    }
}
