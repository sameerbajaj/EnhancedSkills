import Foundation

// MARK: - GitHubSyncError

enum GitHubSyncError: LocalizedError {
    case invalidRepoURL(String)
    case gitError(String)
    case mergeConflict
    case noWriteAccess
    case notAGitRepo

    var errorDescription: String? {
        switch self {
        case .invalidRepoURL(let url): return "Could not parse GitHub URL: \(url)"
        case .gitError(let msg): return "Git error: \(msg)"
        case .mergeConflict: return "Merge conflict detected. Resolve manually in the skill directory."
        case .noWriteAccess: return "You don't have write access to this repository."
        case .notAGitRepo: return "Skill directory is not a git repository."
        }
    }
}

// MARK: - GitHubSyncService

struct GitHubSyncService {

    // MARK: - Publish

    /// Publish a skill as a new GitHub repository.
    static func publishToGitHub(
        skill: DiscoveredSkill,
        repoName: String,
        visibility: RepoVisibility,
        description: String
    ) async throws -> GitHubOrigin {
        guard GHCLIRunner.isInstalled() else { throw GHCLIError.notInstalled }
        let skillPath = skill.skillPath

        // Ensure git repo is initialized in skill directory
        let gitDir = skillPath.appendingPathComponent(".git")
        if !FileManager.default.fileExists(atPath: gitDir.path) {
            try await runGit(["init"], at: skillPath)
            try await runGit(["checkout", "-b", "main"], at: skillPath)
        }

        // Create .gitignore
        let gitignoreContent = ".versions/\n.github.json\n.DS_Store\n"
        let gitignorePath = skillPath.appendingPathComponent(".gitignore")
        if !FileManager.default.fileExists(atPath: gitignorePath.path) {
            try gitignoreContent.write(to: gitignorePath, atomically: true, encoding: .utf8)
        }

        // Stage files
        try await runGit(["add", "SKILL.md"], at: skillPath)
        let fm = FileManager.default
        if fm.fileExists(atPath: skillPath.appendingPathComponent("references").path) {
            try await runGit(["add", "references/"], at: skillPath)
        }
        if fm.fileExists(atPath: skillPath.appendingPathComponent("scripts").path) {
            try await runGit(["add", "scripts/"], at: skillPath)
        }
        try await runGit(["add", ".gitignore"], at: skillPath)

        // Check if there's anything to commit
        let statusOutput = try await runGit(["status", "--porcelain"], at: skillPath)
        if !statusOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try await runGit(["commit", "-m", "Initial publish via EnhancedSkills"], at: skillPath)
        }

        // Create GitHub repo and push using gh CLI
        let visFlag = visibility == .public ? "--public" : "--private"
        let args = [
            "repo", "create", repoName,
            visFlag,
            "--description", description.isEmpty ? "Skill published via EnhancedSkills" : description,
            "--source", skillPath.path,
            "--push",
            "--remote", "origin"
        ]
        let createOutput = try await GHCLIRunner.run(args)

        // Extract repo URL from gh output (usually last line)
        let repoURL = createOutput
            .components(separatedBy: "\n")
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.hasPrefix("https://github.com/") ? trimmed : nil
            }
            .last ?? "https://github.com/\(repoName)"

        // Parse owner/repoName from URL or use authenticated user
        let parsed = GitHubOrigin.parseOwnerRepo(from: repoURL)
        let owner = parsed?.owner ?? ""
        let finalRepoName = parsed?.repoName ?? repoName

        // Get current commit SHA
        let sha = (try? await runGit(["rev-parse", "HEAD"], at: skillPath))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let contentHash = computeContentHash(at: skillPath)

        let origin = GitHubOrigin(
            repoURL: "https://github.com/\(owner)/\(finalRepoName)",
            owner: owner,
            repoName: finalRepoName,
            branch: "main",
            lastSyncedCommitSHA: sha.isEmpty ? nil : sha,
            lastSyncedContentHash: contentHash,
            syncDirection: .origin,
            hasWriteAccess: true,
            lastChecked: Date()
        )

        try GitHubOrigin.saveOrigin(origin, to: skillPath)
        return origin
    }

    // MARK: - Push

    /// Push local changes to the remote GitHub repository.
    static func pushToGitHub(skill: DiscoveredSkill, origin: GitHubOrigin) async throws -> GitHubOrigin {
        guard origin.hasWriteAccess else { throw GitHubSyncError.noWriteAccess }
        let skillPath = skill.skillPath

        // Ensure git repo exists
        guard findGitRoot(from: skillPath) != nil else {
            throw GitHubSyncError.notAGitRepo
        }

        // Stage relevant files
        try await runGit(["add", "SKILL.md"], at: skillPath)
        let fm = FileManager.default
        if fm.fileExists(atPath: skillPath.appendingPathComponent("references").path) {
            try await runGit(["add", "references/"], at: skillPath)
        }
        if fm.fileExists(atPath: skillPath.appendingPathComponent("scripts").path) {
            try await runGit(["add", "scripts/"], at: skillPath)
        }

        // Only commit if there are staged changes
        let statusOutput = try await runGit(["status", "--porcelain"], at: skillPath)
        guard !statusOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return origin
        }

        let commitMsg = "Update via EnhancedSkills"
        try await runGit(["commit", "-m", commitMsg], at: skillPath)
        try await runGit(["push", "origin", origin.branch], at: skillPath)

        let sha = (try? await runGit(["rev-parse", "HEAD"], at: skillPath))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let contentHash = computeContentHash(at: skillPath)

        var updated = origin
        updated.lastSyncedCommitSHA = sha
        updated.lastSyncedContentHash = contentHash
        updated.lastChecked = Date()
        try GitHubOrigin.saveOrigin(updated, to: skillPath)
        return updated
    }

    // MARK: - Pull

    /// Pull remote changes from the GitHub repository.
    static func pullFromGitHub(skill: DiscoveredSkill, origin: GitHubOrigin) async throws -> GitHubOrigin {
        let skillPath = skill.skillPath

        guard findGitRoot(from: skillPath) != nil else {
            throw GitHubSyncError.notAGitRepo
        }

        try await runGit(["fetch", "origin"], at: skillPath)

        do {
            try await runGit(["merge", "--ff-only", "origin/\(origin.branch)"], at: skillPath)
        } catch {
            // Try regular merge
            do {
                try await runGit(["merge", "origin/\(origin.branch)"], at: skillPath)
            } catch {
                try? await runGit(["merge", "--abort"], at: skillPath)
                var updated = origin
                updated.lastChecked = Date()
                try? GitHubOrigin.saveOrigin(updated, to: skillPath)
                throw GitHubSyncError.mergeConflict
            }
        }

        let sha = (try? await runGit(["rev-parse", "HEAD"], at: skillPath))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let contentHash = computeContentHash(at: skillPath)

        var updated = origin
        updated.lastSyncedCommitSHA = sha
        updated.lastSyncedContentHash = contentHash
        updated.lastChecked = Date()
        try GitHubOrigin.saveOrigin(updated, to: skillPath)
        return updated
    }

    // MARK: - Force Push (Keep Local)

    /// Force push local state to remote, discarding remote changes.
    static func forceLocalToGitHub(skill: DiscoveredSkill, origin: GitHubOrigin) async throws -> GitHubOrigin {
        guard origin.hasWriteAccess else { throw GitHubSyncError.noWriteAccess }
        let skillPath = skill.skillPath

        try await runGit(["push", "--force", "origin", origin.branch], at: skillPath)

        let sha = (try? await runGit(["rev-parse", "HEAD"], at: skillPath))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let contentHash = computeContentHash(at: skillPath)

        var updated = origin
        updated.lastSyncedCommitSHA = sha
        updated.lastSyncedContentHash = contentHash
        updated.lastChecked = Date()
        try GitHubOrigin.saveOrigin(updated, to: skillPath)
        return updated
    }

    // MARK: - Force Pull (Keep Remote)

    /// Force pull remote state, discarding local changes.
    static func forceRemoteToLocal(skill: DiscoveredSkill, origin: GitHubOrigin) async throws -> GitHubOrigin {
        let skillPath = skill.skillPath

        try await runGit(["fetch", "origin"], at: skillPath)
        try await runGit(["reset", "--hard", "origin/\(origin.branch)"], at: skillPath)

        let sha = (try? await runGit(["rev-parse", "HEAD"], at: skillPath))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let contentHash = computeContentHash(at: skillPath)

        var updated = origin
        updated.lastSyncedCommitSHA = sha
        updated.lastSyncedContentHash = contentHash
        updated.lastChecked = Date()
        try GitHubOrigin.saveOrigin(updated, to: skillPath)
        return updated
    }

    // MARK: - Divergence Detection

    /// Check whether local and remote are in sync.
    static func checkDivergence(skill: DiscoveredSkill, origin: GitHubOrigin) async -> GitHubSyncStatus {
        let skillPath = skill.skillPath

        guard findGitRoot(from: skillPath) != nil else {
            return .error("Not a git repository. Push first to set up tracking.")
        }

        // Fetch latest remote state (silent)
        _ = try? await runGit(["fetch", "origin", "--quiet"], at: skillPath)

        let localSHA = (try? await runGit(["rev-parse", "HEAD"], at: skillPath))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let remoteSHA = (try? await runGit(["rev-parse", "origin/\(origin.branch)"], at: skillPath))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if localSHA.isEmpty || remoteSHA.isEmpty {
            return .error("Could not determine commit SHA")
        }

        if localSHA == remoteSHA { return .inSync }

        let localAheadStr = try? await runGit(["rev-list", "--count", "origin/\(origin.branch)..HEAD"], at: skillPath)
        let remoteAheadStr = try? await runGit(["rev-list", "--count", "HEAD..origin/\(origin.branch)"], at: skillPath)

        let localAhead = Int(localAheadStr?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0") ?? 0
        let remoteAhead = Int(remoteAheadStr?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0") ?? 0

        if localAhead > 0 && remoteAhead == 0 { return .localAhead }
        if remoteAhead > 0 && localAhead == 0 { return .remoteAhead }
        if localAhead > 0 && remoteAhead > 0 { return .diverged }

        return .inSync
    }

    // MARK: - Git Setup for Imported Skills

    /// Initialize a git repo in the skill directory and set up tracking for an imported skill.
    static func setupGitForImportedSkill(at skillPath: URL, origin: GitHubOrigin) async throws {
        let gitDir = skillPath.appendingPathComponent(".git")
        let fm = FileManager.default
        let remoteURL = "https://github.com/\(origin.owner)/\(origin.repoName).git"
        
        if !fm.fileExists(atPath: gitDir.path) {
            try await runGit(["init"], at: skillPath)
            try await runGit(["checkout", "-b", origin.branch], at: skillPath)

            // Create .gitignore
            let gitignoreContent = ".versions/\n.github.json\n.DS_Store\n"
            let gitignorePath = skillPath.appendingPathComponent(".gitignore")
            if !fm.fileExists(atPath: gitignorePath.path) {
                try gitignoreContent.write(to: gitignorePath, atomically: true, encoding: .utf8)
            }

            // Initial commit of existing files
            try await runGit(["add", "SKILL.md"], at: skillPath)
            try? await runGit(["add", ".gitignore"], at: skillPath)
            if fm.fileExists(atPath: skillPath.appendingPathComponent("references").path) {
                try? await runGit(["add", "references/"], at: skillPath)
            }
            if fm.fileExists(atPath: skillPath.appendingPathComponent("scripts").path) {
                try? await runGit(["add", "scripts/"], at: skillPath)
            }
            try await runGit(["commit", "-m", "Import via EnhancedSkills"], at: skillPath)

            // Add remote
            try await runGit(["remote", "add", "origin", remoteURL], at: skillPath)
        } else {
            // Ensure remote origin URL is set correctly
            let remotes = try? await runGit(["remote"], at: skillPath)
            if remotes?.contains("origin") == true {
                try await runGit(["remote", "set-url", "origin", remoteURL], at: skillPath)
            } else {
                try await runGit(["remote", "add", "origin", remoteURL], at: skillPath)
            }
        }

        // Fetch remote so we can track it
        _ = try? await runGit(["fetch", "origin", "--quiet"], at: skillPath)
        
        // Try setting the upstream for the local branch to track the remote branch
        _ = try? await runGit(["branch", "--set-upstream-to=origin/\(origin.branch)", origin.branch], at: skillPath)
    }

    // MARK: - Helpers

    @discardableResult
    private static func runGit(_ args: [String], at directory: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = args
                process.currentDirectoryURL = directory
                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr

                do {
                    try process.run()
                    process.waitUntilExit()
                    let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                    let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                    if process.terminationStatus != 0 {
                        let errStr = String(data: errData, encoding: .utf8) ?? ""
                        continuation.resume(throwing: GitHubSyncError.gitError(errStr.trimmingCharacters(in: .whitespacesAndNewlines)))
                    } else {
                        let output = String(data: outData, encoding: .utf8) ?? ""
                        continuation.resume(returning: output)
                    }
                } catch {
                    continuation.resume(throwing: GitHubSyncError.gitError(error.localizedDescription))
                }
            }
        }
    }

    private static func computeContentHash(at skillPath: URL) -> String? {
        let skillFile = skillPath.appendingPathComponent("SKILL.md")
        guard let data = try? Data(contentsOf: skillFile) else { return nil }
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }

    private static func findGitRoot(from url: URL) -> URL? {
        var current = url
        let fm = FileManager.default
        while current.path != "/" && current.path != "." {
            let gitDir = current.appendingPathComponent(".git")
            if fm.fileExists(atPath: gitDir.path) {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }
        return nil
    }
}
