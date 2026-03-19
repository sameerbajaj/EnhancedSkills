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

// MARK: - AI Backend

enum AIBackend: String, CaseIterable {
    case claudeCLI = "claude-cli"
    case codexCLI = "codex-cli"

    var displayName: String {
        switch self {
        case .claudeCLI: return "Claude CLI"
        case .codexCLI: return "Codex CLI"
        }
    }

    var executableName: String {
        switch self {
        case .claudeCLI: return "claude"
        case .codexCLI: return "codex"
        }
    }
}
