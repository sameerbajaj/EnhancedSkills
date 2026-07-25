import Foundation

/// Generic SKILL.md-based provider that works for any provider type.
/// Used for OpenClaw, Gemini, Antigravity, and any future providers.
struct GenericProvider: SkillProvider {
    let provider: Provider
    let rootPath: URL

    init(provider: Provider, rootPath: URL?) {
        self.provider = provider
        guard let rootPath else {
            self.rootPath = URL(fileURLWithPath: "/nonexistent")
            return
        }
        self.rootPath = rootPath
    }

    func discoverSkills() async throws -> [DiscoveredSkill] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: rootPath.path, isDirectory: &isDir), isDir.boolValue else { return [] }

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

            let hasScripts = fm.fileExists(atPath: skillPath.appendingPathComponent("scripts").path)
            let hasRefs = fm.fileExists(atPath: skillPath.appendingPathComponent("references").path)
            let attrs = try? fm.attributesOfItem(atPath: mdPath.path)
            let lastMod = attrs?[.modificationDate] as? Date
            let createdDate = (try? fm.attributesOfItem(atPath: url.path))?[.creationDate] as? Date

            let isSymlink = TransferService.isSymlink(at: url)
            let symlinkTarget = isSymlink ? TransferService.resolvedSymlink(at: url) : nil
            let isDangling = isSymlink && (symlinkTarget == nil || !fm.fileExists(atPath: symlinkTarget!.path))

            var skill = DiscoveredSkill(
                provider: provider, folderName: folderName,
                rootPath: rootPath, skillPath: skillPath, skillMarkdownPath: mdPath,
                parsedName: nil, parsedDescription: nil,
                isSystem: false, hasScripts: hasScripts, hasReferences: hasRefs,
                createdDate: createdDate, lastModified: lastMod, parseStatus: isDangling ? .missingFile : .ok, previewExcerpt: nil,
                isSymlink: isSymlink, symlinkTarget: symlinkTarget, isDanglingSymlink: isDangling
            )
            let (fm, body) = SkillParser.parse(skill: &skill)
            skill.contentHash = ContentHasher.sha256(ofString: body)
            skill.validationReport = GuidelinesValidator.validate(skill: skill, frontmatter: fm, body: body)
            return skill
        }
    }
}
