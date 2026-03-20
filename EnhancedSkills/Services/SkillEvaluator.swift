import Foundation

// MARK: - Errors

enum EvaluationError: LocalizedError {
    case cliNotFound(String)
    case executionFailed(exitCode: Int32, stderr: String)
    case invalidJSON(String)
    case timeout
    case noContent
    case missingAPIKey
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .cliNotFound(let name):
            return "\(name) not found. Make sure it is installed and in your PATH."
        case .executionFailed(let code, let stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty
                ? "CLI exited with code \(code)."
                : "CLI exited with code \(code): \(detail.prefix(200))"
        case .invalidJSON(let preview):
            return "Could not parse AI response as JSON. Preview: \(preview.prefix(200))"
        case .timeout:
            return "Evaluation timed out after 90 seconds."
        case .noContent:
            return "SKILL.md is empty or could not be read."
        case .missingAPIKey:
            return "API key is not set. Add it in Settings → AI."
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

// MARK: - SkillEvaluator

enum SkillEvaluator {

    // MARK: Best Practices System Prompt

    private static let systemPrompt = """
    You are an expert skill quality evaluator for AI coding assistants. Analyze the provided SKILL.md content and return a structured JSON evaluation.

    ## Structure Rules
    - Skill folder should use kebab-case (lowercase letters, numbers, and hyphens only, no spaces/underscores/capitals)
    - SKILL.md must be exactly that name (case-sensitive)
    - YAML frontmatter must have --- delimiters at top and bottom
    - Optional directories that improve quality: scripts/ (executable code), examples/ (sample usage)
    - All frontmatter fields are optional; 'description' is recommended

    ## Name Field Rules
    - Lowercase letters, numbers, and hyphens only (max 64 characters)
    - No spaces, underscores, or capital letters
    - Should match the skill folder name

    ## Description Field Rules (CRITICAL - this is how the AI decides when to load the skill)
    - MUST include WHAT the skill does AND WHEN to use it (trigger phrases users would say)
    - Note: all skill descriptions share a combined budget of ~2% of context window (fallback 16,000 chars), so keep descriptions concise
    - Include specific trigger phrases users would actually type
    - Good example: "Analyzes Figma design files and generates developer handoff documentation. Use when user uploads .fig files, asks for 'design specs', 'component documentation', or 'design-to-code handoff'."
    - Bad examples: "Helps with projects." (too vague), "Creates sophisticated multi-page documentation systems." (no trigger phrases), "Implements the Project entity model." (too technical, no user triggers)

    ## Content Quality Rules
    - Include a "Gotchas" or "Common Issues" section capturing failure points the AI should avoid
    - Use progressive disclosure: keep SKILL.md focused on core instructions, move detailed docs to supporting files with explicit links
    - Avoid railroading: give the AI enough info but allow flexibility to adapt to the situation
    - Instructions should be specific and actionable, not vague ("Run `python scripts/validate.py --input {filename}`" not "Validate the data")
    - Include error handling guidance for common failure cases
    - Reference any bundled scripts or reference files explicitly so the AI knows they exist
    - Keep SKILL.md under 500 lines (very long files degrade performance)
    - Consider using string substitutions ($ARGUMENTS, ${CLAUDE_SKILL_DIR}) for dynamic content

    ## Skill Categories (app-defined)
    Classify into exactly one of:
    1. Library & API Reference - explains how to correctly use a library, CLI, or SDK
    2. Product Verification - tests or verifies that code is working (often uses playwright, tmux, etc.)
    3. Data Fetching & Analysis - connects to data and monitoring stacks
    4. Business Process & Team Automation - automates repetitive team workflows
    5. Code Scaffolding & Templates - generates framework boilerplate for a specific codebase
    6. Code Quality & Review - enforces code quality and review standards
    7. CI/CD & Deployment - helps fetch, push, and deploy code
    8. Runbooks - takes a symptom, investigates via multi-tool workflow, produces a report
    9. Infrastructure Operations - routine maintenance and operational procedures

    ## Output Format
    Return ONLY valid JSON with this exact structure (no markdown, no explanation, just JSON):
    {
      "overallScore": <integer 1-10>,
      "category": "<one of the 9 category names above>",
      "structureScore": <integer 1-10>,
      "descriptionScore": <integer 1-10>,
      "contentQualityScore": <integer 1-10>,
      "issues": [
        {
          "field": "<name|description|body|structure>",
          "severity": "<error|warning|suggestion>",
          "message": "<specific, actionable improvement message>"
        }
      ],
      "suggestions": ["<suggestion 1>", "<suggestion 2>"],
      "improvedDescription": "<rewritten description if current one scores below 7, otherwise null>",
      "summary": "<1-2 sentence overall assessment>"
    }

    Score guide: 9-10 = excellent, 7-8 = good, 5-6 = needs improvement, 3-4 = poor, 1-2 = failing.
    """

    // MARK: - Main Entry Point

    static func evaluate(skill: DiscoveredSkill, backend: AIBackend, apiKey: String = "") async throws -> AIEvaluation {
        let content: String
        do {
            content = try String(contentsOf: skill.skillMarkdownPath, encoding: .utf8)
        } catch {
            throw EvaluationError.noContent
        }

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EvaluationError.noContent
        }

        let truncated = content.count > 35_000 ? String(content.prefix(35_000)) + "\n\n[...truncated]" : content

        let providerContext = skill.provider.spec.promptContext
        let fullSystemPrompt = systemPrompt + "\n\n" + providerContext

        let userPrompt = """
        Evaluate this skill (provider: \(skill.provider.displayName), folder: \(skill.folderName)):

        \(truncated)
        """

        let rawResponse = try await AIBackendRunner.run(
            systemPrompt: fullSystemPrompt,
            userPrompt: userPrompt,
            backend: backend,
            apiKey: apiKey
        )

        return try extractEvaluation(from: rawResponse)
    }

    // MARK: - JSON Extraction

    private static func extractEvaluation(from text: String) throws -> AIEvaluation {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = trimmed.data(using: .utf8),
           let evaluation = try? JSONDecoder().decode(AIEvaluation.self, from: data) {
            return evaluation
        }

        if let jsonString = AIBackendRunner.extractJSONObject(from: trimmed),
           let data = jsonString.data(using: .utf8),
           let evaluation = try? JSONDecoder().decode(AIEvaluation.self, from: data) {
            return evaluation
        }

        throw EvaluationError.invalidJSON(String(trimmed.prefix(300)))
    }

    // MARK: - Test Backend

    static func testBackend(_ backend: AIBackend, apiKey: String?) async -> Result<String, Error> {
        do {
            let _ = try await AIBackendRunner.run(
                systemPrompt: "You are a helpful assistant.",
                userPrompt: "Say hello in one word.",
                backend: backend,
                apiKey: apiKey ?? ""
            )
            return .success("Connection successful")
        } catch {
            return .failure(error)
        }
    }
}
