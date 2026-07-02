import Foundation

class CategoryStore {
    private static let fileURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".enhanced-skills/skill-categories.json")
    }()

    private var database = CategoryDatabase()

    func load() {
        guard let data = try? Data(contentsOf: Self.fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let db = try? decoder.decode(CategoryDatabase.self, from: data) {
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

    /// Returns the category only if the stored content hash matches the current hash.
    func freshCategory(for slug: String, currentHash: String) -> SkillCategory? {
        guard let record = database.records[slug],
              record.contentHash == currentHash else {
            return nil
        }
        return record.category
    }

    /// Upserts a category record and persists to disk.
    func saveCategory(_ category: SkillCategory, slug: String, contentHash: String) {
        let record = CategoryRecord(
            slug: slug,
            contentHash: contentHash,
            category: category,
            classifiedAt: Date()
        )
        database.records[slug] = record
        save()
    }
}
