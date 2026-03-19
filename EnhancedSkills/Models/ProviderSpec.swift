import Foundation

struct ProviderSpec {
    let specURL: URL?
    let bestPracticesURL: URL?
    let skillFileName: String
    let requiredFrontmatterFields: [String]
    let optionalFrontmatterFields: [String]
    let specSummary: String

    /// Ready-made context block for feeding into an AI prompt
    var promptContext: String {
        """
        Provider Skill Specification:
        \(specSummary)
        Required frontmatter: \(requiredFrontmatterFields.joined(separator: ", "))
        Optional frontmatter: \(optionalFrontmatterFields.joined(separator: ", "))
        """
    }
}
