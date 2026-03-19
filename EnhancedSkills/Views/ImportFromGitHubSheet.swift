import SwiftUI
import AppKit

struct ImportFromGitHubSheet: View {
    let settings: SettingsStore
    let onDismiss: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var phase: ImportPhase = .input
    @State private var urlText: String = ""
    @State private var fetchedContent: GitHubSkillContent?
    @State private var selectedProviders: Set<Provider> = []
    @State private var importResults: [(Provider, String)] = []
    @State private var errorMessage: String = ""

    enum ImportPhase {
        case input
        case fetching
        case preview
        case importing
        case done
        case error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            switch phase {
            case .input:
                inputPhase
            case .fetching:
                fetchingPhase
            case .preview:
                previewPhase
            case .importing:
                importingPhase
            case .done:
                donePhase
            case .error:
                errorPhase
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(width: 520)
        .background(DS.Color.surface)
        .onAppear {
            autoPopulateFromClipboard()
            selectedProviders = Set(settings.configuredProviders)
        }
    }

    // MARK: - Input Phase

    private var inputPhase: some View {
        Group {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Import from GitHub")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(DS.Color.text)
                Text("Paste a GitHub URL to a skill or SKILL.md file")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Color.textSecondary)
            }

            HStack(spacing: DS.Spacing.sm) {
                TextField("https://github.com/user/repo/tree/main/my-skill", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(DS.Spacing.md)
                    .background(DS.Color.canvas)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Color.border, lineWidth: 1))

                Button {
                    if let str = NSPasteboard.general.string(forType: .string) {
                        urlText = str
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Paste from clipboard")
            }

            HStack {
                cancelButton

                Spacer()

                Button {
                    startFetch()
                } label: {
                    Text("Fetch")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.vertical, DS.Spacing.md)
                        .background(urlText.isEmpty ? DS.Color.border : DS.Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plain)
                .disabled(urlText.isEmpty)
            }
        }
    }

    // MARK: - Fetching Phase

    private var fetchingPhase: some View {
        VStack(spacing: DS.Spacing.lg) {
            ProgressView()
                .controlSize(.regular)
            Text("Fetching skill from GitHub…")
                .font(.system(size: 13))
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    // MARK: - Preview Phase

    private var previewPhase: some View {
        Group {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Import from GitHub")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(DS.Color.text)
                Text("Review the skill before importing")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Color.textSecondary)
            }

            if let content = fetchedContent {
                // Skill info card
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text(content.inferredName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.Color.text)
                    if !content.inferredDescription.isEmpty {
                        Text(content.inferredDescription)
                            .font(.system(size: 13))
                            .foregroundStyle(DS.Color.textSecondary)
                            .lineLimit(3)
                    }
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.textTertiary)
                        Text(content.inferredFolderName)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(DS.Color.textTertiary)
                    }
                    Text(content.originalURL)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DS.Color.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(DS.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Color.canvas)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.borderLight, lineWidth: 1))

                // Provider selection
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("IMPORT TO")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DS.Color.textTertiary)

                    ForEach(settings.configuredProviders) { provider in
                        providerRow(provider: provider, content: content)
                    }
                }

                // Content preview
                DisclosureGroup {
                    ScrollView {
                        let reformatted = selectedProviders.first.map {
                            GitHubImportService.reformatForProvider(content, provider: $0)
                        } ?? content.rawContent
                        Text(reformatted)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(DS.Color.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DS.Spacing.sm)
                    }
                    .frame(maxHeight: 160)
                } label: {
                    Text("Preview content")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.Color.textSecondary)
                }

                // Actions
                HStack {
                    cancelButton

                    Spacer()

                    Button {
                        startImport()
                    } label: {
                        Text("Import to \(selectedProviders.count) Provider\(selectedProviders.count == 1 ? "" : "s")")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, DS.Spacing.xl)
                            .padding(.vertical, DS.Spacing.md)
                            .background(selectedProviders.isEmpty ? DS.Color.border : DS.Color.accent)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedProviders.isEmpty)
                }
            }
        }
    }

    private func providerRow(provider: Provider, content: GitHubSkillContent) -> some View {
        let isSelected = selectedProviders.contains(provider)
        let exists: Bool = {
            guard let root = settings.rootPath(for: provider) else { return false }
            return GitHubImportService.skillExists(content, at: provider, rootPath: root)
        }()

        return HStack(spacing: DS.Spacing.md) {
            ProviderBadge(provider: provider)
            Text(provider.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.Color.text)
            Spacer()
            if exists {
                Text("Will replace existing")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Color.warning)
            }
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { newValue in
                    if newValue { selectedProviders.insert(provider) }
                    else { selectedProviders.remove(provider) }
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    // MARK: - Importing Phase

    private var importingPhase: some View {
        VStack(spacing: DS.Spacing.lg) {
            ProgressView()
                .controlSize(.regular)
            Text("Importing skill…")
                .font(.system(size: 13))
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    // MARK: - Done Phase

    private var donePhase: some View {
        Group {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(DS.Color.synced)
                Text("Import Successful")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DS.Color.text)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                ForEach(importResults, id: \.0) { provider, path in
                    HStack(spacing: DS.Spacing.sm) {
                        ProviderBadge(provider: provider)
                        Text(path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(DS.Color.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Color.canvas)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

            HStack {
                Spacer()
                Button {
                    onDismiss()
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.vertical, DS.Spacing.md)
                        .background(DS.Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Error Phase

    private var errorPhase: some View {
        Group {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Import Failed")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(DS.Color.text)
            }

            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DS.Color.invalid)
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Color.invalid)
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Color.invalidBg)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

            if errorMessage.contains("not found") || errorMessage.contains("404") {
                Text("Make sure the repository is public and the URL points to a folder containing SKILL.md.")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.textSecondary)
            }

            HStack {
                cancelButton

                Spacer()

                Button {
                    phase = .input
                } label: {
                    Text("Try Again")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.vertical, DS.Spacing.md)
                        .background(DS.Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Shared Components

    private var cancelButton: some View {
        Button {
            dismiss()
        } label: {
            Text("Cancel")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.Color.textSecondary)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.md)
                .background(DS.Color.borderLight)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func autoPopulateFromClipboard() {
        if let str = NSPasteboard.general.string(forType: .string),
           str.contains("github.com") {
            urlText = str
        }
    }

    private func startFetch() {
        phase = .fetching
        Task {
            do {
                let content = try await GitHubImportService.fetchSkillContent(from: urlText)
                await MainActor.run {
                    fetchedContent = content
                    phase = .preview
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    phase = .error
                }
            }
        }
    }

    private func startImport() {
        guard let content = fetchedContent else { return }
        phase = .importing
        Task {
            var results: [(Provider, String)] = []
            var firstError: Error?
            for provider in selectedProviders.sorted(by: { $0.rawValue < $1.rawValue }) {
                guard let rootPath = settings.rootPath(for: provider) else {
                    firstError = firstError ?? GitHubImportError.providerNotConfigured(provider)
                    continue
                }
                do {
                    try GitHubImportService.importSkill(content, to: provider, rootPath: rootPath)
                    let destPath = rootPath.appendingPathComponent(content.inferredFolderName).path
                    results.append((provider, destPath))
                } catch {
                    firstError = firstError ?? error
                }
            }

            await MainActor.run {
                if results.isEmpty, let err = firstError {
                    errorMessage = err.localizedDescription
                    phase = .error
                } else {
                    importResults = results
                    phase = .done
                }
            }
        }
    }
}
