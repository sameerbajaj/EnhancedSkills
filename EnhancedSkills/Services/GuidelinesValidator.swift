import Foundation

struct GuidelinesValidator {

    // MARK: - Rule Definitions

    private static let commonRules: [GuidelineRule] = [
        GuidelineRule(
            id: "frontmatter-present",
            title: "Frontmatter present",
            detail: "Skill must have valid YAML frontmatter between --- delimiters",
            severity: .error,
            provider: nil,
            isAutoFixable: true
        ),
        GuidelineRule(
            id: "name-present",
            title: "Name field present",
            detail: "Frontmatter must include a non-empty 'name' field",
            severity: .error,
            provider: nil,
            isAutoFixable: true
        ),
        GuidelineRule(
            id: "description-present",
            title: "Description field present",
            detail: "Frontmatter must include a non-empty 'description' field",
            severity: .error,
            provider: nil,
            isAutoFixable: false
        ),
        GuidelineRule(
            id: "body-content",
            title: "Body has meaningful content",
            detail: "Skill body should contain content beyond headings",
            severity: .warning,
            provider: nil,
            isAutoFixable: false
        ),
    ]

    private static let claudeRules: [GuidelineRule] = [
        GuidelineRule(
            id: "claude-allowed-tools",
            title: "allowed-tools field recommended",
            detail: "Claude uses allowed-tools to know which tools the skill can invoke",
            severity: .warning,
            provider: .claude,
            isAutoFixable: true
        ),
        GuidelineRule(
            id: "claude-codex-artifacts",
            title: "No Codex-specific fields",
            detail: "Fields like 'version' or 'license' suggest an unmodified Codex copy",
            severity: .suggestion,
            provider: .claude,
            isAutoFixable: true
        ),
    ]

    private static let codexRules: [GuidelineRule] = [
        GuidelineRule(
            id: "codex-version",
            title: "version field recommended",
            detail: "Codex skills should include a version field",
            severity: .suggestion,
            provider: .codex,
            isAutoFixable: true
        ),
        GuidelineRule(
            id: "codex-scripts-consistency",
            title: "Scripts directory consistency",
            detail: "Body references scripts but no scripts/ directory exists",
            severity: .warning,
            provider: .codex,
            isAutoFixable: true
        ),
        GuidelineRule(
            id: "codex-claude-artifacts",
            title: "No Claude-specific fields",
            detail: "The 'allowed-tools' field suggests an unmodified Claude copy",
            severity: .suggestion,
            provider: .codex,
            isAutoFixable: true
        ),
    ]

    // MARK: - Validation

    static func validate(
        skill: DiscoveredSkill,
        frontmatter: ParsedFrontmatter?,
        body: String
    ) -> ValidationReport {
        let provider = skill.provider
        let providerRules: [GuidelineRule]
        switch provider {
        case .claude: providerRules = claudeRules
        case .codex: providerRules = codexRules
        case .openclaw: providerRules = []
        }
        let applicableRules = commonRules + providerRules

        var violations: [GuidelineViolation] = []
        var passed: [GuidelineRule] = []

        for rule in applicableRules {
            if let violation = check(rule: rule, skill: skill, frontmatter: frontmatter, body: body) {
                violations.append(violation)
            } else {
                passed.append(rule)
            }
        }

        violations.sort { $0.rule.severity < $1.rule.severity }

        return ValidationReport(provider: provider, violations: violations, passedRules: passed)
    }

    private static func check(
        rule: GuidelineRule,
        skill: DiscoveredSkill,
        frontmatter: ParsedFrontmatter?,
        body: String
    ) -> GuidelineViolation? {
        switch rule.id {

        case "frontmatter-present":
            if skill.parseStatus == .noFrontmatter || skill.parseStatus == .malformed {
                return GuidelineViolation(
                    rule: rule,
                    fixHint: "Add YAML frontmatter between --- delimiters at the top of SKILL.md"
                )
            }

        case "name-present":
            guard let fm = frontmatter else { return nil }  // covered by frontmatter-present
            let name = fm.scalars["name"] ?? ""
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return GuidelineViolation(
                    rule: rule,
                    fixHint: "Add 'name: Your Skill Name' to the frontmatter"
                )
            }

        case "description-present":
            guard let fm = frontmatter else { return nil }
            let desc = fm.scalars["description"] ?? ""
            if desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return GuidelineViolation(
                    rule: rule,
                    fixHint: "Add 'description: A brief description' to the frontmatter"
                )
            }

        case "body-content":
            let meaningful = body.components(separatedBy: "\n").contains { line in
                let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return !t.isEmpty && !t.hasPrefix("#")
            }
            if !meaningful {
                return GuidelineViolation(
                    rule: rule,
                    fixHint: "Add instructions or content to the skill body below the frontmatter"
                )
            }

        case "claude-allowed-tools":
            guard let fm = frontmatter else { return nil }
            if !fm.allKeys.contains("allowed-tools") {
                return GuidelineViolation(
                    rule: rule,
                    fixHint: "Add 'allowed-tools: <tool list>' to specify which tools this skill can use"
                )
            }

        case "claude-codex-artifacts":
            guard let fm = frontmatter else { return nil }
            let codexFields = fm.allKeys.intersection(["version", "license"])
            if !codexFields.isEmpty {
                let fields = codexFields.sorted().joined(separator: ", ")
                return GuidelineViolation(
                    rule: rule,
                    fixHint: "Consider removing Codex-specific fields: \(fields)"
                )
            }

        case "codex-version":
            guard let fm = frontmatter else { return nil }
            if !fm.allKeys.contains("version") {
                return GuidelineViolation(
                    rule: rule,
                    fixHint: "Add 'version: 1.0' to the frontmatter"
                )
            }

        case "codex-scripts-consistency":
            let refsScripts = body.lowercased().contains("scripts/") ||
                              body.lowercased().contains("script")
            if refsScripts && !skill.hasScripts {
                return GuidelineViolation(
                    rule: rule,
                    fixHint: "Create a scripts/ directory or remove script references from the body"
                )
            }

        case "codex-claude-artifacts":
            guard let fm = frontmatter else { return nil }
            if fm.allKeys.contains("allowed-tools") {
                return GuidelineViolation(
                    rule: rule,
                    fixHint: "Consider removing the Claude-specific 'allowed-tools' field"
                )
            }

        default:
            break
        }

        return nil
    }
}
