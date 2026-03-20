import SwiftUI

struct GitHubDivergenceSheet: View {
    let skill: DiscoveredSkill
    let origin: GitHubOrigin
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {

            // Header
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "exclamationmark.icloud.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DS.Color.diverged)
                    Text("Diverged Changes")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DS.Color.text)
                }
                Text("Both your local copy and the remote repository have changed. Choose how to resolve.")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Repo info
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "link")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Color.textTertiary)
                Text(origin.repoURL)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(DS.Color.accent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .onTapGesture {
                        if let url = URL(string: origin.repoURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }
            }

            // Resolution options
            VStack(spacing: DS.Spacing.sm) {
                if origin.hasWriteAccess {
                    DivergenceOptionButton(
                        title: "Keep Local (Force Push)",
                        description: "Overwrite the remote repository with your local changes. Remote changes will be lost.",
                        icon: "arrow.up.circle.fill",
                        color: DS.Color.localAhead
                    ) {
                        Task {
                            await state.forceLocalToGitHub(skill: skill)
                            dismiss()
                        }
                    }
                }

                DivergenceOptionButton(
                    title: "Keep Remote (Force Pull)",
                    description: "Overwrite your local copy with the remote repository content. Local changes will be lost.",
                    icon: "arrow.down.circle.fill",
                    color: DS.Color.remoteAhead
                ) {
                    Task {
                        await state.forceRemoteToLocal(skill: skill)
                        dismiss()
                    }
                }

                DivergenceOptionButton(
                    title: "Disconnect",
                    description: "Remove the GitHub link from this skill without changing any content.",
                    icon: "xmark.circle",
                    color: DS.Color.textSecondary
                ) {
                    state.disconnectFromGitHub(skill: skill)
                    dismiss()
                }
            }

            // Error
            if let err = state.githubSyncError {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.invalid)
                    .padding(DS.Spacing.sm)
                    .background(DS.Color.invalidBg)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }

            // Cancel
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 440)
    }
}

private struct DivergenceOptionButton: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Color.text)
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Color.textTertiary)
            }
            .padding(DS.Spacing.md)
            .background(isHovered ? DS.Color.canvas : DS.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.borderLight, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
