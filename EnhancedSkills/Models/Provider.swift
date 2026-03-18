import SwiftUI

enum Provider: String, CaseIterable, Identifiable, Equatable {
    case codex
    case claude

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .claude: return "Claude"
        }
    }

    var defaultRootPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .codex: return home.appendingPathComponent(".codex/skills")
        case .claude: return home.appendingPathComponent(".claude/skills")
        }
    }

    var badgeColor: Color {
        switch self {
        case .codex: return DS.Color.codexOnly
        case .claude: return DS.Color.claudeOnly
        }
    }

    var badgeBgColor: Color {
        switch self {
        case .codex: return DS.Color.codexOnlyBg
        case .claude: return DS.Color.claudeOnlyBg
        }
    }
}
