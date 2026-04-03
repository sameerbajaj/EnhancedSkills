import SwiftUI

// MARK: - Supporting Types

struct ProviderScanResult {
    let exists: Bool
    let skillCount: Int
}

// MARK: - Page Enum

enum OnboardingPage: Int, CaseIterable {
    case welcome
    case providers
    case aiBackend
    case ready
}

// MARK: - Onboarding Overlay

struct OnboardingOverlay: View {
    let settings: SettingsStore

    @State private var currentPage: OnboardingPage = .welcome
    @State private var direction: Int = 1
    @State private var providerStatus: [Provider: ProviderScanResult] = [:]
    @State private var detectedBackend: AIBackend? = nil
    @State private var ghInstalled = false

    var body: some View {
        ZStack {
            // Backdrop
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.15))

            // Card
            VStack(spacing: 0) {
                pageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Dot page indicators
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(OnboardingPage.allCases, id: \.rawValue) { page in
                        Circle()
                            .fill(currentPage == page ? DS.Color.accent : DS.Color.border)
                            .frame(width: currentPage == page ? 7 : 5, height: currentPage == page ? 7 : 5)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentPage)
                    }
                }
                .padding(.bottom, DS.Spacing.xl)
            }
            .frame(width: 580, height: 480)
            .background(DS.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
            .elevatedShadow()
        }
    }

    // MARK: - Page Content

    @ViewBuilder
    private var pageContent: some View {
        switch currentPage {
        case .welcome:
            OnboardingWelcomeScreen {
                advance()
            }
            .transition(pageTransition(for: .welcome))
            .id(OnboardingPage.welcome)

        case .providers:
            OnboardingProvidersScreen(
                settings: settings,
                providerStatus: $providerStatus
            ) {
                advance()
            } onBack: {
                retreat()
            }
            .transition(pageTransition(for: .providers))
            .id(OnboardingPage.providers)

        case .aiBackend:
            OnboardingAIBackendScreen(
                settings: settings,
                detectedBackend: $detectedBackend,
                ghInstalled: $ghInstalled
            ) {
                advance()
            } onBack: {
                retreat()
            }
            .transition(pageTransition(for: .aiBackend))
            .id(OnboardingPage.aiBackend)

        case .ready:
            OnboardingReadyScreen(
                settings: settings,
                providerStatus: providerStatus,
                detectedBackend: detectedBackend
            ) {
                settings.hasCompletedOnboarding = true
            } onBack: {
                retreat()
            }
            .transition(pageTransition(for: .ready))
            .id(OnboardingPage.ready)
        }
    }

    // MARK: - Navigation

    private func advance() {
        guard let next = OnboardingPage(rawValue: currentPage.rawValue + 1) else { return }
        direction = 1
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentPage = next
        }
    }

    private func retreat() {
        guard let prev = OnboardingPage(rawValue: currentPage.rawValue - 1) else { return }
        direction = -1
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentPage = prev
        }
    }

    private func pageTransition(for page: OnboardingPage) -> AnyTransition {
        let insertEdge: Edge = direction > 0 ? .trailing : .leading
        let removalEdge: Edge = direction > 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }
}

// MARK: - Navigation Button Styles

struct OnboardingPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(DS.Color.accent)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct OnboardingBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                Text("Back")
                    .font(.system(size: 13, weight: .regular))
            }
            .foregroundStyle(DS.Color.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
