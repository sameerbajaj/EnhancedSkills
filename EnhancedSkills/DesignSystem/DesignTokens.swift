import SwiftUI
import AppKit

private func adaptive(
    light: (CGFloat, CGFloat, CGFloat),
    dark: (CGFloat, CGFloat, CGFloat),
    lightAlpha: CGFloat = 1,
    darkAlpha: CGFloat = 1
) -> SwiftUI.Color {
    SwiftUI.Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(red: dark.0, green: dark.1, blue: dark.2, alpha: darkAlpha)
        } else {
            return NSColor(red: light.0, green: light.1, blue: light.2, alpha: lightAlpha)
        }
    })
}

enum DS {
    enum Color {
        static let canvas     = adaptive(light: (0.976, 0.969, 0.953), dark: (0.11, 0.10, 0.09))
        static let surface    = adaptive(light: (1.0,   1.0,   1.0  ), dark: (0.16, 0.15, 0.14))
        static let text       = adaptive(light: (0.10,  0.09,  0.08 ), dark: (0.93, 0.91, 0.89))
        static let textSecondary  = adaptive(light: (0.42, 0.39, 0.36), dark: (0.65, 0.63, 0.60))
        static let textTertiary   = adaptive(light: (0.63, 0.61, 0.58), dark: (0.48, 0.46, 0.44))
        static let accent         = SwiftUI.Color(red: 0.18, green: 0.42, blue: 0.82)
        static let accentLight    = adaptive(light: (0.18, 0.42, 0.82), dark: (0.18, 0.42, 0.82),
                                             lightAlpha: 0.10, darkAlpha: 0.15)
        static let border         = adaptive(light: (0.87, 0.85, 0.82), dark: (0.25, 0.24, 0.22))
        static let borderLight    = adaptive(light: (0.92, 0.91, 0.89), dark: (0.20, 0.19, 0.18))

        static let synced         = SwiftUI.Color(red: 0.14, green: 0.60, blue: 0.38)
        static let syncedBg       = adaptive(light: (0.14, 0.60, 0.38), dark: (0.14, 0.60, 0.38),
                                             lightAlpha: 0.10, darkAlpha: 0.15)
        static let codexOnly      = SwiftUI.Color(red: 0.70, green: 0.38, blue: 0.10)
        static let codexOnlyBg    = adaptive(light: (0.70, 0.38, 0.10), dark: (0.70, 0.38, 0.10),
                                             lightAlpha: 0.10, darkAlpha: 0.15)
        static let claudeOnly     = SwiftUI.Color(red: 0.52, green: 0.20, blue: 0.73)
        static let claudeOnlyBg   = adaptive(light: (0.52, 0.20, 0.73), dark: (0.52, 0.20, 0.73),
                                             lightAlpha: 0.10, darkAlpha: 0.15)
        static let openclawOnly   = SwiftUI.Color(red: 0.08, green: 0.65, blue: 0.52)
        static let openclawOnlyBg = adaptive(light: (0.08, 0.65, 0.52), dark: (0.08, 0.65, 0.52),
                                             lightAlpha: 0.10, darkAlpha: 0.15)
        static let geminiOnly     = SwiftUI.Color(red: 0.26, green: 0.52, blue: 0.96)
        static let geminiOnlyBg   = adaptive(light: (0.26, 0.52, 0.96), dark: (0.26, 0.52, 0.96),
                                             lightAlpha: 0.10, darkAlpha: 0.15)
        static let antigravityOnly   = SwiftUI.Color(red: 0.85, green: 0.32, blue: 0.40)
        static let antigravityOnlyBg = adaptive(light: (0.85, 0.32, 0.40), dark: (0.85, 0.32, 0.40),
                                                lightAlpha: 0.10, darkAlpha: 0.15)
        static let needsSync      = SwiftUI.Color(red: 0.82, green: 0.52, blue: 0.10)
        static let needsSyncBg    = adaptive(light: (0.82, 0.52, 0.10), dark: (0.82, 0.52, 0.10),
                                             lightAlpha: 0.10, darkAlpha: 0.15)
        static let invalid        = SwiftUI.Color(red: 0.72, green: 0.14, blue: 0.14)
        static let invalidBg      = adaptive(light: (0.72, 0.14, 0.14), dark: (0.72, 0.14, 0.14),
                                             lightAlpha: 0.10, darkAlpha: 0.15)
        static let warning        = SwiftUI.Color(red: 0.78, green: 0.56, blue: 0.10)
        static let warningBg      = adaptive(light: (0.78, 0.56, 0.10), dark: (0.78, 0.56, 0.10),
                                             lightAlpha: 0.10, darkAlpha: 0.15)
        static let suggestion     = SwiftUI.Color(red: 0.40, green: 0.52, blue: 0.68)
        static let suggestionBg   = adaptive(light: (0.40, 0.52, 0.68), dark: (0.40, 0.52, 0.68),
                                             lightAlpha: 0.10, darkAlpha: 0.15)
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
