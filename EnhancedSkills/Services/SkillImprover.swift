import Foundation

enum SkillImprover {

    // MARK: - System Prompt

    private static let systemPrompt = """
    You are an expert skill author for AI coding assistants. You will be given:
    1. The current content of a skill's files (SKILL.md and any reference files)
    2. An AI evaluation with scores, issues, and suggestions
    3. A list of selected suggestions the user wants you to address

    Your job is to rewrite the skill files to address ONLY the selected suggestions. Rules:
    - Preserve the author's intent, voice, and domain knowledge
    - Only make changes that directly address the selected suggestions
    - If a suggestion says to move content to references/, create a new reference file and add a link in SKILL.md
    - Maintain valid YAML frontmatter with --- delimiters
    - Keep the name field in kebab-case
    - Ensure the description includes WHAT the skill does AND WHEN to use it (with trigger phrases)
    - Do not add XML angle brackets (< or >) anywhere
    - Keep SKILL.md under 5,000 words
    - Do not remove existing content unless a suggestion specifically calls for it

    ## Output Format
    Return ONLY valid JSON with this exact structure (no markdown, no explanation, just JSON):
    {
      "files": [
        {
          "relativePath": "SKILL.md",
          "content": "<full file content>",
          "isNew": false
        },
        {
          "relativePath": "references/example.md",
          "content": "<full file content>",
          "isNew": true
        }
      ]
    }

    Always include the full content of every file you modify or create. For files you don't change, do not include them.
    """

    // MARK: - Generate Improvements

    static func generateImprovements(
        skill: DiscoveredSkill,
        evaluation: AIEvaluation,
        selectedSuggestions: [String],
        backend: AIBackend,
        apiKey: String
    ) async throws -> [SkillFileChange] {
        // Read current SKILL.md
        let skillContent: String
        do {
            skillContent = try String(contentsOf: skill.skillMarkdownPath, encoding: .utf8)
        } catch {
            throw EvaluationError.noContent
        }

        // Read reference files if they exist
        var referenceContents: [(String, String)] = [] // (relativePath, content)
        let refsDir = skill.skillPath.appendingPathComponent("references")
        if let enumerator = FileManager.default.enumerator(at: refsDir, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                    let relativePath = "references/" + fileURL.lastPathComponent
                    referenceContents.append((relativePath, content))
                }
            }
        }

        // Build user prompt
        var userPrompt = """
        ## Current SKILL.md
        ```
        \(skillContent)
        ```

        """

        for (path, content) in referenceContents {
            userPrompt += """

            ## Current \(path)
            ```
            \(content)
            ```

            """
        }

        userPrompt += """

        ## Evaluation Summary
        Overall Score: \(evaluation.overallScore)/10
        Structure: \(evaluation.structureScore)/10
        Description: \(evaluation.descriptionScore)/10
        Content Quality: \(evaluation.contentQualityScore)/10

        Issues:
        \(evaluation.issues.map { "- [\($0.severity)] \($0.field): \($0.message)" }.joined(separator: "\n"))

        ## Selected Suggestions to Address
        \(selectedSuggestions.enumerated().map { "  \($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        Please rewrite the files to address these selected suggestions. Return the result as JSON.
        """

        let rawResponse = try await AIBackendRunner.run(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            backend: backend,
            apiKey: apiKey
        )

        return try parseFileChanges(from: rawResponse)
    }

    // MARK: - Parse Response

    private struct ImprovementResponse: Decodable {
        let files: [SkillFileChange]
    }

    private static func parseFileChanges(from text: String) throws -> [SkillFileChange] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = trimmed.data(using: .utf8),
           let response = try? JSONDecoder().decode(ImprovementResponse.self, from: data) {
            return response.files
        }

        if let jsonString = AIBackendRunner.extractJSONObject(from: trimmed),
           let data = jsonString.data(using: .utf8),
           let response = try? JSONDecoder().decode(ImprovementResponse.self, from: data) {
            return response.files
        }

        throw EvaluationError.invalidJSON(String(trimmed.prefix(300)))
    }

    // MARK: - Apply Changes

    static func applyChanges(plan: SkillImprovementPlan) throws {
        let fm = FileManager.default
        let skillDir = plan.skill.skillPath

        // Create backup
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupName = ".backup-\(timestamp)"
        let backupDir = skillDir.deletingLastPathComponent().appendingPathComponent(
            plan.skill.folderName + "-" + backupName
        )

        try fm.copyItem(at: skillDir, to: backupDir)

        // Write each file change
        for change in plan.fileChanges {
            let targetURL = skillDir.appendingPathComponent(change.relativePath)

            // Create parent directories if needed
            let parentDir = targetURL.deletingLastPathComponent()
            if !fm.fileExists(atPath: parentDir.path) {
                try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }

            try change.content.write(to: targetURL, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Build Plan

    static func buildPlan(skill: DiscoveredSkill, fileChanges: [SkillFileChange]) -> SkillImprovementPlan {
        let fm = FileManager.default
        var originalContents: [String: String] = [:]

        for change in fileChanges {
            let fileURL = skill.skillPath.appendingPathComponent(change.relativePath)
            if fm.fileExists(atPath: fileURL.path),
               let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                originalContents[change.relativePath] = content
            }
        }

        return SkillImprovementPlan(
            skill: skill,
            fileChanges: fileChanges,
            originalContents: originalContents
        )
    }
}
