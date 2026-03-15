import SwiftUI

enum CategoryColors {
    static let indigo = Color(red: 0.369, green: 0.361, blue: 0.902)
    static let orange = Color(red: 1.0, green: 0.624, blue: 0.039)
    static let green = Color(red: 0.188, green: 0.820, blue: 0.345)
    static let purple = Color(red: 0.749, green: 0.353, blue: 0.949)
    static let pink = Color(red: 1.0, green: 0.216, blue: 0.373)
    static let cyan = Color(red: 0.392, green: 0.824, blue: 1.0)
    static let gray = Color(red: 0.557, green: 0.557, blue: 0.576)
    static let yellow = Color(red: 1.0, green: 0.839, blue: 0.039)
    static let teal = Color(red: 0.255, green: 0.784, blue: 0.667)
    static let brown = Color(red: 0.635, green: 0.518, blue: 0.369)
    static let mint = Color(red: 0.388, green: 0.902, blue: 0.765)

    private static let namedColors: [String: Color] = [
        "Coding": indigo,
        "Email": orange,
        "Communication": green,
        "Design": purple,
        "Writing": pink,
        "Browsing": cyan,
        "Other": gray,
    ]

    private static let overflowPalette: [Color] = [yellow, teal, brown, mint]

    static func color(for category: String) -> Color {
        if let named = namedColors[category] {
            return named
        }
        let hash = abs(category.hashValue)
        return overflowPalette[hash % overflowPalette.count]
    }
}
