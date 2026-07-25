import Foundation

struct SkillInventory {
    static func merge(skillsByProvider: [Provider: [DiscoveredSkill]], settings: SettingsStore? = nil) -> [SkillRecord] {
        var records: [String: SkillRecord] = [:]

        for (_, skills) in skillsByProvider {
            for skill in skills {
                let slug = normalize(skill.folderName)
                var r = records[slug] ?? SkillRecord(
                    id: slug, displayName: skill.parsedName ?? slug,
                    description: skill.parsedDescription, slug: slug,
                    skills: [:], status: .invalid, tags: [], lastModified: nil, createdDate: nil
                )
                r.skills[skill.provider] = skill
                // First provider to set display name wins
                if r.skills.count == 1 {
                    r.displayName = skill.parsedName ?? slug
                    r.description = skill.parsedDescription ?? r.description
                }
                r.lastModified = latestDate(r.lastModified, skill.lastModified)
                r.createdDate = earliestDate(r.createdDate, skill.createdDate)
                records[slug] = r
            }
        }

        return records.values.map { r -> SkillRecord in
            var rec = r
            rec.syncEnabled = settings?.syncPreference(for: rec.slug) ?? (rec.skills.count >= 2)
            rec.status = computeStatus(rec)
            return rec
        }.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    static func normalize(_ name: String) -> String {
        name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func computeStatus(_ r: SkillRecord) -> SkillStatus {
        let count = r.skills.count
        switch count {
        case 0: return .invalid
        case 1:
            let provider = r.skills.keys.first!
            return SkillStatus.onlyStatus(for: provider)
        default:
            // If all non-canonical copies are symlinks, they are physically in sync with canonical source
            let realCopies = r.skills.values.filter { !$0.isSymlink }
            if realCopies.count <= 1 {
                return .synced
            }
            // Multiple independent physical copies exist — check content hashes if sync is enabled
            if r.syncEnabled {
                let hashes = Set(realCopies.compactMap(\.contentHash))
                if hashes.count > 1 { return .needsSync }
            }
            return .synced
        }
    }

    private static func latestDate(_ a: Date?, _ b: Date?) -> Date? {
        switch (a, b) {
        case (nil, let d): return d
        case (let d, nil): return d
        case (let d1?, let d2?): return max(d1, d2)
        default: return nil
        }
    }

    private static func earliestDate(_ a: Date?, _ b: Date?) -> Date? {
        switch (a, b) {
        case (nil, let d): return d
        case (let d, nil): return d
        case (let d1?, let d2?): return min(d1, d2)
        default: return nil
        }
    }
}
