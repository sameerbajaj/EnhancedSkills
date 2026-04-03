import SwiftUI

struct OnboardingWelcomeScreen: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: DS.Spacing.xl)

            ProviderConstellationView()

            Spacer(minLength: DS.Spacing.lg)

            VStack(spacing: DS.Spacing.sm) {
                Text("Your AI Skills, Unified")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(DS.Color.text)
                    .multilineTextAlignment(.center)

                Text("One place to discover, sync, and improve skills\nacross all your AI coding assistants.")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Spacer(minLength: DS.Spacing.xl)

            FeatureBullets()

            Spacer(minLength: DS.Spacing.xl)

            OnboardingPrimaryButton(title: "Get Started", action: onNext)
                .padding(.horizontal, DS.Spacing.xxxl)
        }
        .padding(.horizontal, DS.Spacing.xxxl)
        .padding(.bottom, DS.Spacing.md)
    }
}

// MARK: - Feature Bullets

private struct FeatureBullets: View {
    private let features: [(icon: String, text: String)] = [
        ("square.stack.3d.up", "Discover and organize skills across all your AI coding tools"),
        ("arrow.triangle.2.circlepath", "Keep skills in sync and transfer between providers"),
        ("sparkles", "AI-powered evaluation and improvement suggestions")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Color.accent)
                        .frame(width: 20)
                        .padding(.top, 1)

                    Text(feature.text)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(DS.Color.canvas)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Color.borderLight, lineWidth: 1)
        )
    }
}

// MARK: - Provider Constellation

private struct ProviderConstellationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    private let providers = Provider.allCases
    private let radius: CGFloat = 72

    var body: some View {
        ZStack {
            // Connection lines
            ForEach(Array(providers.enumerated()), id: \.offset) { index, provider in
                let angle = pentagonAngle(index: index)
                ConstellationLine(
                    from: .zero,
                    to: CGPoint(
                        x: radius * cos(angle),
                        y: radius * sin(angle)
                    )
                )
                .stroke(provider.badgeColor.opacity(0.18), lineWidth: 1)
            }

            // Provider circles
            ForEach(Array(providers.enumerated()), id: \.offset) { index, provider in
                let angle = pentagonAngle(index: index)
                let floatY: CGFloat = floatOffset(for: index)

                ZStack {
                    Circle()
                        .fill(provider.badgeBgColor)
                    Circle()
                        .strokeBorder(provider.badgeColor.opacity(0.35), lineWidth: 1.5)
                    Text(String(provider.displayName.prefix(1)))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(provider.badgeColor)
                }
                .frame(width: 34, height: 34)
                .offset(
                    x: radius * cos(angle),
                    y: radius * sin(angle) + (isAnimating ? floatY : 0)
                )
                .animation(
                    reduceMotion ? nil :
                        .easeInOut(duration: 2.2 + Double(index) * 0.18)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.22),
                    value: isAnimating
                )
            }

            // Center hub
            ZStack {
                Circle()
                    .fill(DS.Color.accent)
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)
        }
        .frame(width: 200, height: 200)
        .onAppear {
            guard !reduceMotion else { return }
            isAnimating = true
        }
    }

    private func pentagonAngle(index: Int) -> Double {
        -Double.pi / 2 + Double(index) * (2 * Double.pi / 5)
    }

    private func floatOffset(for index: Int) -> CGFloat {
        [6.0, -5.0, 5.5, -6.0, 4.5][index % 5]
    }
}

private struct ConstellationLine: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: CGPoint(x: center.x + from.x, y: center.y + from.y))
        path.addLine(to: CGPoint(x: center.x + to.x, y: center.y + to.y))
        return path
    }
}
