import Foundation

// MARK: - AI Evaluation Models

struct AIEvaluation: Codable, Equatable {
    let overallScore: Int
    let category: String
    let structureScore: Int
    let descriptionScore: Int
    let contentQualityScore: Int
    let issues: [AIEvaluationIssue]
    let suggestions: [String]
    let improvedDescription: String?
    let summary: String
}

struct AIEvaluationIssue: Codable, Equatable, Identifiable {
    var id: String { "\(field)-\(severity)-\(String(message.prefix(20)))" }
    let field: String     // "name", "description", "body", "structure"
    let severity: String  // "error", "warning", "suggestion"
    let message: String
}

// MARK: - Evaluation State

enum EvaluationState: Equatable {
    case idle
    case evaluating
    case completed(AIEvaluation)
    case failed(String)
}

// MARK: - Skill Improvement Models

struct SkillFileChange: Codable, Equatable, Identifiable {
    var id: String { relativePath }
    let relativePath: String    // "SKILL.md", "references/book-processing.md"
    let content: String         // full new file content
    let isNew: Bool
}

struct SkillImprovementPlan: Equatable {
    let skill: DiscoveredSkill
    let fileChanges: [SkillFileChange]
    let originalContents: [String: String]  // relativePath -> original content
}

enum ImprovementState: Equatable {
    case idle
    case generating
    case previewing(SkillImprovementPlan)
    case applying
    case applied
    case failed(String)
}

// MARK: - AI Backend

enum AIBackend: String, CaseIterable {
    case claudeCLI = "claude-cli"
    case anthropicAPI = "anthropic-api"
    case codexCLI = "codex-cli"
    case openAIAPI = "openai-api"
    case googleCLI = "google-cli"
    case googleAPI = "google-api"

    var displayName: String {
        switch self {
        case .claudeCLI: return "Claude CLI"
        case .anthropicAPI: return "Anthropic API"
        case .codexCLI: return "Codex CLI"
        case .openAIAPI: return "OpenAI API"
        case .googleCLI: return "Gemini CLI"
        case .googleAPI: return "Google AI API"
        }
    }

    var vendorGroup: String {
        switch self {
        case .claudeCLI, .anthropicAPI: return "Anthropic"
        case .codexCLI, .openAIAPI: return "OpenAI"
        case .googleCLI, .googleAPI: return "Google"
        }
    }

    var isCLI: Bool {
        switch self {
        case .claudeCLI, .codexCLI, .googleCLI: return true
        case .anthropicAPI, .openAIAPI, .googleAPI: return false
        }
    }

    var isAPI: Bool { !isCLI }

    var executableName: String {
        switch self {
        case .claudeCLI: return "claude"
        case .codexCLI: return "codex"
        case .googleCLI: return "gemini"
        case .anthropicAPI, .openAIAPI, .googleAPI: return ""
        }
    }

    static var vendorGroups: [(vendor: String, backends: [AIBackend])] {
        let order = ["Anthropic", "OpenAI", "Google"]
        let grouped = Dictionary(grouping: allCases, by: \.vendorGroup)
        return order.compactMap { vendor in
            guard let backends = grouped[vendor] else { return nil }
            return (vendor: vendor, backends: backends)
        }
    }
}
