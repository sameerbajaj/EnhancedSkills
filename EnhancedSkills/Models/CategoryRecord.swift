import Foundation

public struct CategoryRecord: Codable {
    public let slug: String
    public let contentHash: String
    public let category: SkillCategory
    public let classifiedAt: Date
}

public struct CategoryDatabase: Codable {
    public var version: Int = 1
    public var records: [String: CategoryRecord] = [:]  // keyed by slug
    public var approvedTaxonomy: [String] = []          // dynamic category names
}
