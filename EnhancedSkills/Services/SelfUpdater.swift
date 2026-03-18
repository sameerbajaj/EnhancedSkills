import AppKit
import Foundation

enum SelfUpdateState: Equatable {
    case idle
    case downloading(progress: Double)
    case installing
    case failed(String)
}

enum SelfUpdater {
    static func update(
        dmgURL: URL,
        onStateChange: @escaping @MainActor (SelfUpdateState) -> Void
    ) async {
        do {
            await MainActor.run { onStateChange(.downloading(progress: 0)) }
            let localDMG = try await downloadDMG(from: dmgURL) { fraction in
                Task { @MainActor in onStateChange(.downloading(progress: fraction)) }
            }

            await MainActor.run { onStateChange(.installing) }
            let mountPoint = try await mountDMG(at: localDMG)
            defer {
                unmountDMG(mountPoint: mountPoint)
                try? FileManager.default.removeItem(at: localDMG)
            }

            let runningAppURL = Bundle.main.bundleURL
            let newAppURL = try locateApp(in: mountPoint, preferredAppName: runningAppURL.lastPathComponent)
            try replaceApp(old: runningAppURL, with: newAppURL)
            relaunchApp(at: runningAppURL)
        } catch {
            await MainActor.run { onStateChange(.failed(error.localizedDescription)) }
        }
    }

    private static func downloadDMG(
        from url: URL,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EnhancedSkills-Update", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dest = tempDir.appendingPathComponent("update.dmg")
        try? FileManager.default.removeItem(at: dest)

        let delegate = DownloadDelegate(progress: progress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: url) { tmp, _, error in
                if let error { continuation.resume(throwing: error); return }
                guard let tmp else { continuation.resume(throwing: UpdateError.downloadFailed); return }
                do {
                    try FileManager.default.moveItem(at: tmp, to: dest)
                    continuation.resume(returning: dest)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            task.resume()
        }
    }

    private static func mountDMG(at dmgURL: URL) async throws -> URL {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", dmgURL.path, "-nobrowse", "-readonly", "-mountrandom", "/tmp", "-plist"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.mountFailed }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]] else { throw UpdateError.mountFailed }

        for entity in entities {
            if let mountPoint = entity["mount-point"] as? String {
                return URL(fileURLWithPath: mountPoint)
            }
        }
        throw UpdateError.mountFailed
    }

    private static func unmountDMG(mountPoint: URL) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        p.arguments = ["detach", mountPoint.path, "-quiet"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }

    private static func locateApp(in volume: URL, preferredAppName: String) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(
            at: volume, includingPropertiesForKeys: [.isDirectoryKey]
        )
        let candidates = contents.filter { $0.pathExtension.lowercased() == "app" }
        if let preferred = candidates.first(where: { $0.lastPathComponent == preferredAppName }) { return preferred }
        if candidates.count == 1, let only = candidates.first { return only }
        if let fallback = candidates.first(where: { $0.lastPathComponent.lowercased().contains("enhancedskills") }) { return fallback }
        guard let app = candidates.first else { throw UpdateError.appNotFoundInDMG }
        return app
    }

    private static func replaceApp(old: URL, with new: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: old.path) else { throw UpdateError.currentAppNotFound }

        let parent = old.deletingLastPathComponent()
        let staged = parent.appendingPathComponent(".EnhancedSkills-update-staging.app")
        let backup = parent.appendingPathComponent(".EnhancedSkills-update-backup.app")

        try? fm.removeItem(at: staged)
        try? fm.removeItem(at: backup)
        try fm.copyItem(at: new, to: staged)
        clearQuarantine(at: staged)

        do {
            try fm.moveItem(at: old, to: backup)
            try fm.moveItem(at: staged, to: old)
            try verifyCodeSignature(at: old)
            try? fm.removeItem(at: backup)
        } catch {
            try? fm.removeItem(at: old)
            if fm.fileExists(atPath: backup.path) { try? fm.moveItem(at: backup, to: old) }
            throw UpdateError.installFailed(error.localizedDescription)
        }
    }

    private static func clearQuarantine(at appURL: URL) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        p.arguments = ["-dr", "com.apple.quarantine", appURL.path]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }

    private static func verifyCodeSignature(at appURL: URL) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        p.arguments = ["--verify", "--deep", "--strict", appURL.path]
        p.standardOutput = FileHandle.nullDevice
        let stderr = Pipe()
        p.standardError = stderr
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let msg = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw UpdateError.invalidUpdatedApp(msg ?? "Code signature verification failed.")
        }
    }

    private static func relaunchApp(at appURL: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = """
        #!/bin/bash
        for i in $(seq 1 20); do
            kill -0 \(pid) 2>/dev/null || break
            sleep 0.5
        done
        open "\(appURL.path)"
        """
        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("enhancedskills-relaunch.sh")
        try? script.write(to: scriptURL, atomically: true, encoding: .utf8)

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [scriptURL.path]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        p.qualityOfService = .utility
        try? p.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.terminate(nil)
        }
    }

    enum UpdateError: LocalizedError {
        case downloadFailed, mountFailed, appNotFoundInDMG, currentAppNotFound
        case invalidUpdatedApp(String), installFailed(String)

        var errorDescription: String? {
            switch self {
            case .downloadFailed: return "Failed to download the update."
            case .mountFailed: return "Failed to open the downloaded image."
            case .appNotFoundInDMG: return "No app found in the update image."
            case .currentAppNotFound: return "Cannot locate the running app to replace."
            case .invalidUpdatedApp(let d): return "The downloaded app failed verification. \(d)"
            case .installFailed(let d): return "Failed to install the update. \(d)"
            }
        }
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let onProgress: (Double) -> Void
    init(progress: @escaping (Double) -> Void) { self.onProgress = progress; super.init() }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {}
}
