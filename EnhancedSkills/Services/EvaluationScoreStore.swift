import Foundation

class EvaluationScoreStore {
    private static let fileURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".enhanced-skills/evaluation-scores.json")
    }()

    private var database = EvaluationScoreDatabase()

    func load() {
        guard let data = try? Data(contentsOf: Self.fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let db = try? decoder.decode(EvaluationScoreDatabase.self, from: data) {
            database = db
        }
    }

    private func save() {
        let url = Self.fileURL
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(database) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Returns the overall score only if the stored content hash matches the current hash.
    func freshScore(for slug: String, currentHash: String) -> Int? {
        guard let record = database.records[slug],
              record.contentHash == currentHash else {
            return nil
        }
        return record.overallScore
    }

    /// Returns the full evaluation only if the stored content hash matches the current hash.
    func freshEvaluation(for slug: String, currentHash: String) -> AIEvaluation? {
        guard let record = database.records[slug],
              record.contentHash == currentHash else {
            return nil
        }
        return record.evaluation
    }

    /// Returns all fresh evaluations keyed by contentHash, for bulk cache restoration.
    func allFreshEvaluations() -> [String: AIEvaluation] {
        var result: [String: AIEvaluation] = [:]
        for record in database.records.values {
            if let eval = record.evaluation {
                result[record.contentHash] = eval
            }
        }
        return result
    }

    /// Upserts an evaluation record and persists to disk.
    func saveEvaluation(_ eval: AIEvaluation, slug: String, contentHash: String) {
        let record = EvaluationScoreRecord(
            slug: slug,
            contentHash: contentHash,
            overallScore: eval.overallScore,
            structureScore: eval.structureScore,
            descriptionScore: eval.descriptionScore,
            contentQualityScore: eval.contentQualityScore,
            evaluatedAt: Date(),
            evaluation: eval
        )
        database.records[slug] = record
        save()
    }
}
