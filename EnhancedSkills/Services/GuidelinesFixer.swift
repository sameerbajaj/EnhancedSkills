import Foundation

enum FixerError: LocalizedError {
    case fileNotFound(String)
    case readFailed(String)
    case writeFailed(String)
    case directoryCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path): return "File not found: \(path)"
        case .readFailed(let path): return "Could not read: \(path)"
        case .writeFailed(let path): return "Could not write: \(path)"
        case .directoryCreationFailed(let path): return "Could not create directory: \(path)"
        }
    }
}

struct GuidelinesFixer {

    // MARK: - Public

    static func fix(ruleID: String, skill: DiscoveredSkill) throws {
        switch ruleID {
        case "frontmatter-present":
            try fixMissingFrontmatter(skill: skill)
        case "name-present":
            try fixMissingName(skill: skill)
        case "claude-allowed-tools":
            try insertFrontmatterField(key: "allowed-tools", value: "*", skill: skill)
        case "claude-codex-artifacts":
            try removeFrontmatterFields(keys: ["version", "license"], skill: skill)
        case "codex-version":
            try insertFrontmatterField(key: "version", value: "1.0", skill: skill)
        case "codex-scripts-consistency":
            try createScriptsDirectory(skill: skill)
        case "codex-claude-artifacts":
            try removeFrontmatterFields(keys: ["allowed-tools"], skill: skill)
        default:
            break
        }
    }

    static func fixAll(violations: [GuidelineViolation], skill: DiscoveredSkill) throws {
        let fixable = violations.filter { $0.isAutoFixable }

        // Sort: frontmatter-present first, then name-present, then everything else
        let sorted = fixable.sorted { a, b in
            priority(a.rule.id) < priority(b.rule.id)
        }

        for violation in sorted {
            try fix(ruleID: violation.rule.id, skill: skill)
        }
    }

    // MARK: - Private Fix Methods

    private static func fixMissingFrontmatter(skill: DiscoveredSkill) throws {
        let path = skill.skillMarkdownPath
        let content = try readFile(at: path)
        let name = humanize(skill.folderName)
        let frontmatter = "---\nname: \(name)\ndescription: \n---\n"
        let updated = frontmatter + content
        try writeFile(updated, to: path)
    }

    private static func fixMissingName(skill: DiscoveredSkill) throws {
        let path = skill.skillMarkdownPath
        var content = try readFile(at: path)
        let name = humanize(skill.folderName)

        // Insert `name:` line after the opening `---`
        guard let range = content.range(of: "---\n") else { return }
        let insertionPoint = range.upperBound
        content.insert(contentsOf: "name: \(name)\n", at: insertionPoint)
        try writeFile(content, to: path)
    }

    private static func insertFrontmatterField(key: String, value: String, skill: DiscoveredSkill) throws {
        let path = skill.skillMarkdownPath
        var lines = try readFile(at: path).components(separatedBy: "\n")

        // Guard against duplicate — check if key already exists in frontmatter
        var inFM = false
        var closingIdx: Int?
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                if !inFM {
                    inFM = true
                } else {
                    closingIdx = i
                    break
                }
            }
            if inFM && line.hasPrefix("\(key):") {
                return // already exists
            }
        }

        guard let idx = closingIdx else { return }
        lines.insert("\(key): \(value)", at: idx)
        try writeFile(lines.joined(separator: "\n"), to: path)
    }

    private static func removeFrontmatterFields(keys: [String], skill: DiscoveredSkill) throws {
        let path = skill.skillMarkdownPath
        var lines = try readFile(at: path).components(separatedBy: "\n")

        var inFM = false
        var indicesToRemove: [Int] = []
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                if !inFM { inFM = true } else { break }
                continue
            }
            if inFM {
                for key in keys {
                    if line.hasPrefix("\(key):") {
                        indicesToRemove.append(i)
                    }
                }
            }
        }

        for i in indicesToRemove.reversed() {
            lines.remove(at: i)
        }
        try writeFile(lines.joined(separator: "\n"), to: path)
    }

    private static func createScriptsDirectory(skill: DiscoveredSkill) throws {
        let scriptsURL = skill.skillPath.appendingPathComponent("scripts")
        do {
            try FileManager.default.createDirectory(at: scriptsURL, withIntermediateDirectories: true)
        } catch {
            throw FixerError.directoryCreationFailed(scriptsURL.path)
        }
    }

    // MARK: - Helpers

    static func humanize(_ name: String) -> String {
        name.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private static func readFile(at url: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FixerError.fileNotFound(url.path)
        }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw FixerError.readFailed(url.path)
        }
        return content
    }

    private static func writeFile(_ content: String, to url: URL) throws {
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw FixerError.writeFailed(url.path)
        }
    }

    private static func priority(_ ruleID: String) -> Int {
        switch ruleID {
        case "frontmatter-present": return 0
        case "name-present": return 1
        default: return 2
        }
    }
}
