import Foundation

enum TransferError: LocalizedError {
    case noSource
    case noDestinationPath(Provider)
    case sourceNotFound(URL)
    case rootCreationFailed(URL, Error)
    case copyFailed(URL, URL, Error)

    var errorDescription: String? {
        switch self {
        case .noSource: return "No source skill available for transfer."
        case .noDestinationPath(let p): return "\(p.displayName) path is not configured. Set it in Settings."
        case .sourceNotFound(let u): return "Source not found: \(u.path)"
        case .rootCreationFailed(let u, let e): return "Could not create \(u.path): \(e.localizedDescription)"
        case .copyFailed(let s, let d, let e): return "Copy failed \(s.lastPathComponent) → \(d.lastPathComponent): \(e.localizedDescription)"
        }
    }
}

struct TransferService {
    static func buildPlan(for record: SkillRecord, to destination: Provider, destinationRoot: URL?) throws -> SkillTransferPlan {
        // Find a source skill from any other provider
        let source: DiscoveredSkill
        let candidates = record.skills.values
            .filter { $0.provider != destination }
        guard let s = candidates.first else { throw TransferError.noSource }
        source = s

        guard let destRoot = destinationRoot else {
            throw TransferError.noDestinationPath(destination)
        }

        let destPath = destRoot.appendingPathComponent(source.folderName)
        let destExists = FileManager.default.fileExists(atPath: destPath.path)
        let fileCount = countItems(at: source.skillPath)

        return SkillTransferPlan(
            skillSlug: record.slug,
            sourceProvider: source.provider,
            destinationProvider: destination,
            sourcePath: source.skillPath,
            destinationPath: destPath,
            sourceFileCount: fileCount,
            destinationExists: destExists,
            willReplace: destExists,
            warnings: destExists ? ["Existing skill at destination will be replaced."] : []
        )
    }

    static func syncAll(record: SkillRecord, settings: SettingsStore) throws {
        guard record.skills.count >= 2 else { return }

        // Find the newest copy by lastModified
        let sorted = record.skills.values.sorted {
            ($0.lastModified ?? .distantPast) > ($1.lastModified ?? .distantPast)
        }
        guard let newest = sorted.first else { return }

        // Overwrite every other provider's copy with the newest
        for (provider, _) in record.skills where provider != newest.provider {
            guard let destRoot = settings.rootPath(for: provider) else { continue }
            let plan = SkillTransferPlan(
                skillSlug: record.slug,
                sourceProvider: newest.provider,
                destinationProvider: provider,
                sourcePath: newest.skillPath,
                destinationPath: destRoot.appendingPathComponent(newest.folderName),
                sourceFileCount: 0,
                destinationExists: true,
                willReplace: true,
                warnings: []
            )
            try execute(plan: plan)
        }
    }

    static func execute(plan: SkillTransferPlan) throws {
        let fm = FileManager.default
        let destRoot = plan.destinationPath.deletingLastPathComponent()

        if !fm.fileExists(atPath: destRoot.path) {
            do { try fm.createDirectory(at: destRoot, withIntermediateDirectories: true) }
            catch { throw TransferError.rootCreationFailed(destRoot, error) }
        }

        if fm.fileExists(atPath: plan.destinationPath.path) {
            try fm.removeItem(at: plan.destinationPath)
        }

        do { try copyDir(from: plan.sourcePath, to: plan.destinationPath) }
        catch { throw TransferError.copyFailed(plan.sourcePath, plan.destinationPath, error) }
    }

    private static func copyDir(from src: URL, to dst: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: dst, withIntermediateDirectories: true)
        
        // Resolve src path if it is a symlink
        let resolvedSrc = src.resolvingSymlinksInPath()
        let items = try fm.contentsOfDirectory(at: resolvedSrc, includingPropertiesForKeys: nil)
        
        for item in items {
            let name = item.lastPathComponent
            if name == ".DS_Store" || name == ".versions" || name == ".git" || name == ".github.json" || name == ".gitignore" || name == ".venv" || name == "node_modules" || name == "build" || name == "dist" || name == ".build" { continue }
            
            let dest = dst.appendingPathComponent(name)
            let resolvedItem = item.resolvingSymlinksInPath()
            
            var isDir: ObjCBool = false
            fm.fileExists(atPath: resolvedItem.path, isDirectory: &isDir)
            if isDir.boolValue {
                try copyDir(from: resolvedItem, to: dest)
            } else {
                try fm.copyItem(at: resolvedItem, to: dest)
            }
        }
    }

    private static func countItems(at url: URL) -> Int {
        let fm = FileManager.default
        let resolvedURL = url.resolvingSymlinksInPath()
        guard let enumerator = fm.enumerator(
            at: resolvedURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        var count = 0
        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent
            if name == ".DS_Store" || name == ".versions" || name == ".git" || name == ".github.json" || name == ".gitignore" || name == ".venv" || name == "node_modules" || name == "build" || name == "dist" || name == ".build" {
                enumerator.skipDescendants()
                continue
            }
            count += 1
        }
        return count
    }
}
