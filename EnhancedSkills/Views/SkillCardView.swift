import SwiftUI

struct SkillCardView: View {
    let record: SkillRecord
    let isSelected: Bool
    var index: Int = 0
    var usageCount: Int = 0
    var evaluationScore: Int? = nil
    var sortOrder: SkillSortOrder = .lastModified
    var lastUsedDate: Date? = nil

    @State private var appeared = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(record.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? DS.Color.accent : DS.Color.text)
                        .lineLimit(1)

                    if let desc = record.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Color.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                StatusPill(status: record.status)
            }

            HStack(spacing: DS.Spacing.sm) {
                ForEach(Provider.allCases) { provider in
                    if record.skills[provider] != nil {
                        ProviderBadge(provider: provider)
                    }
                }
                if record.totalViolationCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                        Text("\(record.totalViolationCount)")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(DS.Color.warning)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(DS.Color.warningBg)
                    .clipShape(Capsule())
                }
                GitHubSyncBadge(status: record.githubSyncStatus)
                if usageCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                        Text("\(usageCount)")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(DS.Color.accent)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(DS.Color.accentLight)
                    .clipShape(Capsule())
                }
                if let score = evaluationScore {
                    EvaluationScoreBadge(score: score)
                }
                Spacer()
                contextualDateView
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(isSelected ? DS.Color.accentLight : (isHovered ? DS.Color.surface.opacity(0.8) : DS.Color.surface))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(isSelected ? DS.Color.accent.opacity(0.3) : DS.Color.borderLight, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        .scaleEffect(isHovered && !isSelected ? 1.005 : 1.0)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(.spring(response: 0.3, dampingFraction: 0.85).delay(min(Double(index) * 0.02, 0.3)), value: appeared)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onAppear { appeared = true }
        .onHover { isHovered = $0 }
    }

    // MARK: - Context-Aware Date Display

    @ViewBuilder
    private var contextualDateView: some View {
        switch sortOrder {
        case .createdNewest, .createdOldest:
            if let date = record.createdDate {
                DateLabel(label: "Created", date: date, style: .abbreviated)
            }
        case .recentlyAccessed:
            if let date = lastUsedDate {
                DateLabel(label: "Used", date: date, style: .relative)
            } else if let date = record.lastModified {
                DateLabel(label: "Modified", date: date, style: .relative)
            }
        default:
            if let date = record.lastModified {
                DateLabel(label: "Modified", date: date, style: .relative)
            }
        }
    }
}

struct StatusPill: View {
    let status: SkillStatus

    var fg: Color {
        switch status {
        case .synced: return DS.Color.synced
        case .needsSync: return DS.Color.needsSync
        case .conflict, .invalid: return DS.Color.invalid
        default:
            // For provider-only statuses, use the provider's badge color
            if let provider = providerFromStatus(status) {
                return provider.badgeColor
            }
            return DS.Color.textSecondary
        }
    }
    var bg: Color {
        switch status {
        case .synced: return DS.Color.syncedBg
        case .needsSync: return DS.Color.needsSyncBg
        case .conflict, .invalid: return DS.Color.invalidBg
        default:
            if let provider = providerFromStatus(status) {
                return provider.badgeBgColor
            }
            return DS.Color.borderLight
        }
    }

    private func providerFromStatus(_ status: SkillStatus) -> Provider? {
        switch status {
        case .codexOnly: return .codex
        case .claudeOnly: return .claude
        case .openclawOnly: return .openclaw
        case .antigravityOnly: return .antigravity
        default: return nil
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
    }
}

struct GitHubSyncBadge: View {
    let status: GitHubSyncStatus

    private var icon: String? {
        switch status {
        case .notLinked: return nil
        case .checking: return "arrow.clockwise"
        case .inSync: return "checkmark.icloud.fill"
        case .localAhead: return "icloud.and.arrow.up.fill"
        case .remoteAhead: return "icloud.and.arrow.down.fill"
        case .diverged: return "exclamationmark.icloud.fill"
        case .error: return "xmark.icloud.fill"
        }
    }

    private var color: Color {
        switch status {
        case .notLinked: return .clear
        case .checking: return DS.Color.textTertiary
        case .inSync: return DS.Color.synced
        case .localAhead: return DS.Color.localAhead
        case .remoteAhead: return DS.Color.remoteAhead
        case .diverged: return DS.Color.diverged
        case .error: return DS.Color.invalid
        }
    }

    var body: some View {
        if let icon {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
        }
    }
}

struct ProviderBadge: View {
    let provider: Provider

    var body: some View {
        Text(provider.displayName)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(provider.badgeColor)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 2)
            .background(provider.badgeBgColor)
            .clipShape(Capsule())
    }
}

struct EvaluationScoreBadge: View {
    let score: Int

    private var color: Color {
        score >= 7 ? DS.Color.synced :
        score >= 4 ? DS.Color.warning :
        DS.Color.invalid
    }

    private var bgColor: Color {
        score >= 7 ? DS.Color.syncedBg :
        score >= 4 ? DS.Color.warningBg :
        DS.Color.invalidBg
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
            Text("\(score)/10")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 2)
        .background(bgColor)
        .clipShape(Capsule())
    }
}

// MARK: - Date Label Helper

enum DateLabelStyle {
    case relative
    case abbreviated
}

struct DateLabel: View {
    let label: String
    let date: Date
    let style: DateLabelStyle

    private static let abbreviatedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(DS.Color.textTertiary)
            switch style {
            case .relative:
                Text(date, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Color.textTertiary)
            case .abbreviated:
                Text(Self.abbreviatedFormatter.string(from: date))
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Color.textTertiary)
            }
        }
    }
}
