import SwiftUI

enum Provider: String, CaseIterable, Identifiable, Equatable {
    case codex
    case claude
    case openclaw

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .claude: return "Claude"
        case .openclaw: return "OpenClaw"
        }
    }

    var defaultRootPath: URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .codex: return home.appendingPathComponent(".codex/skills")
        case .claude: return home.appendingPathComponent(".claude/skills")
        case .openclaw: return nil
        }
    }

    var badgeColor: Color {
        switch self {
        case .codex: return DS.Color.codexOnly
        case .claude: return DS.Color.claudeOnly
        case .openclaw: return DS.Color.openclawOnly
        }
    }

    var badgeBgColor: Color {
        switch self {
        case .codex: return DS.Color.codexOnlyBg
        case .claude: return DS.Color.claudeOnlyBg
        case .openclaw: return DS.Color.openclawOnlyBg
        }
    }
}
