import Foundation

public struct ProposedCategory: Codable, Identifiable, Equatable {
    public var id: String { name }
    public var name: String
    public var shortLabel: String
    public let count: Int
    public let reason: String

    public init(name: String, shortLabel: String? = nil, count: Int, reason: String) {
        self.name = name
        self.shortLabel = shortLabel ?? String(name.prefix(15))
        self.count = count
        self.reason = reason
    }
}

struct ClassificationResponse: Codable {
    let category: String
}

enum SkillClassifier {
    private static let discoverySystemPrompt = """
    You are an expert developer skill taxonomist. Your task is to analyze a list of developer skills (names and descriptions) and propose 5-7 meaningful, organic categories that cluster them nicely.

    Propose categories that are high-level and clear (e.g. "Research & Analysis", "Content Creation", "Obsidian & PKM", "Task Management", "Git & DevOps", "Web Automation").

    Return ONLY a valid JSON object containing an array "categories". Each category must have:
    - "name": String (2-4 words, capitalized, the full descriptive name)
    - "shortLabel": String (max 15 characters, a concise abbreviation for compact UI display, e.g. "SEO" for "Search Engine Optimization", "Research" for "Research & Automation", "Git & DevOps" for "Git & DevOps")
    - "reason": String (1-sentence reason why these skills belong together)
    - "count": Integer (approximate number of skills in this category)

    JSON Format Example:
    {
      "categories": [
        {
          "name": "Research & Analysis",
          "shortLabel": "Research",
          "reason": "Skills focused on gathering, summarizing, and processing data.",
          "count": 12
        }
      ]
    }
    """

    private static func classificationSystemPrompt(taxonomy: [String]) -> String {
        let taxonomyList = taxonomy.map { "\"\($0)\"" }.joined(separator: ", ")
        return """
        You are an expert developer skill classifier. Analyze the provided skill and classify it into EXACTLY ONE of the following approved categories:

        [\(taxonomyList)]

        If the skill does not fit any category well, or if you are unsure, default to one of the closest categories or choose the category that fits best.

        Respond with ONLY valid JSON containing a single key "category" whose value is exactly one of the category names listed above (e.g. {"category": "Research & Analysis"}). Do not include any other text, markdown, or explanation.
        """
    }

    struct DiscoveryResponse: Codable {
        let categories: [ProposedCategory]
    }

    static func discoverTaxonomy(
        records: [SkillRecord],
        backend: AIBackend,
        apiKey: String = ""
    ) async throws -> [ProposedCategory] {
        var userPrompt = "Propose categories for the following developer skills:\n\n"
        for (index, record) in records.enumerated() {
            let desc = record.description ?? "No description"
            userPrompt += "\(index + 1). Name: \(record.displayName) (Slug: \(record.slug))\n   Description: \(desc)\n\n"
        }

        let rawResponse = try await AIBackendRunner.run(
            systemPrompt: discoverySystemPrompt,
            userPrompt: userPrompt,
            backend: backend,
            apiKey: apiKey
        )

        let trimmed = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        
        func decodeResponse(from text: String) -> [ProposedCategory]? {
            guard let data = text.data(using: .utf8) else { return nil }
            return (try? JSONDecoder().decode(DiscoveryResponse.self, from: data))?.categories
        }

        if let categories = decodeResponse(from: trimmed) {
            return categories
        }

        if let jsonString = AIBackendRunner.extractJSONObject(from: trimmed),
           let categories = decodeResponse(from: jsonString) {
            return categories
        }

        throw EvaluationError.invalidJSON(String(trimmed.prefix(300)))
    }

    static func classify(
        skill: DiscoveredSkill,
        taxonomy: [String],
        backend: AIBackend,
        apiKey: String = ""
    ) async throws -> SkillCategory {
        let content = (try? String(contentsOf: skill.skillMarkdownPath, encoding: .utf8)) ?? ""
        let excerpt = content.count > 1200 ? String(content.prefix(1200)) : content
        
        let systemPrompt = classificationSystemPrompt(taxonomy: taxonomy)
        
        let truncatedExcerpt = excerpt.count > 1000 ? String(excerpt.prefix(1000)) + "\n[...]" : excerpt
        let userPrompt = """
        Classify this skill:
        Name: \(skill.parsedName ?? skill.folderName)
        Description: \(skill.parsedDescription ?? "None")
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

        guard let parsed = parseCategory(from: rawResponse, taxonomy: taxonomy) else {
            throw EvaluationError.invalidJSON("Failed to parse classification category from LLM output: \(rawResponse)")
        }
        return parsed
    }

    private static func parseCategory(from text: String, taxonomy: [String]) -> SkillCategory? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        func matchCategory(_ str: String) -> SkillCategory? {
            let normalized = str.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            for name in taxonomy {
                if name.lowercased() == normalized {
                    return SkillCategory(name: name)
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
        for name in taxonomy {
            if trimmed.localizedCaseInsensitiveContains(name) {
                return SkillCategory(name: name)
            }
        }

        return nil
    }
}
