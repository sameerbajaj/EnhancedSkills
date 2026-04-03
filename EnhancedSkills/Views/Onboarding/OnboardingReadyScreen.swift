import SwiftUI

struct OnboardingReadyScreen: View {
    let settings: SettingsStore
    let providerStatus: [Provider: ProviderScanResult]
    let detectedBackend: AIBackend?
    let onComplete: () -> Void
    let onBack: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var activeProviders: Int {
        Provider.allCases.filter { settings.isEnabled($0) }.count
    }

    private var totalSkills: Int {
        providerStatus.values.reduce(0) { $0 + $1.skillCount }
    }

    private var backendName: String {
        detectedBackend?.displayName ?? settings.aiBackend.displayName
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Checkmark visual
            ZStack {
                Circle()
                    .fill(DS.Color.syncedBg)
                    .frame(width: 72, height: 72)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.65).delay(0.05),
                        value: appeared
                    )

                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DS.Color.synced)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7).delay(0.15),
                        value: appeared
                    )
            }

            Spacer(minLength: DS.Spacing.xl)

            VStack(spacing: DS.Spacing.sm) {
                Text("You're All Set")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(DS.Color.text)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8).delay(0.2),
                        value: appeared
                    )

                Text("EnhancedSkills is ready to manage your AI skills.")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 6)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8).delay(0.28),
                        value: appeared
                    )
            }
            .padding(.horizontal, DS.Spacing.xxxl)

            Spacer(minLength: DS.Spacing.xl)

            // Summary pills
            HStack(spacing: DS.Spacing.sm) {
                SummaryPill(
                    icon: "square.stack.3d.up",
                    value: "\(activeProviders)",
                    label: "provider\(activeProviders == 1 ? "" : "s")"
                )

                SummaryPill(
                    icon: "doc.text",
                    value: "\(totalSkills)",
                    label: "skill\(totalSkills == 1 ? "" : "s")"
                )

                SummaryPill(
                    icon: "sparkles",
                    value: backendName,
                    label: nil
                )
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(
                reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8).delay(0.35),
                value: appeared
            )

            Spacer()

            // Navigation
            HStack {
                OnboardingBackButton(action: onBack)
                Spacer()
                Button(action: onComplete) {
                    Text("Let's Go")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 140)
                        .padding(.vertical, 11)
                        .background(DS.Color.synced)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.xxxl)
            .padding(.bottom, DS.Spacing.md)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Summary Pill

private struct SummaryPill: View {
    let icon: String
    let value: String
    let label: String?

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.Color.accent)
            Text(label != nil ? "\(value) \(label!)" : value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.Color.text)
                .lineLimit(1)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Color.accentLight)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(DS.Color.accent.opacity(0.2), lineWidth: 1))
    }
}
