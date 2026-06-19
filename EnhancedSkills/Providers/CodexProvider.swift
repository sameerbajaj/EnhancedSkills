import Foundation

struct CodexProvider: SkillProvider {
    let provider: Provider = .codex
    let rootPath: URL

    init(rootPath: URL? = nil) {
        self.rootPath = rootPath ?? Provider.codex.defaultRootPath!
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
            var mdPath = url.appendingPathComponent("SKILL.md")
            var skillPath = url
            
            if !fm.fileExists(atPath: mdPath.path) {
                if let found = findSKILLmd(in: url, maxDepth: 3) {
                    mdPath = found
                    skillPath = found.deletingLastPathComponent()
                } else {
                    return nil
                }
            }

            let isSystem = folderName == ".system"
            let hasScripts = fm.fileExists(atPath: skillPath.appendingPathComponent("scripts").path)
            let hasRefs = fm.fileExists(atPath: skillPath.appendingPathComponent("references").path)
            let attrs = try? fm.attributesOfItem(atPath: mdPath.path)
            let lastMod = attrs?[.modificationDate] as? Date
            let createdDate = (try? fm.attributesOfItem(atPath: url.path))?[.creationDate] as? Date

            var skill = DiscoveredSkill(
                provider: .codex, folderName: folderName,
                rootPath: rootPath, skillPath: skillPath, skillMarkdownPath: mdPath,
                parsedName: nil, parsedDescription: nil,
                isSystem: isSystem, hasScripts: hasScripts, hasReferences: hasRefs,
                createdDate: createdDate, lastModified: lastMod, parseStatus: .ok, previewExcerpt: nil
            )
            let (fm, body) = SkillParser.parse(skill: &skill)
            skill.contentHash = ContentHasher.sha256(ofString: body)
            skill.validationReport = GuidelinesValidator.validate(skill: skill, frontmatter: fm, body: body)
            return skill
        }
    }
}
