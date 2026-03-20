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
            title: "Name field required",
            detail: "Frontmatter must include a 'name' field (required per Anthropic's official skill guide)",
            severity: .error,
            provider: nil,
            isAutoFixable: true
        ),
        GuidelineRule(
            id: "description-present",
            title: "Description field required",
            detail: "Frontmatter must include a 'description' field (required — this is how the AI decides when to load the skill)",
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
        GuidelineRule(
            id: "no-readme",
            title: "No README.md in skill folder",
            detail: "Skill folders must not contain a README.md — all documentation belongs in SKILL.md or references/",
            severity: .error,
            provider: nil,
            isAutoFixable: false
        ),
        GuidelineRule(
            id: "description-length",
            title: "Description under 1024 characters",
            detail: "Description must be under 1,024 characters per Anthropic's official guide",
            severity: .warning,
            provider: nil,
            isAutoFixable: false
        ),
        GuidelineRule(
            id: "no-xml-in-frontmatter",
            title: "No XML angle brackets in frontmatter",
            detail: "Frontmatter must not contain '<' or '>' characters (XML tags are not allowed)",
            severity: .error,
            provider: nil,
            isAutoFixable: false
        ),
        GuidelineRule(
            id: "no-reserved-names",
            title: "No reserved words in name",
            detail: "Skill name must not contain 'claude' or 'anthropic' (reserved names)",
            severity: .error,
            provider: nil,
            isAutoFixable: false
        ),
        GuidelineRule(
            id: "skill-size",
            title: "SKILL.md under 5,000 words",
            detail: "SKILL.md should not exceed 5,000 words — very long files degrade AI performance",
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
            detail: "The 'version' field suggests an unmodified Codex copy",
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
        default: providerRules = [] // OpenClaw, Gemini, Antigravity use common rules only
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

        // Dynamic spec-based field checks
        if let fm = frontmatter {
            let existingRuleFields: Set<String> = ["name", "description"]
            let existingOptionalFields: Set<String> = ["allowed-tools", "version"]

            let spec = provider.spec
            for field in spec.requiredFrontmatterFields where !existingRuleFields.contains(field) {
                let rule = GuidelineRule(
                    id: "spec-required-\(field)",
                    title: "\(field) field required",
                    detail: "Provider spec requires '\(field)' in frontmatter",
                    severity: .error,
                    provider: provider,
                    isAutoFixable: false
                )
                if !fm.allKeys.contains(field) {
                    violations.append(GuidelineViolation(rule: rule, fixHint: "Add '\(field)' to the frontmatter"))
                } else {
                    passed.append(rule)
                }
            }

            for field in spec.optionalFrontmatterFields where !existingOptionalFields.contains(field) {
                let rule = GuidelineRule(
                    id: "spec-optional-\(field)",
                    title: "\(field) field recommended",
                    detail: "Provider spec recommends '\(field)' in frontmatter",
                    severity: .suggestion,
                    provider: provider,
                    isAutoFixable: false
                )
                if !fm.allKeys.contains(field) {
                    violations.append(GuidelineViolation(rule: rule, fixHint: "Consider adding '\(field)' to the frontmatter"))
                } else {
                    passed.append(rule)
                }
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
            if fm.allKeys.contains("version") {
                return GuidelineViolation(
                    rule: rule,
                    fixHint: "Consider removing the Codex-specific 'version' field"
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

        case "no-readme":
            let readmePath = skill.skillPath.appendingPathComponent("README.md")
            if FileManager.default.fileExists(atPath: readmePath.path) {
                return GuidelineViolation(
                    rule: rule,
                    fixHint: "Remove README.md — move its content into SKILL.md or references/"
                )
            }

        case "description-length":
            guard let fm = frontmatter else { return nil }
            let desc = fm.scalars["description"] ?? ""
            if desc.count > 1024 {
                return GuidelineViolation(
                    rule: rule,
                    fixHint: "Description is \(desc.count) characters — shorten to under 1,024"
                )
            }

        case "no-xml-in-frontmatter":
            guard let fm = frontmatter else { return nil }
            if fm.rawText.contains("<") || fm.rawText.contains(">") {
                return GuidelineViolation(
                    rule: rule,
                    fixHint: "Remove '<' and '>' characters from frontmatter values"
                )
            }

        case "no-reserved-names":
            guard let fm = frontmatter else { return nil }
            let name = (fm.scalars["name"] ?? "").lowercased()
            if name.contains("claude") || name.contains("anthropic") {
                return GuidelineViolation(
                    rule: rule,
                    fixHint: "Rename the skill — 'claude' and 'anthropic' are reserved words"
                )
            }

        case "skill-size":
            let words = body.split { $0.isWhitespace || $0.isNewline }
            if words.count > 5000 {
                return GuidelineViolation(
                    rule: rule,
                    fixHint: "SKILL.md has ~\(words.count) words — move detailed content to references/ to stay under 5,000"
                )
            }

        default:
            break
        }

        return nil
    }
}
