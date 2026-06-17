import Foundation
import SwiftUI

enum Provider: String, CaseIterable, Identifiable, Equatable, Hashable {
    case codex
    case claude
    case openclaw
    case antigravity

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .claude: return "Claude"
        case .openclaw: return "OpenClaw"
        case .antigravity: return "Antigravity"
        }
    }

    var defaultRootPath: URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .codex: return home.appendingPathComponent(".codex/skills")
        case .claude: return home.appendingPathComponent(".claude/skills")
        case .antigravity: return home.appendingPathComponent(".gemini/skills")
        case .openclaw: return nil
        }
    }

    var badgeColor: Color {
        switch self {
        case .codex: return DS.Color.codexOnly
        case .claude: return DS.Color.claudeOnly
        case .openclaw: return DS.Color.openclawOnly
        case .antigravity: return DS.Color.antigravityOnly
        }
    }

    var badgeBgColor: Color {
        switch self {
        case .codex: return DS.Color.codexOnlyBg
        case .claude: return DS.Color.claudeOnlyBg
        case .openclaw: return DS.Color.openclawOnlyBg
        case .antigravity: return DS.Color.antigravityOnlyBg
        }
    }

    var spec: ProviderSpec {
        switch self {
        case .claude:
            return ProviderSpec(
                specURL: URL(string: "https://code.claude.com/docs/en/skills"),
                bestPracticesURL: nil,
                skillFileName: "SKILL.md",
                requiredFrontmatterFields: ["name", "description"],
                optionalFrontmatterFields: ["allowed-tools", "model", "context", "argument-hint", "disable-model-invocation", "user-invocable", "agent", "hooks", "license", "compatibility", "metadata"],
                specSummary: "Claude Code skills use Markdown files with YAML frontmatter. Skills define reusable prompts and tool permissions for Claude Code. 'name' and 'description' are required fields."
            )
        case .codex:
            return ProviderSpec(
                specURL: URL(string: "https://developers.openai.com/codex/skills"),
                bestPracticesURL: nil,
                skillFileName: "SKILL.md",
                requiredFrontmatterFields: ["name", "description"],
                optionalFrontmatterFields: ["version", "license"],
                specSummary: "Codex skills are Markdown files with YAML frontmatter defining reusable coding instructions and workflows."
            )
        case .openclaw:
            return ProviderSpec(
                specURL: URL(string: "https://github.com/openclaw/clawhub/blob/main/docs/skill-format.md"),
                bestPracticesURL: nil,
                skillFileName: "SKILL.md",
                requiredFrontmatterFields: ["name", "description"],
                optionalFrontmatterFields: ["version", "requires.env", "requires.bins"],
                specSummary: "OpenClaw skills follow the ClawHub skill format with support for environment and binary requirements."
            )
        case .antigravity:
            return ProviderSpec(
                specURL: URL(string: "https://antigravity.google/docs/skills"),
                bestPracticesURL: nil,
                skillFileName: "SKILL.md",
                requiredFrontmatterFields: ["name", "description"],
                optionalFrontmatterFields: [],
                specSummary: "Antigravity skills use Markdown files with YAML frontmatter, compatible with the Gemini skill ecosystem."
            )
        }
    }
}
