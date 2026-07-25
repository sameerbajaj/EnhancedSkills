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
    static func buildPlan(for record: SkillRecord, to destination: Provider, destinationRoot: URL?, mode: TransferMode = .symlink) throws -> SkillTransferPlan {
        // Find a source skill from any other provider (prefer canonical real directory)
        let source: DiscoveredSkill
        let candidates = record.skills.values
            .filter { $0.provider != destination }
        guard let s = record.canonicalSource ?? candidates.first else { throw TransferError.noSource }
        source = s

        guard let destRoot = destinationRoot else {
            throw TransferError.noDestinationPath(destination)
        }

        let destPath = destRoot.appendingPathComponent(source.folderName)
        let destExists = FileManager.default.fileExists(atPath: destPath.path) || isSymlink(at: destPath)
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
            warnings: destExists ? ["Existing skill at destination will be replaced."] : [],
            mode: mode
        )
    }

    static func syncAll(record: SkillRecord, settings: SettingsStore, mode: TransferMode = .symlink) throws {
        guard record.skills.count >= 2 else { return }

        // Determine canonical source (prefer non-symlink with newest modification date)
        let realCopies = record.skills.values.filter { !$0.isSymlink }
        guard let canonical = realCopies.sorted(by: {
            ($0.lastModified ?? .distantPast) > ($1.lastModified ?? .distantPast)
        }).first ?? record.skills.values.first else { return }

        for (provider, skill) in record.skills where provider != canonical.provider {
            guard let destRoot = settings.rootPath(for: provider) else { continue }
            let destPath = destRoot.appendingPathComponent(canonical.folderName)

            switch mode {
            case .symlink:
                // Skip if already a symlink pointing to the canonical source
                if skill.isSymlink, let target = resolvedSymlink(at: skill.skillPath), target.path == canonical.skillPath.path {
                    continue
                }
                try executeAsSymlink(sourcePath: canonical.skillPath, destinationPath: destPath)

            case .copy:
                let plan = SkillTransferPlan(
                    skillSlug: record.slug,
                    sourceProvider: canonical.provider,
                    destinationProvider: provider,
                    sourcePath: canonical.skillPath,
                    destinationPath: destPath,
                    sourceFileCount: 0,
                    destinationExists: true,
                    willReplace: true,
                    warnings: [],
                    mode: .copy
                )
                try execute(plan: plan)
            }
        }
    }

    /// Create a directory symbolic link pointing from destinationPath -> sourcePath
    static func executeAsSymlink(sourcePath: URL, destinationPath: URL) throws {
        let fm = FileManager.default
        let destRoot = destinationPath.deletingLastPathComponent()

        if !fm.fileExists(atPath: destRoot.path) {
            do { try fm.createDirectory(at: destRoot, withIntermediateDirectories: true) }
            catch { throw TransferError.rootCreationFailed(destRoot, error) }
        }

        // Remove existing item or symlink at destination
        if fm.fileExists(atPath: destinationPath.path) || isSymlink(at: destinationPath) {
            try fm.removeItem(at: destinationPath)
        }

        // Create symbolic link
        try fm.createSymbolicLink(at: destinationPath, withDestinationURL: sourcePath)
    }

    /// Check if a path is a symbolic link
    static func isSymlink(at url: URL) -> Bool {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.type] as? FileAttributeType) == .typeSymbolicLink
    }

    /// Resolve a symbolic link to its target URL
    static func resolvedSymlink(at url: URL) -> URL? {
        guard isSymlink(at: url) else { return nil }
        guard let dest = try? FileManager.default.destinationOfSymbolicLink(atPath: url.path) else { return nil }
        return URL(fileURLWithPath: dest, relativeTo: url.deletingLastPathComponent()).standardizedFileURL
    }

    /// Convert a symlink into an independent physical copy
    static func materializeSymlink(at url: URL) throws {
        guard isSymlink(at: url) else { return }
        let resolvedSrc = url.resolvingSymlinksInPath()
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        try copyDir(from: resolvedSrc, to: tmp)
        try fm.removeItem(at: url)
        try fm.moveItem(at: tmp, to: url)
    }

    static func execute(plan: SkillTransferPlan) throws {
        switch plan.mode {
        case .symlink:
            try executeAsSymlink(sourcePath: plan.sourcePath, destinationPath: plan.destinationPath)
        case .copy:
            let fm = FileManager.default
            let destRoot = plan.destinationPath.deletingLastPathComponent()

            if !fm.fileExists(atPath: destRoot.path) {
                do { try fm.createDirectory(at: destRoot, withIntermediateDirectories: true) }
                catch { throw TransferError.rootCreationFailed(destRoot, error) }
            }

            if fm.fileExists(atPath: plan.destinationPath.path) || isSymlink(at: plan.destinationPath) {
                try fm.removeItem(at: plan.destinationPath)
            }

            do { try copyDir(from: plan.sourcePath, to: plan.destinationPath) }
            catch { throw TransferError.copyFailed(plan.sourcePath, plan.destinationPath, error) }
        }
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
