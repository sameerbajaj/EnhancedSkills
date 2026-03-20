import SwiftUI

struct PublishToGitHubSheet: View {
    let skill: DiscoveredSkill
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var repoName: String = ""
    @State private var description: String = ""
    @State private var visibility: RepoVisibility = .public
    @State private var publishedURL: String?
    @State private var localError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {

            // Header
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "arrow.up.to.line.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DS.Color.accent)
                    Text("Publish to GitHub")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DS.Color.text)
                }
                Text("Create a new GitHub repository for \"\(skill.parsedName ?? skill.folderName)\".")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.textSecondary)
            }

            if let publishedURL {
                // Success state
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(DS.Color.synced)
                        Text("Published successfully!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DS.Color.synced)
                    }
                    Text(publishedURL)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(DS.Color.accent)
                        .onTapGesture {
                            if let url = URL(string: publishedURL) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                }
                .padding(DS.Spacing.lg)
                .background(DS.Color.syncedBg)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.synced.opacity(0.3), lineWidth: 1))

                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.Color.accent)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Color.accentLight)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
            } else {
                // Form
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {

                    // Repo name
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Repository Name")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.Color.textSecondary)
                        TextField("my-skill-name", text: $repoName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, design: .monospaced))
                    }

                    // Description
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Description")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.Color.textSecondary)
                        TextField("What does this skill do?", text: $description)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                    }

                    // Visibility
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Visibility")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.Color.textSecondary)
                        HStack(spacing: DS.Spacing.xl) {
                            ForEach(RepoVisibility.allCases, id: \.rawValue) { option in
                                Button {
                                    visibility = option
                                } label: {
                                    HStack(spacing: DS.Spacing.xs) {
                                        Image(systemName: visibility == option ? "largecircle.fill.circle" : "circle")
                                            .font(.system(size: 12))
                                            .foregroundStyle(visibility == option ? DS.Color.accent : DS.Color.textTertiary)
                                        Text(option.rawValue.capitalized)
                                            .font(.system(size: 13))
                                            .foregroundStyle(DS.Color.text)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Error display
                    if let err = localError ?? state.publishError {
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
                            publish()
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                if state.isPublishing {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 14))
                                }
                                Text(state.isPublishing ? "Publishing…" : "Publish")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(canPublish ? DS.Color.accent : DS.Color.accent.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canPublish)
                    }
                }
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 440)
        .onAppear {
            repoName = skill.folderName
            description = skill.parsedDescription ?? ""
        }
    }

    private var canPublish: Bool {
        !repoName.trimmingCharacters(in: .whitespaces).isEmpty && !state.isPublishing
    }

    private func publish() {
        Task {
            do {
                let origin = try await state.publishToGitHub(
                    skill: skill,
                    repoName: repoName.trimmingCharacters(in: .whitespaces),
                    visibility: visibility,
                    description: description.trimmingCharacters(in: .whitespaces)
                )
                await MainActor.run {
                    publishedURL = origin.repoURL
                }
            } catch {
                await MainActor.run {
                    localError = error.localizedDescription
                }
            }
        }
    }
}
