import Foundation

public struct CategoryRecord: Codable {
    public let slug: String
    public let contentHash: String
    public let category: SkillCategory
    public let classifiedAt: Date
}

public struct CategoryDatabase: Codable {
    public var version: Int = 2
    public var records: [String: CategoryRecord] = [:]          // keyed by slug
    public var approvedTaxonomy: [SkillCategory] = []           // ordered category objects

    // Migration: decode legacy format where taxonomy was [String]
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? container.decode(Int.self, forKey: .version)) ?? 1
        records = (try? container.decode([String: CategoryRecord].self, forKey: .records)) ?? [:]

        // Try decoding as [SkillCategory] first (v2 format)
        if let cats = try? container.decode([SkillCategory].self, forKey: .approvedTaxonomy) {
            approvedTaxonomy = cats
        } else if let names = try? container.decode([String].self, forKey: .approvedTaxonomy) {
            // Legacy v1 format: array of plain strings — migrate to SkillCategory with auto shortLabel
            approvedTaxonomy = names.map { SkillCategory(name: $0) }
            // Bump version so next save writes v2
            version = 2
        } else {
            approvedTaxonomy = []
        }
    }

    public init() {}
}
