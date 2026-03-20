import Foundation

// MARK: - GH CLI Error

enum GHCLIError: LocalizedError {
    case notInstalled
    case notAuthenticated
    case commandFailed(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "GitHub CLI (gh) is not installed. Install it with: brew install gh"
        case .notAuthenticated:
            return "Not authenticated with GitHub. Run: gh auth login"
        case .commandFailed(let msg):
            return "gh command failed: \(msg)"
        case .parseError(let msg):
            return "Could not parse gh output: \(msg)"
        }
    }
}

// MARK: - GH CLI Runner

struct GHCLIRunner {

    private static let knownPaths = [
        "/opt/homebrew/bin/gh",
        "/usr/local/bin/gh",
        "/usr/bin/gh",
        "/opt/local/bin/gh"
    ]

    static var ghPath: String? {
        for path in knownPaths {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return resolveViaWhich()
    }

    private static func resolveViaWhich() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["gh"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let path, !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return nil }
        return path
    }

    static func isInstalled() -> Bool { ghPath != nil }

    static func isAuthenticated() async -> Bool {
        guard ghPath != nil else { return false }
        do {
            let output = try await run(["auth", "status"])
            return output.contains("Logged in to github.com") || output.contains("✓ Logged in")
        } catch {
            return false
        }
    }

    static func authenticatedUser() async throws -> String {
        let output = try await run(["auth", "status"])
        // gh auth status output: "✓ Logged in to github.com account <username> (...)"
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("account") {
                // Extract the username after "account "
                if let range = trimmed.range(of: "account ") {
                    let rest = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    let user = rest.components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "("))).first ?? rest
                    if !user.isEmpty { return user }
                }
            }
        }
        throw GHCLIError.parseError("Could not determine authenticated user from: \(output)")
    }

    @discardableResult
    static func run(_ args: [String], workingDirectory: URL? = nil) async throws -> String {
        guard let ghPath else { throw GHCLIError.notInstalled }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: ghPath)
                process.arguments = args
                if let workingDirectory {
                    process.currentDirectoryURL = workingDirectory
                }
                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr

                do {
                    try process.run()
                    process.waitUntilExit()
                    let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                    let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: outData, encoding: .utf8) ?? ""
                    let errOutput = String(data: errData, encoding: .utf8) ?? ""
                    if process.terminationStatus != 0 {
                        let msg = errOutput.isEmpty ? output : errOutput
                        continuation.resume(throwing: GHCLIError.commandFailed(msg.trimmingCharacters(in: .whitespacesAndNewlines)))
                    } else {
                        continuation.resume(returning: output)
                    }
                } catch {
                    continuation.resume(throwing: GHCLIError.commandFailed(error.localizedDescription))
                }
            }
        }
    }

    static func runJSON<T: Decodable>(_ args: [String], as type: T.Type, workingDirectory: URL? = nil) async throws -> T {
        let output = try await run(args, workingDirectory: workingDirectory)
        guard let data = output.data(using: .utf8) else {
            throw GHCLIError.parseError("Empty output")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    // MARK: - Write Access Check

    static func checkWriteAccess(owner: String, repoName: String) async -> Bool {
        do {
            let output = try await run(["api", "repos/\(owner)/\(repoName)", "--jq", ".permissions.push"])
            return output.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        } catch {
            return false
        }
    }
}
