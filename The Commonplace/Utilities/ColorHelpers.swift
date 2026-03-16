import SwiftUI

// Convert hex string to Color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
    
    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int(r * 255),
                      Int(g * 255),
                      Int(b * 255))
    }
}

// 20 curated colors
struct CuratedColors {
    static let all: [(name: String, hex: String)] = [
        ("Red",         "#FF3B30"),
        ("Coral",       "#FF6B6B"),
        ("Orange",      "#FF9500"),
        ("Amber",       "#FFCC00"),
        ("Yellow",      "#FFD60A"),
        ("Lime",        "#B5E550"),
        ("Green",       "#34C759"),
        ("Mint",        "#00C7BE"),
        ("Teal",        "#30B0C7"),
        ("Cyan",        "#32ADE6"),
        ("Blue",        "#007AFF"),
        ("Indigo",      "#5856D6"),
        ("Purple",      "#AF52DE"),
        ("Pink",        "#FF2D55"),
        ("Rose",        "#FF6492"),
        ("Brown",       "#A2845E"),
        ("Gray",        "#8E8E93"),
        ("Slate",       "#636366"),
        ("Charcoal",    "#3A3A3C"),
        ("Black",       "#1C1C1E"),
    ]
}
