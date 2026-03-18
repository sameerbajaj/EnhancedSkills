import SwiftUI

struct SkillDetailView: View {
    @Bindable var state: AppState

    var body: some View {
        if let record = state.selectedRecord {
            DetailContent(record: record, state: state)
        } else {
            VStack {
                Image(systemName: "arrow.left")
                    .font(.system(size: 28, weight: .thin))
                    .foregroundStyle(DS.Color.textTertiary)
                Text("Select a skill")
                    .font(.system(size: 15))
                    .foregroundStyle(DS.Color.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS.Color.canvas)
        }
    }
}

struct DetailContent: View {
    let record: SkillRecord
    @Bindable var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {

                // Header
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack {
                        StatusPill(status: record.status)
                        Spacer()
                        if let skill = record.preferredPreviewSource {
                            Button {
                                state.revealInFinder(skill)
                            } label: {
                                Label("Reveal", systemImage: "folder")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(DS.Color.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(record.displayName)
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(DS.Color.text)

                    if let desc = record.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 14))
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Provider badges
                    HStack(spacing: DS.Spacing.sm) {
                        if record.codexSkill != nil { ProviderBadge(provider: .codex) }
                        if record.claudeSkill != nil { ProviderBadge(provider: .claude) }
                    }
                }

                Divider()

                // Metadata chips
                let source = record.preferredPreviewSource
                if source?.hasScripts == true || source?.hasReferences == true || source?.isSystem == true || source?.parseStatus != .ok {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("METADATA")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DS.Color.textTertiary)
                        HStack(spacing: DS.Spacing.sm) {
                            if source?.isSystem == true {
                                MetaChip(label: "System", icon: "gear")
                            }
                            if source?.hasScripts == true {
                                MetaChip(label: "Scripts", icon: "terminal")
                            }
                            if source?.hasReferences == true {
                                MetaChip(label: "References", icon: "link")
                            }
                            if let ps = source?.parseStatus, ps != .ok {
                                MetaChip(label: ps.rawValue.capitalized, icon: "exclamationmark.triangle", color: DS.Color.invalid)
                            }
                        }
                    }
                    Divider()
                }

                // Paths
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("LOCATIONS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DS.Color.textTertiary)

                    if let skill = record.codexSkill {
                        PathLine(provider: .codex, path: skill.skillPath.path)
                    }
                    if let skill = record.claudeSkill {
                        PathLine(provider: .claude, path: skill.skillPath.path)
                    }
                }

                // Preview
                if let excerpt = record.preferredPreviewSource?.previewExcerpt {
                    Divider()
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text("PREVIEW")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DS.Color.textTertiary)
                        Text(excerpt)
                            .font(.system(size: 13))
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(DS.Spacing.lg)
                            .background(DS.Color.canvas)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.borderLight, lineWidth: 1))
                    }
                }

                Divider()

                // Transfer actions
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("SYNC ACTIONS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DS.Color.textTertiary)

                    if record.codexSkill != nil && record.claudeSkill == nil {
                        TransferButton(label: "Copy to Claude", icon: "arrow.right.circle.fill", provider: .claude) {
                            state.startTransfer(to: .claude)
                        }
                    } else if record.claudeSkill != nil && record.codexSkill == nil {
                        TransferButton(label: "Copy to Codex", icon: "arrow.left.circle.fill", provider: .codex) {
                            state.startTransfer(to: .codex)
                        }
                    } else if record.status == .synced {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DS.Color.synced)
                            Text("Skill is synced across both providers.")
                                .font(.system(size: 13))
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                        .padding(DS.Spacing.lg)
                        .background(DS.Color.syncedBg)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }

                    if let err = state.transferError {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Color.invalid)
                            .padding(DS.Spacing.md)
                            .background(DS.Color.invalidBg)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                }
            }
            .padding(DS.Spacing.xxl)
        }
        .background(DS.Color.canvas)
        .frame(minWidth: 280)
        .sheet(isPresented: $state.showTransferSheet) {
            if let plan = state.transferPlan {
                TransferConfirmationSheet(plan: plan, state: state)
            }
        }
    }
}

struct MetaChip: View {
    let label: String
    let icon: String
    var color: Color = DS.Color.textSecondary

    var body: some View {
        Label(label, systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Color.borderLight)
            .clipShape(Capsule())
    }
}

struct PathLine: View {
    let provider: Provider
    let path: String

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ProviderBadge(provider: provider)
            Text(path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DS.Color.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

struct TransferButton: View {
    let label: String
    let icon: String
    let provider: Provider
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
            }
            .foregroundStyle(provider.badgeColor)
            .padding(DS.Spacing.lg)
            .background(isHovered ? provider.badgeBgColor.opacity(0.8) : provider.badgeBgColor)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(provider.badgeColor.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
