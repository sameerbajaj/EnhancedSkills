import SwiftUI

public enum SkillCategory: String, Codable, CaseIterable, Identifiable {
    case gitAndVCS       = "Git & VCS"
    case codeQuality     = "Code Quality"
    case documentation   = "Documentation"
    case aiAndLLM        = "AI & LLM"
    case devOps          = "DevOps"
    case testing         = "Testing"
    case workflow        = "Workflow"
    case writing         = "Writing"
    case dataAndAPI      = "Data & API"
    case security        = "Security"
    case other           = "Other"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .gitAndVCS: return "arrow.triangle.pull"
        case .codeQuality: return "checkmark.shield.fill"
        case .documentation: return "doc.text.fill"
        case .aiAndLLM: return "sparkles"
        case .devOps: return "shippingbox.fill"
        case .testing: return "play.square.fill"
        case .workflow: return "arrow.3.trianglepath"
        case .writing: return "pencil.and.outline"
        case .dataAndAPI: return "network"
        case .security: return "lock.fill"
        case .other: return "questionmark.circle.fill"
        }
    }

    public var tint: Color {
        switch self {
        case .gitAndVCS: return Color(red: 0.85, green: 0.35, blue: 0.15)
        case .codeQuality: return Color(red: 0.15, green: 0.65, blue: 0.35)
        case .documentation: return Color(red: 0.45, green: 0.45, blue: 0.45)
        case .aiAndLLM: return Color(red: 0.55, green: 0.20, blue: 0.85)
        case .devOps: return Color(red: 0.10, green: 0.55, blue: 0.70)
        case .testing: return Color(red: 0.75, green: 0.15, blue: 0.35)
        case .workflow: return Color(red: 0.80, green: 0.55, blue: 0.10)
        case .writing: return Color(red: 0.65, green: 0.40, blue: 0.25)
        case .dataAndAPI: return Color(red: 0.10, green: 0.45, blue: 0.85)
        case .security: return Color(red: 0.60, green: 0.10, blue: 0.10)
        case .other: return Color(red: 0.50, green: 0.50, blue: 0.50)
        }
    }

    public var background: Color {
        tint.opacity(0.12)
    }
}
