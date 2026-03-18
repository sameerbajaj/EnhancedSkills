import Foundation

enum TransferError: LocalizedError {
    case noSource
    case sourceNotFound(URL)
    case rootCreationFailed(URL, Error)
    case copyFailed(URL, URL, Error)

    var errorDescription: String? {
        switch self {
        case .noSource: return "No source skill available for transfer."
        case .sourceNotFound(let u): return "Source not found: \(u.path)"
        case .rootCreationFailed(let u, let e): return "Could not create \(u.path): \(e.localizedDescription)"
        case .copyFailed(let s, let d, let e): return "Copy failed \(s.lastPathComponent) → \(d.lastPathComponent): \(e.localizedDescription)"
        }
    }
}

struct TransferService {
    static func buildPlan(for record: SkillRecord, to destination: Provider) throws -> SkillTransferPlan {
        let source: DiscoveredSkill
        switch destination {
        case .claude:
            guard let s = record.codexSkill else { throw TransferError.noSource }
            source = s
        case .codex:
            guard let s = record.claudeSkill else { throw TransferError.noSource }
            source = s
        }

        let destRoot = destination.defaultRootPath
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
        let items = try fm.contentsOfDirectory(at: src, includingPropertiesForKeys: nil)
        for item in items {
            if item.lastPathComponent == ".DS_Store" { continue }
            let dest = dst.appendingPathComponent(item.lastPathComponent)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: item.path, isDirectory: &isDir)
            if isDir.boolValue {
                try copyDir(from: item, to: dest)
            } else {
                try fm.copyItem(at: item, to: dest)
            }
        }
    }

    private static func countItems(at url: URL) -> Int {
        (FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil)?.allObjects.count) ?? 0
    }
}
