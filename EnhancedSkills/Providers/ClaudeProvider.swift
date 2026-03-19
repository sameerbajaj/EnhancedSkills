import Foundation

struct ClaudeProvider: SkillProvider {
    let provider: Provider = .claude
    let rootPath: URL

    init(rootPath: URL? = nil) {
        self.rootPath = rootPath ?? Provider.claude.defaultRootPath!
    }

    func discoverSkills() async throws -> [DiscoveredSkill] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: rootPath.path) else { return [] }

        let contents = try fm.contentsOfDirectory(
            at: rootPath,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        return contents.compactMap { url -> DiscoveredSkill? in
            var isDir: ObjCBool = false
            fm.fileExists(atPath: url.path, isDirectory: &isDir)
            guard isDir.boolValue else { return nil }

            let folderName = url.lastPathComponent
            let mdPath = url.appendingPathComponent("SKILL.md")
            guard fm.fileExists(atPath: mdPath.path) else { return nil }

            let hasScripts = fm.fileExists(atPath: url.appendingPathComponent("scripts").path)
            let hasRefs = fm.fileExists(atPath: url.appendingPathComponent("references").path)
            let lastMod = (try? fm.attributesOfItem(atPath: mdPath.path))?[.modificationDate] as? Date

            var skill = DiscoveredSkill(
                provider: .claude, folderName: folderName,
                rootPath: rootPath, skillPath: url, skillMarkdownPath: mdPath,
                parsedName: nil, parsedDescription: nil,
                isSystem: false, hasScripts: hasScripts, hasReferences: hasRefs,
                lastModified: lastMod, parseStatus: .ok, previewExcerpt: nil
            )
            let (fm, body) = SkillParser.parse(skill: &skill)
            skill.contentHash = ContentHasher.sha256(of: mdPath)
            skill.validationReport = GuidelinesValidator.validate(skill: skill, frontmatter: fm, body: body)
            return skill
        }
    }
}
