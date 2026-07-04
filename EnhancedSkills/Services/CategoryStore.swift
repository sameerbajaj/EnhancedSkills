import Foundation
import Observation

@Observable
class CategoryStore {
    static let shared = CategoryStore()

    private let fileURL: URL
    private var database = CategoryDatabase()

    init(fileURL: URL? = nil) {
        if let custom = fileURL {
            self.fileURL = custom
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.fileURL = home.appendingPathComponent(".enhanced-skills/skill-categories.json")
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let db = try? decoder.decode(CategoryDatabase.self, from: data) {
            database = db
        }
    }

    private func save() {
        let url = fileURL
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

    // MARK: - Taxonomy Access

    var approvedTaxonomy: [SkillCategory] {
        database.approvedTaxonomy
    }

    var hasTaxonomy: Bool {
        !database.approvedTaxonomy.isEmpty
    }

    // MARK: - Taxonomy Management

    func saveTaxonomy(_ categories: [SkillCategory]) {
        database.approvedTaxonomy = categories
        save()
    }

    func addCategory(_ category: SkillCategory) {
        guard !database.approvedTaxonomy.contains(where: { $0.name == category.name }) else { return }
        database.approvedTaxonomy.append(category)
        save()
    }

    func removeCategory(_ name: String) {
        database.approvedTaxonomy.removeAll { $0.name == name }
        // Also remove all skill assignments for this category
        let keysToRemove = database.records.filter { $0.value.category.name == name }.map { $0.key }
        for key in keysToRemove {
            database.records.removeValue(forKey: key)
        }
        save()
    }

    func renameCategory(oldName: String, newName: String, newShortLabel: String) {
        // Update taxonomy entry
        if let idx = database.approvedTaxonomy.firstIndex(where: { $0.name == oldName }) {
            database.approvedTaxonomy[idx] = SkillCategory(name: newName, shortLabel: newShortLabel)
        }
        // Update all skill assignments referencing the old name
        let newCategory = SkillCategory(name: newName, shortLabel: newShortLabel)
        for (slug, record) in database.records where record.category.name == oldName {
            database.records[slug] = CategoryRecord(
                slug: slug,
                contentHash: record.contentHash,
                category: newCategory,
                classifiedAt: record.classifiedAt
            )
        }
        save()
    }

    func mergeCategory(source: String, into target: String) {
        guard let targetCat = database.approvedTaxonomy.first(where: { $0.name == target }) else { return }
        // Reassign all skills from source to target
        for (slug, record) in database.records where record.category.name == source {
            database.records[slug] = CategoryRecord(
                slug: slug,
                contentHash: record.contentHash,
                category: targetCat,
                classifiedAt: record.classifiedAt
            )
        }
        // Remove source from taxonomy
        database.approvedTaxonomy.removeAll { $0.name == source }
        save()
    }

    func reorderTaxonomy(_ categories: [SkillCategory]) {
        database.approvedTaxonomy = categories
        save()
    }

    // MARK: - Per-Skill Category Access

    /// Returns the category only if the stored content hash matches the current hash and it is part of the approved taxonomy.
    func freshCategory(for slug: String, currentHash: String) -> SkillCategory? {
        guard let record = database.records[slug],
              record.contentHash == currentHash else {
            return nil
        }
        if hasTaxonomy && !database.approvedTaxonomy.contains(where: { $0.name == record.category.name }) {
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

    /// Removes the category assignment for a specific skill.
    func removeCategoryAssignment(for slug: String) {
        database.records.removeValue(forKey: slug)
        save()
    }

    /// Resets all taxonomy categories and assignments.
    func resetTaxonomy() {
        database.approvedTaxonomy = []
        database.records = [:]
        save()
    }
}
