import Foundation

enum ParseStatus: String, Equatable {
    case ok
    case noFrontmatter
    case malformed
    case missingFile
}

struct DiscoveredSkill: Identifiable, Equatable {
    var id = UUID()
    let provider: Provider
    let folderName: String
    let rootPath: URL
    let skillPath: URL
    let skillMarkdownPath: URL
    var parsedName: String?
    var parsedDescription: String?
    var isSystem: Bool
    var hasScripts: Bool
    var hasReferences: Bool
    var lastModified: Date?
    var contentHash: String?
    var parseStatus: ParseStatus
    var previewExcerpt: String?
    var validationReport: ValidationReport?
    var versionHistory: SkillVersionHistory?

    static func == (lhs: DiscoveredSkill, rhs: DiscoveredSkill) -> Bool {
        lhs.id == rhs.id
    }
}
