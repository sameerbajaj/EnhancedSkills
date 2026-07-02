import Foundation

struct ClassificationResponse: Codable {
    let category: String
}

enum SkillClassifier {
    private static let systemPrompt = """
    You are an expert developer skill categorizer. Analyze the provided skill information and classify it into exactly one of the following categories:

    - "Git & VCS"
    - "Code Quality"
    - "Documentation"
    - "AI & LLM"
    - "DevOps"
    - "Testing"
    - "Workflow"
    - "Writing"
    - "Data & API"
    - "Security"
    - "Other"

    Respond with ONLY valid JSON containing a single key "category" whose value is exactly one of the category names listed above (e.g. {"category": "Git & VCS"}). Do not include any other text, markdown, or explanation.
    """

    static func classify(
        displayName: String,
        description: String?,
        contentExcerpt: String,
        backend: AIBackend,
        apiKey: String = ""
    ) async throws -> SkillCategory {
        let truncatedExcerpt = contentExcerpt.count > 1000 ? String(contentExcerpt.prefix(1000)) + "\n[...]" : contentExcerpt
        let userPrompt = """
        Classify this skill:
        Name: \(displayName)
        Description: \(description ?? "None")
        Excerpt from SKILL.md:
        ---
        \(truncatedExcerpt)
        ---
        """

        let rawResponse = try await AIBackendRunner.run(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            backend: backend,
            apiKey: apiKey
        )

        return parseCategory(from: rawResponse)
    }

    static func classify(
        skill: DiscoveredSkill,
        backend: AIBackend,
        apiKey: String = ""
    ) async throws -> SkillCategory {
        let content = (try? String(contentsOf: skill.skillMarkdownPath, encoding: .utf8)) ?? ""
        let excerpt = content.count > 1200 ? String(content.prefix(1200)) : content
        
        return try await classify(
            displayName: skill.parsedName ?? skill.folderName,
            description: skill.parsedDescription,
            contentExcerpt: excerpt,
            backend: backend,
            apiKey: apiKey
        )
    }

    private static func parseCategory(from text: String) -> SkillCategory {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        func matchCategory(_ str: String) -> SkillCategory? {
            let normalized = str.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            for cat in SkillCategory.allCases {
                if cat.rawValue.lowercased() == normalized {
                    return cat
                }
            }
            return nil
        }

        // Try direct JSON decode
        if let data = trimmed.data(using: .utf8),
           let resp = try? JSONDecoder().decode(ClassificationResponse.self, from: data),
           let matched = matchCategory(resp.category) {
            return matched
        }

        // Try extracting JSON block
        if let jsonString = AIBackendRunner.extractJSONObject(from: trimmed),
           let data = jsonString.data(using: .utf8),
           let resp = try? JSONDecoder().decode(ClassificationResponse.self, from: data),
           let matched = matchCategory(resp.category) {
            return matched
        }

        // Fuzzy match fallback: check if category names are present in response text
        for cat in SkillCategory.allCases {
            if trimmed.localizedCaseInsensitiveContains(cat.rawValue) {
                return cat
            }
        }

        return .other
    }
}
