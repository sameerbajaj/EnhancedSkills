import SwiftUI

struct OnboardingAIBackendScreen: View {
    let settings: SettingsStore
    @Binding var detectedBackend: AIBackend?
    @Binding var ghInstalled: Bool
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var cliStatus: [AIBackend: Bool] = [:]
    @State private var scanned = false
    @State private var appeared = false

    private let cliBackends: [AIBackend] = [.claudeCLI, .codexCLI, .googleCLI]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: DS.Spacing.sm) {
                Text("Tools & AI")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(DS.Color.text)

                Text("EnhancedSkills uses AI to evaluate and improve your skills.")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, DS.Spacing.xl)
            .padding(.horizontal, DS.Spacing.xxxl)

            Spacer(minLength: DS.Spacing.lg)

            VStack(spacing: DS.Spacing.md) {
                // AI CLI section
                VStack(alignment: .leading, spacing: 0) {
                    Text("AI BACKENDS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DS.Color.textTertiary)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)

                    Divider()

                    ForEach(Array(cliBackends.enumerated()), id: \.offset) { index, backend in
                        if index > 0 { Divider().padding(.leading, DS.Spacing.md) }
                        AIToolRow(
                            label: backend.displayName,
                            icon: iconName(for: backend),
                            isAvailable: cliStatus[backend] ?? false,
                            isSelected: detectedBackend == backend,
                            isScanned: scanned
                        )
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 6)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: appeared)
                    }

                    if scanned && detectedBackend == nil {
                        Divider().padding(.leading, DS.Spacing.md)
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundStyle(DS.Color.needsSync)
                            Text("No CLI found. Add an API key in Settings → AI to enable evaluations.")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                    }
                }
                .background(DS.Color.canvas)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.borderLight, lineWidth: 1))

                // GitHub CLI section
                VStack(alignment: .leading, spacing: 0) {
                    Text("GITHUB SYNC")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DS.Color.textTertiary)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)

                    Divider()

                    AIToolRow(
                        label: "GitHub CLI (gh)",
                        icon: "arrow.triangle.2.circlepath.circle",
                        isAvailable: ghInstalled,
                        isSelected: false,
                        isScanned: scanned,
                        note: ghInstalled ? nil : "brew install gh"
                    )
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.2), value: appeared)
                }
                .background(DS.Color.canvas)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.borderLight, lineWidth: 1))
            }
            .padding(.horizontal, DS.Spacing.xl)

            Spacer()

            // Footer note
            Text("You can configure API keys and change your AI backend anytime in Settings.")
                .font(.system(size: 11))
                .foregroundStyle(DS.Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xxxl)

            Spacer(minLength: DS.Spacing.md)

            // Navigation
            HStack {
                OnboardingBackButton(action: onBack)
                Spacer()
                OnboardingPrimaryButton(title: "Continue", action: onNext)
                    .frame(width: 140)
            }
            .padding(.horizontal, DS.Spacing.xxxl)
            .padding(.bottom, DS.Spacing.md)
        }
        .task {
            appeared = true
            await detectTools()
        }
    }

    private func detectTools() async {
        var status: [AIBackend: Bool] = [:]
        for backend in cliBackends {
            status[backend] = AIBackendRunner.cliPath(for: backend) != nil
        }
        let ghFound = GHCLIRunner.isInstalled()

        // Pick best available backend
        let best: AIBackend? = cliBackends.first(where: { status[$0] == true })

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                cliStatus = status
                ghInstalled = ghFound
                scanned = true
            }
            if let best {
                detectedBackend = best
                settings.aiBackend = best
            }
        }
    }

    private func iconName(for backend: AIBackend) -> String {
        switch backend {
        case .claudeCLI: return "sparkles"
        case .codexCLI: return "chevron.left.forwardslash.chevron.right"
        case .googleCLI: return "globe"
        default: return "cpu"
        }
    }
}

// MARK: - AI Tool Row

private struct AIToolRow: View {
    let label: String
    let icon: String
    let isAvailable: Bool
    let isSelected: Bool
    let isScanned: Bool
    var note: String? = nil

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(isAvailable ? DS.Color.accent : DS.Color.textTertiary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(DS.Color.text)
                if let note, !isAvailable {
                    Text(note)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DS.Color.textTertiary)
                }
            }

            Spacer()

            if isScanned {
                if isAvailable {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Color.synced)
                        Text(isSelected ? "Selected" : "Available")
                            .font(.system(size: 11))
                            .foregroundStyle(isSelected ? DS.Color.accent : DS.Color.textSecondary)
                    }
                } else {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Color.textTertiary)
                        Text("Not found")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.textTertiary)
                    }
                }
            } else {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(isSelected ? DS.Color.accentLight : Color.clear)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
