import SwiftUI
import Combine

enum AppTheme: String, CaseIterable {
    case system   = "System"
    case inkwell  = "Inkwell"
    
    var label: String { rawValue }
    
    var icon: String {
        switch self {
        case .system:  return "circle.lefthalf.filled"
        case .inkwell: return "book.closed.fill"
        }
    }
}

class ThemeManager: ObservableObject {
    @Published var current: AppTheme {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "appTheme") }
    }
    
    init() {
        let saved = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.system.rawValue
        self.current = AppTheme(rawValue: saved) ?? .system
    }
    
    var colorScheme: ColorScheme? {
        switch current {
        case .system:  return nil
        case .inkwell: return .dark
        }
    }
}

// MARK: - Inkwell Color Palette

struct InkwellTheme {
    // Backgrounds
    static let background     = Color(hex: "#1A1510")
    static let surface        = Color(hex: "#2A2218")
    static let card           = Color(hex: "#2E2620")
    static let cardBorder     = Color(hex: "#3D3228")
    static let cardBorderTop  = Color(hex: "#4A3E30")
    
    // Ink
    static let inkPrimary     = Color(hex: "#F0E8D8")
    static let inkSecondary   = Color(hex: "#B8A888")
    static let inkTertiary    = Color(hex: "#7A6A52")
    
    // Amber accent
    static let amber          = Color(hex: "#C8903A")
    static let amberDim       = Color(hex: "#8A6028")
    
    // Entry type accents — warm, muted
    static let textAccent     = Color(hex: "#B8A888")
    static let photoAccent    = Color(hex: "#C07880")
    static let audioAccent    = Color(hex: "#C08840")
    static let linkAccent     = Color(hex: "#6888C8")
    static let journalAccent  = Color(hex: "#9868C8")
    static let locationAccent = Color(hex: "#58A870")
    static let stickyAccent   = Color(hex: "#B8A030")
    
    // Entry card backgrounds
    static let textCard       = Color(hex: "#262626")
    static let photoCard      = Color(hex: "#2E2025")
    static let audioCard      = Color(hex: "#2E2518")
    static let linkCard       = Color(hex: "#1E2230")
    static let journalCard    = Color(hex: "#261830")
    static let locationCard   = Color(hex: "#182820")
    static let stickyCard     = Color(hex: "#282408")
    
    // Entry card borders
    static let textBorder     = Color(hex: "#363636")
    static let photoBorder    = Color(hex: "#3D2830")
    static let audioBorder    = Color(hex: "#3D3020")
    static let linkBorder     = Color(hex: "#2A3048")
    static let journalBorder  = Color(hex: "#342048")
    static let locationBorder = Color(hex: "#203828")
    static let stickyBorder   = Color(hex: "#383410")
    
    static func cardBackground(for type: EntryType) -> Color {
        switch type {
        case .text:     return textCard
        case .photo:    return photoCard
        case .audio:    return audioCard
        case .link:     return linkCard
        case .journal:  return journalCard
        case .location: return locationCard
        case .sticky:   return stickyCard
        }
    }
    
    static func cardBorderColor(for type: EntryType) -> Color {
        switch type {
        case .text:     return textBorder
        case .photo:    return photoBorder
        case .audio:    return audioBorder
        case .link:     return linkBorder
        case .journal:  return journalBorder
        case .location: return locationBorder
        case .sticky:   return stickyBorder
        }
    }
    
    static func accentColor(for type: EntryType) -> Color {
        switch type {
        case .text:     return textAccent
        case .photo:    return photoAccent
        case .audio:    return audioAccent
        case .link:     return linkAccent
        case .journal:  return journalAccent
        case .location: return locationAccent
        case .sticky:   return stickyAccent
        }
    }
    // MARK: - Collection color mappings (muted Inkwell versions of the 20 curated colors)
    
    static func collectionCardBackground(for hex: String) -> Color {
        switch hex.uppercased() {
        case "#FF3B30": return Color(hex: "#2E1A18") // Red
        case "#FF6B6B": return Color(hex: "#2E1E1E") // Coral
        case "#FF9500": return Color(hex: "#2E2218") // Orange
        case "#FFCC00": return Color(hex: "#2A2410") // Amber
        case "#FFD60A": return Color(hex: "#282408") // Yellow
        case "#B5E550": return Color(hex: "#1E2610") // Lime
        case "#34C759": return Color(hex: "#182818") // Green
        case "#00C7BE": return Color(hex: "#182828") // Mint
        case "#30B0C7": return Color(hex: "#182430") // Teal
        case "#32ADE6": return Color(hex: "#182030") // Cyan
        case "#007AFF": return Color(hex: "#1A2030") // Blue
        case "#5856D6": return Color(hex: "#201E38") // Indigo
        case "#AF52DE": return Color(hex: "#261830") // Purple
        case "#FF2D55": return Color(hex: "#2E1820") // Pink
        case "#FF6492": return Color(hex: "#2E1C24") // Rose
        case "#A2845E": return Color(hex: "#281E14") // Brown
        case "#8E8E93": return Color(hex: "#222224") // Gray
        case "#636366": return Color(hex: "#1E1E20") // Slate
        case "#3A3A3C": return Color(hex: "#1C1C1E") // Charcoal
        case "#1C1C1E": return Color(hex: "#1A1A1C") // Black
        default:        return Color(hex: "#2E2620")
        }
    }
    
    static func collectionAccentColor(for hex: String) -> Color {
        switch hex.uppercased() {
        case "#FF3B30": return Color(hex: "#C85850") // Red
        case "#FF6B6B": return Color(hex: "#E07878") // Coral
        case "#FF9500": return Color(hex: "#E08830") // Orange
        case "#AF52DE": return Color(hex: "#B070E0") // Purple
        case "#FF2D55": return Color(hex: "#E05070") // Pink
        case "#FF6492": return Color(hex: "#E07898") // Rose
        case "#34C759": return Color(hex: "#50C068") // Green
        case "#00C7BE": return Color(hex: "#40C0B8") // Mint
        case "#30B0C7": return Color(hex: "#40A8C0") // Teal
        case "#32ADE6": return Color(hex: "#3888C0") // Cyan
        case "#007AFF": return Color(hex: "#4878C8") // Blue
        case "#5856D6": return Color(hex: "#6860B8") // Indigo
        case "#AF52DE": return Color(hex: "#9868C8") // Purple
        case "#FF2D55": return Color(hex: "#C84868") // Pink
        case "#FF6492": return Color(hex: "#C86888") // Rose
        case "#A2845E": return Color(hex: "#987050") // Brown
        case "#8E8E93": return Color(hex: "#787880") // Gray
        case "#636366": return Color(hex: "#606068") // Slate
        case "#3A3A3C": return Color(hex: "#505055") // Charcoal
        case "#1C1C1E": return Color(hex: "#404045") // Black
        default:        return Color(hex: "#B8A888")
        }
    }
}
