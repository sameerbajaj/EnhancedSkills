import SwiftUI

enum DS {
    enum Color {
        static let canvas = SwiftUI.Color(red: 0.976, green: 0.969, blue: 0.953)
        static let surface = SwiftUI.Color.white
        static let text = SwiftUI.Color(red: 0.10, green: 0.09, blue: 0.08)
        static let textSecondary = SwiftUI.Color(red: 0.42, green: 0.39, blue: 0.36)
        static let textTertiary = SwiftUI.Color(red: 0.63, green: 0.61, blue: 0.58)
        static let accent = SwiftUI.Color(red: 0.18, green: 0.42, blue: 0.82)
        static let accentLight = SwiftUI.Color(red: 0.18, green: 0.42, blue: 0.82).opacity(0.10)
        static let border = SwiftUI.Color(red: 0.87, green: 0.85, blue: 0.82)
        static let borderLight = SwiftUI.Color(red: 0.92, green: 0.91, blue: 0.89)

        static let synced = SwiftUI.Color(red: 0.14, green: 0.60, blue: 0.38)
        static let syncedBg = SwiftUI.Color(red: 0.14, green: 0.60, blue: 0.38).opacity(0.10)
        static let codexOnly = SwiftUI.Color(red: 0.70, green: 0.38, blue: 0.10)
        static let codexOnlyBg = SwiftUI.Color(red: 0.70, green: 0.38, blue: 0.10).opacity(0.10)
        static let claudeOnly = SwiftUI.Color(red: 0.52, green: 0.20, blue: 0.73)
        static let claudeOnlyBg = SwiftUI.Color(red: 0.52, green: 0.20, blue: 0.73).opacity(0.10)
        static let openclawOnly = SwiftUI.Color(red: 0.08, green: 0.65, blue: 0.52)
        static let openclawOnlyBg = SwiftUI.Color(red: 0.08, green: 0.65, blue: 0.52).opacity(0.10)
        static let geminiOnly = SwiftUI.Color(red: 0.26, green: 0.52, blue: 0.96)
        static let geminiOnlyBg = SwiftUI.Color(red: 0.26, green: 0.52, blue: 0.96).opacity(0.10)
        static let antigravityOnly = SwiftUI.Color(red: 0.85, green: 0.32, blue: 0.40)
        static let antigravityOnlyBg = SwiftUI.Color(red: 0.85, green: 0.32, blue: 0.40).opacity(0.10)
        static let invalid = SwiftUI.Color(red: 0.72, green: 0.14, blue: 0.14)
        static let invalidBg = SwiftUI.Color(red: 0.72, green: 0.14, blue: 0.14).opacity(0.10)
        static let warning = SwiftUI.Color(red: 0.78, green: 0.56, blue: 0.10)
        static let warningBg = SwiftUI.Color(red: 0.78, green: 0.56, blue: 0.10).opacity(0.10)
        static let suggestion = SwiftUI.Color(red: 0.40, green: 0.52, blue: 0.68)
        static let suggestionBg = SwiftUI.Color(red: 0.40, green: 0.52, blue: 0.68).opacity(0.10)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 20
    }
}

extension View {
    func cardShadow() -> some View {
        self.shadow(color: .black.opacity(0.055), radius: 10, x: 0, y: 2)
    }
    func elevatedShadow() -> some View {
        self.shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: 6)
    }
}
