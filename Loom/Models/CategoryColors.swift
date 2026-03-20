import SwiftUI

enum CategoryColors {
    // Light mode palette — earthy, matte, desaturated
    private static let lightColors: [String: Color] = [
        "Coding": Color(hex: 0x7b8db8),       // dusty blue
        "Email": Color(hex: 0xc9956a),         // warm clay
        "Communication": Color(hex: 0x5a9a6e), // matte green
        "Design": Color(hex: 0xa07cba),        // dusty purple
        "Writing": Color(hex: 0xc47878),       // matte rose
        "Browsing": Color(hex: 0x6da89a),      // sage
        "Other": Color(hex: 0x9a958e),         // warm gray
    ]

    // Dark mode palette — same hues, pulled down ~15% lightness
    private static let darkColors: [String: Color] = [
        "Coding": Color(hex: 0x6878a0),
        "Email": Color(hex: 0xb0845e),
        "Communication": Color(hex: 0x4e8760),
        "Design": Color(hex: 0x8a6ca3),
        "Writing": Color(hex: 0xa86868),
        "Browsing": Color(hex: 0x5e9487),
        "Other": Color(hex: 0x6b665f),
    ]

    private static let lightOverflow: [Color] = [
        Color(hex: 0xc4a84e), // ochre
        Color(hex: 0x5e9487), // teal
        Color(hex: 0x8a7560), // umber
        Color(hex: 0x7aaa8a), // mint
    ]

    private static let darkOverflow: [Color] = [
        Color(hex: 0xa89040),
        Color(hex: 0x4e8070),
        Color(hex: 0x746350),
        Color(hex: 0x689478),
    ]

    // Terracotta accent — same in both modes
    static let accent = Color(hex: 0xc06040)

    // For "Other" category reference in tests
    static let gray = Color(light: Color(hex: 0x9a958e), dark: Color(hex: 0x6b665f))

    static func color(for category: String) -> Color {
        Color(light: lightColor(for: category), dark: darkColor(for: category))
    }

    private static func lightColor(for category: String) -> Color {
        if let named = lightColors[category] { return named }
        let hash = abs(category.hashValue)
        return lightOverflow[hash % lightOverflow.count]
    }

    private static func darkColor(for category: String) -> Color {
        if let named = darkColors[category] { return named }
        let hash = abs(category.hashValue)
        return darkOverflow[hash % darkOverflow.count]
    }
}

// MARK: - Theme Tokens

enum Theme {
    static let background = Color(light: Color(hex: 0xf7f5f2), dark: Color(hex: 0x242220))
    static let backgroundSecondary = Color(light: Color(hex: 0xf2efec), dark: Color(hex: 0x1e1c1a))
    static let border = Color(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.05))
    static let borderSubtle = Color(light: Color.black.opacity(0.04), dark: Color.white.opacity(0.04))

    static let textPrimary = Color(light: Color(hex: 0x1a1a1a), dark: Color(hex: 0xf0ede8))
    static let textSecondary = Color(light: Color(hex: 0x3a3a3a), dark: Color(hex: 0xc8c3bb))
    static let textTertiary = Color(light: Color(hex: 0x9a958e), dark: Color(hex: 0x6b665f))
    static let textQuaternary = Color(light: Color(hex: 0xb5b0a8), dark: Color(hex: 0x4a4540))

    static let trackFill = Color(light: Color.black.opacity(0.04), dark: Color.white.opacity(0.04))
    static let idleSegment = Color(light: Color(hex: 0xddd9d3).opacity(0.5), dark: Color(hex: 0x363330).opacity(0.5))
}

// MARK: - Color Helpers

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(dark)
            }
            return NSColor(light)
        })
    }
}
