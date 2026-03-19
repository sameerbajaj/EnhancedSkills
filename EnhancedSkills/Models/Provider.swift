import SwiftUI

enum Provider: String, CaseIterable, Identifiable, Equatable, Hashable {
    case codex
    case claude
    case openclaw
    case gemini
    case antigravity

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .claude: return "Claude"
        case .openclaw: return "OpenClaw"
        case .gemini: return "Gemini"
        case .antigravity: return "Antigravity"
        }
    }

    var defaultRootPath: URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .codex: return home.appendingPathComponent(".codex/skills")
        case .claude: return home.appendingPathComponent(".claude/skills")
        case .gemini: return home.appendingPathComponent(".gemini/skills")
        case .antigravity: return home.appendingPathComponent(".gemini/antigravity/skills")
        case .openclaw: return nil
        }
    }

    var badgeColor: Color {
        switch self {
        case .codex: return DS.Color.codexOnly
        case .claude: return DS.Color.claudeOnly
        case .openclaw: return DS.Color.openclawOnly
        case .gemini: return DS.Color.geminiOnly
        case .antigravity: return DS.Color.antigravityOnly
        }
    }

    var badgeBgColor: Color {
        switch self {
        case .codex: return DS.Color.codexOnlyBg
        case .claude: return DS.Color.claudeOnlyBg
        case .openclaw: return DS.Color.openclawOnlyBg
        case .gemini: return DS.Color.geminiOnlyBg
        case .antigravity: return DS.Color.antigravityOnlyBg
        }
    }
}
