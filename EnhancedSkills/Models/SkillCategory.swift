import SwiftUI

public struct SkillCategory: Codable, Equatable, Hashable, Identifiable {
    public let name: String
    public var id: String { name }

    public init(name: String) {
        self.name = name
    }

    public var tint: Color {
        let hash = abs(name.hashValue)
        let colors: [Color] = [
            Color(red: 0.85, green: 0.35, blue: 0.15), // Burnt orange
            Color(red: 0.15, green: 0.65, blue: 0.35), // Emerald
            Color(red: 0.55, green: 0.20, blue: 0.85), // Purple
            Color(red: 0.10, green: 0.55, blue: 0.70), // Blue-teal
            Color(red: 0.75, green: 0.15, blue: 0.35), // Rose
            Color(red: 0.80, green: 0.55, blue: 0.10), // Gold
            Color(red: 0.65, green: 0.40, blue: 0.25), // Brownish
            Color(red: 0.10, green: 0.45, blue: 0.85), // Royal blue
            Color(red: 0.60, green: 0.10, blue: 0.10), // Dark red
            Color(red: 0.45, green: 0.55, blue: 0.20), // Olive
            Color(red: 0.10, green: 0.60, blue: 0.60), // Cyan-teal
        ]
        return colors[hash % colors.count]
    }

    public var background: Color {
        tint.opacity(0.12)
    }

    public var icon: String {
        let hash = abs(name.hashValue)
        let icons = [
            "sparkles",
            "arrow.triangle.pull",
            "checkmark.shield.fill",
            "doc.text.fill",
            "shippingbox.fill",
            "play.square.fill",
            "arrow.3.trianglepath",
            "pencil.and.outline",
            "network",
            "lock.fill",
            "folder.fill",
            "bookmark.fill",
            "hammer.fill",
            "tray.fill",
            "cpu"
        ]
        return icons[hash % icons.count]
    }
}
