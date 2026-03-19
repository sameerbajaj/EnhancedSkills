import Foundation

enum GuidelineSeverity: Int, Comparable, CaseIterable {
    case error = 0
    case warning = 1
    case suggestion = 2

    static func < (lhs: GuidelineSeverity, rhs: GuidelineSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .error: return "Error"
        case .warning: return "Warning"
        case .suggestion: return "Suggestion"
        }
    }

    var iconName: String {
        switch self {
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .suggestion: return "info.circle.fill"
        }
    }
}

struct GuidelineRule: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let severity: GuidelineSeverity
    let provider: Provider?  // nil = applies to both
    let isAutoFixable: Bool
}

struct GuidelineViolation: Identifiable, Equatable {
    var id: String { rule.id }
    let rule: GuidelineRule
    let fixHint: String?
    var isAutoFixable: Bool { rule.isAutoFixable }
}

struct ValidationReport: Equatable {
    let provider: Provider
    let violations: [GuidelineViolation]
    let passedRules: [GuidelineRule]

    var errorCount: Int { violations.filter { $0.rule.severity == .error }.count }
    var warningCount: Int { violations.filter { $0.rule.severity == .warning }.count }
    var suggestionCount: Int { violations.filter { $0.rule.severity == .suggestion }.count }
    var totalCount: Int { violations.count }
    var autoFixableCount: Int { violations.filter { $0.isAutoFixable }.count }
}
