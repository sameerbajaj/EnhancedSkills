import Foundation

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
}
