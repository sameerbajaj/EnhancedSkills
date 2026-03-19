import Foundation

struct GitHubSkillContent {
    let originalURL: String
    let resolvedRawURL: URL
    let rawContent: String
    let frontmatter: ParsedFrontmatter?
    let body: String
    let inferredName: String
    let inferredDescription: String
    let inferredFolderName: String
}

enum GitHubImportError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case notFound
    case malformedContent
    case fileWriteFailed(Error)
    case providerNotConfigured(Provider)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid GitHub URL. Please provide a valid link to a skill or SKILL.md file."
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .notFound: return "SKILL.md not found. Make sure the repository is public and the path is correct."
        case .malformedContent: return "The fetched content does not appear to be a valid skill file."
        case .fileWriteFailed(let e): return "Failed to write skill file: \(e.localizedDescription)"
        case .providerNotConfigured(let p): return "\(p.displayName) path is not configured. Set it in Settings."
        }
    }
}

struct GitHubImportService {

    // MARK: - URL Resolution

    static func resolveRawURL(from urlString: String) throws -> URL {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GitHubImportError.invalidURL }

        // Already a raw URL
        if trimmed.contains("raw.githubusercontent.com") {
            guard let url = URL(string: trimmed) else { throw GitHubImportError.invalidURL }
            return url
        }

        guard trimmed.contains("github.com") else { throw GitHubImportError.invalidURL }

        // Parse the GitHub URL
        guard let url = URL(string: trimmed) else { throw GitHubImportError.invalidURL }
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        guard pathComponents.count >= 2 else { throw GitHubImportError.invalidURL }
        let user = pathComponents[0]
        let repo = pathComponents[1]

        // github.com/user/repo/blob/branch/path/SKILL.md
        if pathComponents.count >= 4 && pathComponents[2] == "blob" {
            let branch = pathComponents[3]
            let remainingPath = pathComponents[4...].joined(separator: "/")
            let rawURLString = "https://raw.githubusercontent.com/\(user)/\(repo)/\(branch)/\(remainingPath)"
            guard let rawURL = URL(string: rawURLString) else { throw GitHubImportError.invalidURL }
            return rawURL
        }

        // github.com/user/repo/tree/branch/path/
        if pathComponents.count >= 4 && pathComponents[2] == "tree" {
            let branch = pathComponents[3]
            let folderPath = pathComponents.count > 4 ? pathComponents[4...].joined(separator: "/") : ""
            let skillPath = folderPath.isEmpty ? "SKILL.md" : "\(folderPath)/SKILL.md"
            let rawURLString = "https://raw.githubusercontent.com/\(user)/\(repo)/\(branch)/\(skillPath)"
            guard let rawURL = URL(string: rawURLString) else { throw GitHubImportError.invalidURL }
            return rawURL
        }

        // github.com/user/repo — try main branch first
        if pathComponents.count == 2 {
            let rawURLString = "https://raw.githubusercontent.com/\(user)/\(repo)/main/SKILL.md"
            guard let rawURL = URL(string: rawURLString) else { throw GitHubImportError.invalidURL }
            return rawURL
        }

        // github.com/user/repo/path... (no tree/blob) — assume main branch
        let remainingPath = pathComponents[2...].joined(separator: "/")
        let suffix = remainingPath.hasSuffix("SKILL.md") ? remainingPath : "\(remainingPath)/SKILL.md"
        let rawURLString = "https://raw.githubusercontent.com/\(user)/\(repo)/main/\(suffix)"
        guard let rawURL = URL(string: rawURLString) else { throw GitHubImportError.invalidURL }
        return rawURL
    }

    // MARK: - Fetching

    static func fetchSkillContent(from originalURL: String) async throws -> GitHubSkillContent {
        let rawURL = try resolveRawURL(from: originalURL)
        return try await fetchWithFallback(originalURL: originalURL, rawURL: rawURL)
    }

    private static func fetchWithFallback(originalURL: String, rawURL: URL) async throws -> GitHubSkillContent {
        do {
            return try await doFetch(originalURL: originalURL, rawURL: rawURL)
        } catch GitHubImportError.notFound {
            // If URL used /main/, try /master/ as fallback
            let urlString = rawURL.absoluteString
            if urlString.contains("/main/") {
                let masterURLString = urlString.replacingOccurrences(of: "/main/", with: "/master/")
                if let masterURL = URL(string: masterURLString) {
                    return try await doFetch(originalURL: originalURL, rawURL: masterURL)
                }
            }
            throw GitHubImportError.notFound
        }
    }

    private static func doFetch(originalURL: String, rawURL: URL) async throws -> GitHubSkillContent {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(from: rawURL)
        } catch {
            throw GitHubImportError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 404 {
                throw GitHubImportError.notFound
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw GitHubImportError.networkError(
                    NSError(domain: "HTTP", code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "Server returned \(httpResponse.statusCode)"])
                )
            }
        }

        guard let content = String(data: data, encoding: .utf8), !content.isEmpty else {
            throw GitHubImportError.malformedContent
        }

        let (fmRaw, body) = SkillParser.extractFrontmatter(from: content)
        let frontmatter: ParsedFrontmatter?
        if let fmRaw {
            let parsed = SkillParser.parseFrontmatter(fmRaw)
            frontmatter = ParsedFrontmatter(scalars: parsed, rawText: fmRaw)
        } else {
            frontmatter = nil
        }

        let name = frontmatter?.scalars["name"] ?? inferName(from: rawURL)
        let description = frontmatter?.scalars["description"] ?? inferDescription(from: body)
        let folderName = inferFolderName(from: name)

        return GitHubSkillContent(
            originalURL: originalURL,
            resolvedRawURL: rawURL,
            rawContent: content,
            frontmatter: frontmatter,
            body: body,
            inferredName: name,
            inferredDescription: description,
            inferredFolderName: folderName
        )
    }

    // MARK: - Reformatting

    static func reformatForProvider(_ content: GitHubSkillContent, provider: Provider) -> String {
        let spec = provider.spec
        let allowedKeys = Set(spec.requiredFrontmatterFields + spec.optionalFrontmatterFields)

        guard let fm = content.frontmatter else {
            // No frontmatter — build minimal required fields
            var lines = ["---"]
            lines.append("name: \(content.inferredName)")
            lines.append("description: \(content.inferredDescription)")
            lines.append("---")
            if !content.body.isEmpty {
                lines.append(content.body)
            }
            return lines.joined(separator: "\n")
        }

        // Filter frontmatter to only allowed keys
        var fmLines: [String] = []
        var hasName = false
        var hasDescription = false

        // Preserve original ordering from rawText
        for line in fm.rawText.components(separatedBy: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count >= 1 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            if allowedKeys.contains(key) {
                fmLines.append(line)
                if key == "name" { hasName = true }
                if key == "description" { hasDescription = true }
            }
        }

        // Ensure required fields are present
        if !hasName {
            fmLines.insert("name: \(content.inferredName)", at: 0)
        }
        if !hasDescription {
            let insertIdx = hasName ? 1 : 1
            fmLines.insert("description: \(content.inferredDescription)", at: min(insertIdx, fmLines.count))
        }

        var result = "---\n"
        result += fmLines.joined(separator: "\n")
        result += "\n---"
        if !content.body.isEmpty {
            result += "\n" + content.body
        }
        return result
    }

    // MARK: - Import

    static func importSkill(_ content: GitHubSkillContent, to provider: Provider, rootPath: URL) throws {
        let fm = FileManager.default
        let skillDir = rootPath.appendingPathComponent(content.inferredFolderName)
        let skillFile = skillDir.appendingPathComponent(provider.spec.skillFileName)

        // Create directory
        do {
            try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        } catch {
            throw GitHubImportError.fileWriteFailed(error)
        }

        // Write reformatted content
        let reformatted = reformatForProvider(content, provider: provider)
        do {
            try reformatted.write(to: skillFile, atomically: true, encoding: .utf8)
        } catch {
            throw GitHubImportError.fileWriteFailed(error)
        }
    }

    static func skillExists(_ content: GitHubSkillContent, at provider: Provider, rootPath: URL) -> Bool {
        let skillDir = rootPath.appendingPathComponent(content.inferredFolderName)
        return FileManager.default.fileExists(atPath: skillDir.path)
    }

    // MARK: - Helpers

    private static func inferName(from url: URL) -> String {
        // Try to get folder name from URL path (the parent of SKILL.md)
        let components = url.pathComponents.filter { $0 != "/" }
        if let skillIdx = components.lastIndex(of: "SKILL.md"), skillIdx > 0 {
            return components[skillIdx - 1]
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .localizedCapitalized
        }
        return "Imported Skill"
    }

    private static func inferDescription(from body: String) -> String {
        for line in body.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            return trimmed.count > 200 ? String(trimmed.prefix(200)) + "…" : trimmed
        }
        return ""
    }

    private static func inferFolderName(from name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")).inverted)
            .joined()
    }
}
