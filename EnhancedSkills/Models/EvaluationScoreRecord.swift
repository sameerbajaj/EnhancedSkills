import Foundation

struct EvaluationScoreRecord: Codable {
    let slug: String
    let contentHash: String
    let overallScore: Int
    let structureScore: Int
    let descriptionScore: Int
    let contentQualityScore: Int
    let evaluatedAt: Date
}

struct EvaluationScoreDatabase: Codable {
    var version: Int = 1
    var records: [String: EvaluationScoreRecord] = [:]  // keyed by slug
}
