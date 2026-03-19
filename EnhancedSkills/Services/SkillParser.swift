import Foundation

struct ParsedFrontmatter: Equatable {
    let scalars: [String: String]
    let rawText: String
    var allKeys: Set<String> { Set(scalars.keys) }
}

struct SkillParser {
    @discardableResult
    static func parse(skill: inout DiscoveredSkill) -> (frontmatter: ParsedFrontmatter?, body: String) {
        let mdPath = skill.skillMarkdownPath
        guard FileManager.default.fileExists(atPath: mdPath.path) else {
            skill.parseStatus = .missingFile
            return (nil, "")
        }
        guard let content = try? String(contentsOf: mdPath, encoding: .utf8) else {
            skill.parseStatus = .malformed
            return (nil, "")
        }

        let (fmRaw, body) = extractFrontmatter(from: content)

        if let fmRaw {
            let parsed = parseFrontmatter(fmRaw)
            skill.parsedName = parsed["name"]
            skill.parsedDescription = parsed["description"]
            skill.parseStatus = .ok

            let fm = ParsedFrontmatter(scalars: parsed, rawText: fmRaw)
            skill.previewExcerpt = extractPreview(from: body)
            return (fm, body)
        } else {
            skill.parsedName = nil
            skill.parsedDescription = nil
            skill.parseStatus = .noFrontmatter
            skill.previewExcerpt = extractPreview(from: body)
            return (nil, body)
        }
    }

    static func extractFrontmatter(from content: String) -> (String?, String) {
        var lines = content.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return (nil, content)
        }
        lines.removeFirst()
        var fmLines: [String] = []
        var bodyLines: [String] = []
        var inFM = true
        for line in lines {
            if inFM && line.trimmingCharacters(in: .whitespaces) == "---" {
                inFM = false
                continue
            }
            if inFM { fmLines.append(line) } else { bodyLines.append(line) }
        }
        return inFM ? (nil, content) : (fmLines.joined(separator: "\n"), bodyLines.joined(separator: "\n"))
    }

    static func parseFrontmatter(_ fm: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in fm.components(separatedBy: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            var val = String(parts[1]).trimmingCharacters(in: .whitespaces)
            if val.count >= 2,
               (val.hasPrefix("\"") && val.hasSuffix("\"")) ||
               (val.hasPrefix("'") && val.hasSuffix("'")) {
                val = String(val.dropFirst().dropLast())
            }
            result[key] = val
        }
        return result
    }

    private static func extractPreview(from body: String) -> String? {
        let lines = body.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            return trimmed.count > 220 ? String(trimmed.prefix(220)) + "…" : trimmed
        }
        return nil
    }
}
