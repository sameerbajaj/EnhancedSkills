import Testing
import Foundation
@testable import EnhancedSkills

// MARK: - SkillParser Tests

@Suite("SkillParser")
struct SkillParserTests {
    func makeSkill(provider: Provider = .codex, folderName: String = "test-skill", mdContent: String) throws -> DiscoveredSkill {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let skillDir = tmp.appendingPathComponent(folderName)
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        let mdPath = skillDir.appendingPathComponent("SKILL.md")
        try mdContent.write(to: mdPath, atomically: true, encoding: .utf8)
        return DiscoveredSkill(
            provider: provider, folderName: folderName,
            rootPath: tmp, skillPath: skillDir, skillMarkdownPath: mdPath,
            parsedName: nil, parsedDescription: nil,
            isSystem: false, hasScripts: false, hasReferences: false,
            lastModified: nil, parseStatus: .ok, previewExcerpt: nil
        )
    }

    @Test func parsesValidFrontmatter() throws {
        var skill = try makeSkill(mdContent: """
        ---
        name: My Skill
        description: Does something useful
        ---
        Body text here.
        """)
        SkillParser.parse(skill: &skill)
        #expect(skill.parseStatus == .ok)
        #expect(skill.parsedName == "My Skill")
        #expect(skill.parsedDescription == "Does something useful")
        #expect(skill.previewExcerpt == "Body text here.")
    }

    @Test func handlesNoFrontmatter() throws {
        var skill = try makeSkill(mdContent: "Just plain text with no frontmatter.")
        SkillParser.parse(skill: &skill)
        #expect(skill.parseStatus == .noFrontmatter)
        #expect(skill.parsedName == nil)
        #expect(skill.previewExcerpt == "Just plain text with no frontmatter.")
    }

    @Test func handlesEmptyFile() throws {
        var skill = try makeSkill(mdContent: "")
        SkillParser.parse(skill: &skill)
        #expect(skill.previewExcerpt == nil)
    }

    @Test func handlesMissingFile() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let skillDir = tmp.appendingPathComponent("no-skill")
        let mdPath = skillDir.appendingPathComponent("SKILL.md")
        var skill = DiscoveredSkill(
            provider: .codex, folderName: "no-skill",
            rootPath: tmp, skillPath: skillDir, skillMarkdownPath: mdPath,
            parsedName: nil, parsedDescription: nil,
            isSystem: false, hasScripts: false, hasReferences: false,
            lastModified: nil, parseStatus: .ok, previewExcerpt: nil
        )
        SkillParser.parse(skill: &skill)
        #expect(skill.parseStatus == .missingFile)
    }
}

// MARK: - SkillInventory Tests

@Suite("SkillInventory")
struct SkillInventoryTests {
    func makeDiscovered(provider: Provider, folderName: String) -> DiscoveredSkill {
        let tmp = FileManager.default.temporaryDirectory
        return DiscoveredSkill(
            provider: provider, folderName: folderName,
            rootPath: tmp, skillPath: tmp.appendingPathComponent(folderName),
            skillMarkdownPath: tmp.appendingPathComponent(folderName).appendingPathComponent("SKILL.md"),
            parsedName: folderName, parsedDescription: "Desc for \(folderName)",
            isSystem: false, hasScripts: false, hasReferences: false,
            lastModified: nil, parseStatus: .ok, previewExcerpt: nil
        )
    }

    @Test func syncsWhenBothProvidersHaveSkill() {
        let codex = [makeDiscovered(provider: .codex, folderName: "my-skill")]
        let claude = [makeDiscovered(provider: .claude, folderName: "my-skill")]
        let merged = SkillInventory.merge(skillsByProvider: [.codex: codex, .claude: claude])
        #expect(merged.count == 1)
        #expect(merged[0].status == .synced)
    }

    @Test func codexOnlyWhenNoClaudeSkill() {
        let codex = [makeDiscovered(provider: .codex, folderName: "codex-only")]
        let merged = SkillInventory.merge(skillsByProvider: [.codex: codex])
        #expect(merged[0].status == .codexOnly)
    }

    @Test func claudeOnlyWhenNoCodexSkill() {
        let claude = [makeDiscovered(provider: .claude, folderName: "claude-only")]
        let merged = SkillInventory.merge(skillsByProvider: [.claude: claude])
        #expect(merged[0].status == .claudeOnly)
    }

    @Test func mergesToSingleRecordBySlug() {
        let codex = [makeDiscovered(provider: .codex, folderName: "Shared-Skill")]
        let claude = [makeDiscovered(provider: .claude, folderName: "shared-skill")]
        let merged = SkillInventory.merge(skillsByProvider: [.codex: codex, .claude: claude])
        #expect(merged.count == 1)
    }

    @Test func separatesDistinctSlugs() {
        let codex = [makeDiscovered(provider: .codex, folderName: "skill-a")]
        let claude = [makeDiscovered(provider: .claude, folderName: "skill-b")]
        let merged = SkillInventory.merge(skillsByProvider: [.codex: codex, .claude: claude])
        #expect(merged.count == 2)
    }
}

// MARK: - TransferService Tests

@Suite("TransferService")
struct TransferServiceTests {
    func makeSkillDir(name: String) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let dir = tmp.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "content".write(to: dir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        return dir
    }

    @Test func executesTransferCreatingDestination() throws {
        let srcDir = try makeSkillDir(name: "my-skill")
        let destRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let destDir = destRoot.appendingPathComponent("my-skill")

        let plan = SkillTransferPlan(
            skillSlug: "my-skill",
            sourceProvider: .codex,
            destinationProvider: .claude,
            sourcePath: srcDir,
            destinationPath: destDir,
            sourceFileCount: 1,
            destinationExists: false,
            willReplace: false,
            warnings: []
        )

        try TransferService.execute(plan: plan)
        #expect(FileManager.default.fileExists(atPath: destDir.path))
        #expect(FileManager.default.fileExists(atPath: destDir.appendingPathComponent("SKILL.md").path))
    }

    @Test func replacesPreviousDestination() throws {
        let srcDir = try makeSkillDir(name: "shared-skill")
        let destRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let destDir = destRoot.appendingPathComponent("shared-skill")
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        try "old".write(to: destDir.appendingPathComponent("OLD.md"), atomically: true, encoding: .utf8)

        let plan = SkillTransferPlan(
            skillSlug: "shared-skill",
            sourceProvider: .codex,
            destinationProvider: .claude,
            sourcePath: srcDir,
            destinationPath: destDir,
            sourceFileCount: 1,
            destinationExists: true,
            willReplace: true,
            warnings: []
        )

        try TransferService.execute(plan: plan)
        #expect(!FileManager.default.fileExists(atPath: destDir.appendingPathComponent("OLD.md").path))
        #expect(FileManager.default.fileExists(atPath: destDir.appendingPathComponent("SKILL.md").path))
    }
}

// MARK: - CategoryStore Tests

@Suite("CategoryStore")
struct CategoryStoreTests {
    @Test func persistsAndRestoresCategory() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let store = CategoryStore(fileURL: tempURL)
        store.load()
        
        let testSlug = "test-category-slug"
        let testHash = "hash-12345"
        let category = SkillCategory(name: "AI & LLM")
        
        store.saveCategory(category, slug: testSlug, contentHash: testHash)
        
        // Load in a fresh store to verify persistence
        let store2 = CategoryStore(fileURL: tempURL)
        store2.load()
        
        let restored = store2.freshCategory(for: testSlug, currentHash: testHash)
        #expect(restored == category)
        
        // Invalid hash should return nil
        let restoredInvalidHash = store2.freshCategory(for: testSlug, currentHash: "wrong-hash")
        #expect(restoredInvalidHash == nil)
    }
}
