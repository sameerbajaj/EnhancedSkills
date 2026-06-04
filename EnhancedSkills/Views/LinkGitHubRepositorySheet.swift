import SwiftUI

struct LinkGitHubRepositorySheet: View {
    let skill: DiscoveredSkill
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var repoURL: String = ""
    @State private var branch: String = "main"
    @State private var syncDirection: SyncDirection = .upstream
    @State private var localError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {

            // Header
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DS.Color.accent)
                    Text(isEditing ? "Edit GitHub Link" : "Link GitHub Repository")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DS.Color.text)
                }
                Text("Attach an existing GitHub repository to \"\(skill.parsedName ?? skill.folderName)\".")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.textSecondary)
            }

            // Form
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {

                // Repo URL
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Repository URL or owner/repo")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.Color.textSecondary)
                    TextField("https://github.com/owner/repo", text: $repoURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                }

                // Branch
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Tracking Branch")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.Color.textSecondary)
                    TextField("main", text: $branch)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                }

                // Mode Selection
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Sync Mode")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.Color.textSecondary)
                    Picker("Sync Mode", selection: $syncDirection) {
                        Text("Read-Only (Upstream) — Pull updates only").tag(SyncDirection.upstream)
                        Text("Read-Write (Owner) — Push & Pull changes").tag(SyncDirection.origin)
                    }
                    .pickerStyle(.radioGroup)
                    .font(.system(size: 12))
                }

                // Info disclaimer if not authenticated or no gh CLI
                if !state.ghCLIAvailable || !state.ghCLIAuthenticated {
                    HStack(alignment: .top, spacing: DS.Spacing.xs) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.textTertiary)
                        Text("No active GitHub CLI login. You can still link, but write access checks will be bypassed.")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.Color.textTertiary)
                    }
                    .padding(.top, 2)
                }

                // Error display
                if let err = localError ?? state.linkError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Color.invalid)
                        .padding(DS.Spacing.sm)
                        .background(DS.Color.invalidBg)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }

                // Actions
                HStack {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Color.textSecondary)

                    Spacer()

                    Button {
                        link()
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            if state.isLinking {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "link")
                                    .font(.system(size: 14))
                            }
                            Text(state.isLinking ? "Linking…" : "Link Repository")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(canLink ? DS.Color.accent : DS.Color.accent.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canLink)
                }
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 440)
        .onAppear {
            if let origin = skill.githubOrigin {
                repoURL = origin.repoURL
                branch = origin.branch
                syncDirection = origin.syncDirection
            } else {
                repoURL = ""
                branch = "main"
                syncDirection = .upstream
            }
        }
    }

    private var isEditing: Bool {
        skill.githubOrigin != nil
    }

    private var canLink: Bool {
        !repoURL.trimmingCharacters(in: .whitespaces).isEmpty && !state.isLinking
    }

    private func link() {
        Task {
            do {
                try await state.linkToGitHub(
                    skill: skill,
                    repoURL: repoURL.trimmingCharacters(in: .whitespacesAndNewlines),
                    branch: branch.trimmingCharacters(in: .whitespacesAndNewlines),
                    syncDirection: syncDirection
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    localError = error.localizedDescription
                }
            }
        }
    }
}
