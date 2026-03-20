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
    You are an expert skill quality evaluator for AI coding assistants. Analyze the provided SKILL.md content and return a structured JSON evaluation. Your evaluation criteria are aligned with Anthropic's official "Complete Guide to Building Skills for Claude."

    ## Structure Rules
    - Skill folder must use kebab-case (lowercase letters, numbers, and hyphens only, no spaces/underscores/capitals)
    - SKILL.md must be exactly that name (case-sensitive)
    - YAML frontmatter must have --- delimiters at top and bottom
    - No README.md inside the skill folder (all documentation belongs in SKILL.md or references/)
    - Optional directories: scripts/ (executable code), references/ (detailed documentation), assets/ (bundled resources)
    - All documentation should go in SKILL.md or references/

    ## Name Field Rules (REQUIRED)
    - Name is REQUIRED, not optional
    - Lowercase letters, numbers, and hyphens only (kebab-case, max 64 characters)
    - No spaces, underscores, or capital letters
    - Should match the skill folder name
    - Must NOT contain "claude" or "anthropic" (reserved names)

    ## Description Field Rules (REQUIRED — this is how the AI decides when to load the skill)
    - Description is REQUIRED, not optional
    - MUST include: WHAT it does + WHEN to use it (trigger conditions) + Key capabilities
    - Must be under 1,024 characters
    - Must NOT contain XML angle brackets (< or >)
    - Include specific tasks users might say, mention file types if relevant
    - Note: all skill descriptions share a combined budget of ~2% of context window, so keep descriptions concise
    - Good examples:
      * "Analyzes Figma design files and generates developer handoff documentation. Use when user uploads .fig files, asks for 'design specs', 'component documentation', or 'design-to-code handoff'. Supports component inventory, spacing analysis, and design token extraction."
      * "Manages Linear project workflows including issue creation, sprint planning, and status updates. Use when user mentions 'create issue', 'plan sprint', 'update ticket status', or references Linear project names."
      * "Guides new team members through PayFlow onboarding setup. Use when user says 'set up dev environment', 'onboarding', or 'getting started with PayFlow'. Covers repo cloning, dependency installation, and local environment configuration."
    - Bad examples:
      * "Helps with projects." (too vague, no triggers or capabilities)
      * "Creates sophisticated multi-page documentation systems." (no trigger phrases, overly grandiose)
      * "Implements the Project entity model with hierarchical relationships." (too technical, no user triggers)

    ## Content Quality Rules
    - Recommended structure: # Skill Name → ## Instructions → ### Step N → Examples → Troubleshooting
    - Be specific and actionable: "Run `python scripts/validate.py --input {filename}`" not "Validate the data before proceeding"
    - Include a "Common Issues" or "Troubleshooting" section with specific errors, causes, and solutions
    - Reference bundled resources clearly: explicitly mention files in references/ and scripts/
    - Use progressive disclosure: keep SKILL.md focused on core instructions, move detailed docs to references/
    - Keep SKILL.md under 5,000 words (very long files degrade AI performance)
    - Use bullet points and numbered lists to keep instructions concise
    - Put critical instructions at the top; use ## Important or ## Critical headers
    - Avoid ambiguous language: "Make sure to validate things properly" is bad; a specific validation checklist is good
    - Consider adding ## Performance Notes with explicit encouragement ("Take your time", "Quality is more important than speed") to address model laziness
    - Consider using string substitutions ($ARGUMENTS, ${CLAUDE_SKILL_DIR}) for dynamic content
    - Avoid railroading: give the AI enough info but allow flexibility to adapt to the situation

    ## Skill Categories
    Classify into exactly one of these 3 categories (from Anthropic's official guide):
    1. Document & Asset Creation — Skills that produce consistent, high-quality output such as documents, presentations, applications, designs, or code artifacts
    2. Workflow Automation — Skills that codify multi-step processes benefiting from a consistent methodology
    3. MCP Enhancement — Skills that provide workflow guidance to enhance MCP server tool access

    ## Output Format
    Return ONLY valid JSON with this exact structure (no markdown, no explanation, just JSON):
    {
      "overallScore": <integer 1-10>,
      "category": "<one of: Document & Asset Creation, Workflow Automation, MCP Enhancement>",
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
      "improvedDescription": "<rewritten description following the WHAT + WHEN + Key capabilities formula if current one scores below 7, otherwise null>",
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
