import SwiftUI

struct OnboardingProvidersScreen: View {
    let settings: SettingsStore
    @Binding var providerStatus: [Provider: ProviderScanResult]
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var scanned = false
    @State private var appeared = false

    var foundCount: Int {
        providerStatus.values.filter(\.exists).count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: DS.Spacing.sm) {
                Text("Your Providers")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(DS.Color.text)

                Text(scanned
                     ? (foundCount > 0 ? "Found \(foundCount) provider\(foundCount == 1 ? "" : "s") on your system." : "No provider directories found yet — you can set them up in Settings.")
                     : "Scanning your system…")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.3), value: scanned)
            }
            .padding(.top, DS.Spacing.xl)
            .padding(.horizontal, DS.Spacing.xxxl)

            Spacer(minLength: DS.Spacing.lg)

            // Provider list
            VStack(spacing: 0) {
                ForEach(Array(Provider.allCases.enumerated()), id: \.offset) { index, provider in
                    if index > 0 {
                        Divider().padding(.leading, DS.Spacing.md)
                    }
                    OnboardingProviderRow(
                        provider: provider,
                        result: providerStatus[provider],
                        isEnabled: settings.isEnabled(provider)
                    ) { enabled in
                        settings.setEnabled(enabled, for: provider)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05),
                        value: appeared
                    )
                }
            }
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Color.canvas)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(DS.Color.borderLight, lineWidth: 1)
            )
            .padding(.horizontal, DS.Spacing.xl)

            Spacer()

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
            await scanProviders()
        }
    }

    private func scanProviders() async {
        var results: [Provider: ProviderScanResult] = [:]

        for provider in Provider.allCases {
            guard let defaultPath = provider.defaultRootPath else {
                results[provider] = ProviderScanResult(exists: false, skillCount: 0)
                continue
            }

            let expanded = defaultPath.path
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir) && isDir.boolValue
            let count = exists ? countSkillFolders(at: defaultPath) : 0
            results[provider] = ProviderScanResult(exists: exists, skillCount: count)

            // Auto-enable/disable based on whether directory exists
            settings.setEnabled(exists, for: provider)
        }

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                providerStatus = results
                scanned = true
            }
        }
    }

    private func countSkillFolders(at url: URL) -> Int {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        )) ?? []
        return contents.filter { item in
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir) && isDir.boolValue
        }.count
    }
}
