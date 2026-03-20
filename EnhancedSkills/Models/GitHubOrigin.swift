import Foundation

// MARK: - Sync Direction

enum SyncDirection: String, Codable, Equatable {
    case origin    // user owns/published this repo
    case upstream  // user imported from someone else
}

// MARK: - Repo Visibility

enum RepoVisibility: String, Codable, Equatable, CaseIterable {
    case `public` = "public"
    case `private` = "private"
}

// MARK: - GitHub Sync Status

enum GitHubSyncStatus: Equatable {
    case notLinked
    case checking
    case inSync
    case localAhead
    case remoteAhead
    case diverged
    case error(String)

    static func == (lhs: GitHubSyncStatus, rhs: GitHubSyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notLinked, .notLinked): return true
        case (.checking, .checking): return true
        case (.inSync, .inSync): return true
        case (.localAhead, .localAhead): return true
        case (.remoteAhead, .remoteAhead): return true
        case (.diverged, .diverged): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }

    var displayName: String {
        switch self {
        case .notLinked: return "Not Linked"
        case .checking: return "Checking…"
        case .inSync: return "In Sync"
        case .localAhead: return "Local Ahead"
        case .remoteAhead: return "Remote Ahead"
        case .diverged: return "Diverged"
        case .error: return "Error"
        }
    }

    var sfSymbol: String {
        switch self {
        case .notLinked: return "cloud.slash"
        case .checking: return "arrow.clockwise"
        case .inSync: return "checkmark.icloud.fill"
        case .localAhead: return "icloud.and.arrow.up.fill"
        case .remoteAhead: return "icloud.and.arrow.down.fill"
        case .diverged: return "exclamationmark.icloud.fill"
        case .error: return "xmark.icloud.fill"
        }
    }
}

// MARK: - GitHub Origin

struct GitHubOrigin: Codable, Equatable {
    var repoURL: String
    var owner: String
    var repoName: String
    var branch: String
    var lastSyncedCommitSHA: String?
    var lastSyncedContentHash: String?
    var syncDirection: SyncDirection
    var hasWriteAccess: Bool
    var lastChecked: Date?

    // MARK: - Persistence

    static func saveOrigin(_ origin: GitHubOrigin, to skillPath: URL) throws {
        let url = skillPath.appendingPathComponent(".github.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(origin)
        try data.write(to: url, options: .atomic)
    }

    static func loadOrigin(from skillPath: URL) -> GitHubOrigin? {
        let url = skillPath.appendingPathComponent(".github.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(GitHubOrigin.self, from: data)
    }

    // MARK: - URL Helpers

    /// Parse owner and repo name from a GitHub URL or "owner/repo" string
    static func parseOwnerRepo(from urlString: String) -> (owner: String, repoName: String)? {
        let cleaned = urlString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://github.com/", with: "")
            .replacingOccurrences(of: "http://github.com/", with: "")
            .replacingOccurrences(of: "https://raw.githubusercontent.com/", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let parts = cleaned.split(separator: "/", maxSplits: 2)
        guard parts.count >= 2 else { return nil }
        return (String(parts[0]), String(parts[1]))
    }
}
