import Foundation

enum TransferMode: String, CaseIterable, Identifiable {
    case symlink = "Symlink"
    case copy = "Copy"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .symlink: return "Linked (Symlink)"
        case .copy: return "Standalone Copy"
        }
    }

    var description: String {
        switch self {
        case .symlink: return "Destination symlinks to the source directory and stays in sync automatically."
        case .copy: return "Creates an independent duplicate copy of the skill files."
        }
    }
}

struct SkillTransferPlan {
    let skillSlug: String
    let sourceProvider: Provider
    let destinationProvider: Provider
    let sourcePath: URL
    let destinationPath: URL
    let sourceFileCount: Int
    let destinationExists: Bool
    var willReplace: Bool
    var warnings: [String]
    var mode: TransferMode = .symlink
}

