// ThemeManager.swift
// Commonplace
//
// Manages the active app theme and provides theme-aware colors and fonts.
// Three themes: System (adaptive), Inkwell (warm dark), Dusk (new default).
//
// AppThemeStyle protocol defines all color and font slots.
// Each theme struct conforms to the protocol and fills in the values.
// All views access theme values via style.body, style.primaryText etc.
//
// To add a new theme:
//   1. Add a case to AppTheme enum
//   2. Create a new struct conforming to AppThemeStyle
//   3. Add a case to ThemeManager.style switch
//
// To add a new entry type:
//   1. Add accent, card, and border color constants to InkwellTheme / DuskTheme
//   2. Add a case to cardBackground(for:), cardBorderColor(for:), accentColor(for:)

import SwiftUI
import Combine

enum AppTheme: String, CaseIterable {
    case system   = "System"
    case inkwell  = "Inkwell"
    case dusk     = "Dusk"

    var label: String { rawValue }

    var icon: String {
        switch self {
        case .system:  return "circle.lefthalf.filled"
        case .inkwell: return "book.closed.fill"
        case .dusk:    return "moon.stars.fill"
        }
    }
}

// MARK: - Shared Visual Constants
// Used across all themes — defined once, referenced everywhere

struct SharedTheme {
    static let goldRingGradient = AngularGradient(
        colors: [
            Color(hex: "#C8903A"),
            Color(hex: "#F5D478"),
            Color(hex: "#C8903A"),
            Color(hex: "#8A6028"),
            Color(hex: "#C8903A"),
            Color(hex: "#F5D478"),
            Color(hex: "#C8903A")
        ],
        center: .center,
        startAngle: .degrees(0),
        endAngle: .degrees(360)
    )
}

class ThemeManager: ObservableObject {
    @Published var current: AppTheme {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "appTheme") }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.dusk.rawValue
        self.current = AppTheme(rawValue: saved) ?? .dusk
    }

    var style: any AppThemeStyle {
        switch current {
        case .inkwell: return InkwellStyle()
        case .system:  return SystemStyle()
        case .dusk:    return DuskStyle()
        }
    }

    var colorScheme: ColorScheme? {
        switch current {
        case .system:  return nil
        case .inkwell: return .dark
        case .dusk:    return .dark
        }
    }
}

// MARK: - Theme Style Protocol

protocol AppThemeStyle {
    // Backgrounds
    var background: Color { get }
    var surface: Color { get }
    var cardBackground: Color { get }

    // Text
    var primaryText: Color { get }
    var secondaryText: Color { get }
    var tertiaryText: Color { get }

    // Accent
    var accent: Color { get }
    var accentDim: Color { get }

    // Legacy font slots — kept for compatibility, use AppTypeScale for new work
    var largeTitle: Font { get }
    var title: Font { get }
    var headline: Font { get }
    var body: Font { get }
    var subheadline: Font { get }
    var caption: Font { get }

    // Type scale — use these for all new views
    var typeLargeTitle: Font { get }
    var typeTitle1: Font { get }
    var typeTitle2: Font { get }
    var typeTitle3: Font { get }
    var typeBody: Font { get }
    var typeBodySecondary: Font { get }
    var typeEntryTypeLabel: Font { get }
    var typeLabel: Font { get }
    var typeCaption: Font { get }
    var typeSectionHeader: Font { get }
    var typeMono: Font { get }

    // Pills (tags, stat chips)
        var pillBackground: Color { get }
        var pillForeground: Color { get }

        // Person avatar fallback (no photo)
        var personAvatarBackground: Color { get }
        var personAvatarForeground: Color { get }

        // Card text — used on colored entry type cards
        var cardPrimaryText: Color { get }
        var cardSecondaryText: Color { get }
        var cardMetadataText: Color { get }
        var cardDivider: Color { get }
        var cardBorder: Color { get }

        // Entry type label visibility
        var showsEntryTypeLabel: Bool { get }

        // Behavior
        var usesSerifFonts: Bool { get }
    }

// MARK: - AppThemeStyle default implementations
// All themes get the same type scale — only colors differ

extension AppThemeStyle {
    var typeLargeTitle: Font     { AppTypeScale.largeTitle }
    var typeTitle1: Font         { AppTypeScale.title1 }
    var typeTitle2: Font         { AppTypeScale.title2 }
    var typeTitle3: Font         { AppTypeScale.title3 }
    var typeBody: Font           { AppTypeScale.body }
    var typeBodySecondary: Font  { AppTypeScale.bodySecondary }
    var typeEntryTypeLabel: Font { AppTypeScale.entryTypeLabel }
    var typeLabel: Font          { AppTypeScale.label }
    var typeCaption: Font        { AppTypeScale.caption }
    var typeSectionHeader: Font  { AppTypeScale.sectionHeader }
    var typeMono: Font           { AppTypeScale.mono }
}

// MARK: - Dusk Theme Colors

struct DuskTheme {
    // Background
    static let background  = Color(hex: "#0D0500")
    static let surface     = Color(hex: "#1A1208")
    static let card        = Color(hex: "#221A0E")
    static let cardBorder  = Color(hex: "#2E2418")

    // Text
    static let primaryText   = Color(hex: "#F0E8DC")
    static let secondaryText = Color(hex: "#A89880")
    static let tertiaryText  = Color(hex: "#6A5A48")

    // Accent
    static let accent    = Color(hex: "#A89060")
    static let accentDim = Color(hex: "#6A5A3A")

    // Entry type base colors
    static let noteColor     = Color(hex: "#464645")
    static let journalColor  = Color(hex: "#4A435D")
    static let linkColor     = Color(hex: "#3D505B")
    static let shotColor     = Color(hex: "#5E7272")
    static let soundColor    = Color(hex: "#8E6A5F")
    static let placeColor    = Color(hex: "#526349")
    static let stickyColor   = Color(hex: "#877662")
    static let musicColor    = Color(hex: "#7E505D")
    static let mediaColor    = Color(hex: "#7A5855")

    // Derived border — base color lightened
    static func borderColor(for base: Color) -> Color {
        base.opacity(0.6)
    }

    static func cardBackground(for type: EntryType) -> Color {
        switch type {
        case .text:     return noteColor
        case .journal:  return journalColor
        case .link:     return linkColor
        case .photo:    return shotColor
        case .audio:    return soundColor
        case .location: return placeColor
        case .sticky:   return stickyColor
        case .music:    return musicColor
        case .media:    return mediaColor
        }
    }

    static func accentColor(for type: EntryType) -> Color {
            cardBackground(for: type)
        }

        // Brighter version of the card color for UI chrome on detail views
        // Used for toolbar buttons, metadata text, interactive elements
        static func detailAccentColor(for type: EntryType) -> Color {
            switch type {
            case .text:     return Color(hex: "#8A8A88")
            case .journal:  return Color(hex: "#8A82A8")
            case .link:     return Color(hex: "#7A9AAA")
            case .photo:    return Color(hex: "#9ABAAA")
            case .audio:    return Color(hex: "#C8A898")
            case .location: return Color(hex: "#8AA882")
            case .sticky:   return Color(hex: "#C8B898")
            case .music:    return Color(hex: "#C8909A")
            case .media:    return Color(hex: "#C89890")
            }
        }
}

// MARK: - Dusk Style

struct DuskStyle: AppThemeStyle {
    // Backgrounds
    var background: Color    { DuskTheme.background }
    var surface: Color       { DuskTheme.surface }
    var cardBackground: Color { DuskTheme.card }

    // Text
    var primaryText: Color   { DuskTheme.primaryText }
    var secondaryText: Color { DuskTheme.secondaryText }
    var tertiaryText: Color  { DuskTheme.tertiaryText }

    // Accent
    var accent: Color        { DuskTheme.accent }
    var accentDim: Color     { DuskTheme.accentDim }

    // Legacy font slots
    var largeTitle: Font  { AppTypeScale.largeTitle }
    var title: Font       { AppTypeScale.title2 }
    var headline: Font    { AppTypeScale.title3 }
    var body: Font        { AppTypeScale.body }
    var subheadline: Font { AppTypeScale.bodySecondary }
    var caption: Font     { AppTypeScale.caption }

    // Pills
        var pillBackground: Color        { Color.white.opacity(0.12) }
        var pillForeground: Color        { Color.white.opacity(0.80) }

        // Person avatar
        var personAvatarBackground: Color { Color.white.opacity(0.15) }
        var personAvatarForeground: Color { Color.white.opacity(0.90) }

        // Card text
        var cardPrimaryText: Color   { Color.white.opacity(0.92) }
        var cardSecondaryText: Color { Color.white.opacity(0.60) }
        var cardMetadataText: Color  { Color.white.opacity(0.35) }
        var cardDivider: Color       { Color.white.opacity(0.10) }
        var cardBorder: Color        { Color.white.opacity(0.10) }

        // Entry type label
        var showsEntryTypeLabel: Bool { true }

        // Behavior
        var usesSerifFonts: Bool     { false }
    }

    // MARK: - Inkwell Color Palette

struct InkwellTheme {
    static let background     = Color(hex: "#1A1510")
    static let surface        = Color(hex: "#2A2218")
    static let card           = Color(hex: "#2E2620")
    static let cardBorder     = Color(hex: "#3D3228")
    static let cardBorderTop  = Color(hex: "#4A3E30")
    static let inkPrimary     = Color(hex: "#F0E8D8")
    static let inkSecondary   = Color(hex: "#B8A888")
    static let inkTertiary    = Color(hex: "#7A6A52")
    static let amber          = Color(hex: "#C8903A")
    static let amberDim       = Color(hex: "#8A6028")
    static let textAccent     = Color(hex: "#B8A888")
    static let photoAccent    = Color(hex: "#C07880")
    static let audioAccent    = Color(hex: "#C08840")
    static let linkAccent     = Color(hex: "#6888C8")
    static let journalAccent  = Color(hex: "#9868C8")
    static let locationAccent = Color(hex: "#58A870")
    static let stickyAccent   = Color(hex: "#B8A030")
    static let musicAccent    = Color(hex: "#C87858")
    static let mediaAccent    = Color(hex: "#C85850")
    static let textCard       = Color(hex: "#262626")
    static let photoCard      = Color(hex: "#2E2025")
    static let audioCard      = Color(hex: "#2E2518")
    static let linkCard       = Color(hex: "#1E2230")
    static let journalCard    = Color(hex: "#261830")
    static let locationCard   = Color(hex: "#182820")
    static let stickyCard     = Color(hex: "#282408")
    static let musicCard      = Color(hex: "#2A1510")
    static let mediaCard      = Color(hex: "#2E1A18")
    static let textBorder     = Color(hex: "#363636")
    static let photoBorder    = Color(hex: "#3D2830")
    static let audioBorder    = Color(hex: "#3D3020")
    static let linkBorder     = Color(hex: "#2A3048")
    static let journalBorder  = Color(hex: "#342048")
    static let locationBorder = Color(hex: "#203828")
    static let stickyBorder   = Color(hex: "#383410")
    static let musicBorder    = Color(hex: "#6A2020")
    static let mediaBorder    = Color(hex: "#4A2020")

    static func cardBackground(for type: EntryType) -> Color {
        switch type {
        case .text:     return textCard
        case .photo:    return photoCard
        case .audio:    return audioCard
        case .link:     return linkCard
        case .journal:  return journalCard
        case .location: return locationCard
        case .sticky:   return stickyCard
        case .music:    return musicCard
        case .media:    return mediaCard
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
        case .music:    return musicBorder
        case .media:    return mediaBorder
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
        case .music:    return musicAccent
        case .media:    return mediaAccent
        }
    }

    static func collectionCardBackground(for hex: String) -> Color {
        switch hex.uppercased() {
        case "#FF3B30": return Color(hex: "#2E1A18")
        case "#FF6B6B": return Color(hex: "#2E1E1E")
        case "#FF9500": return Color(hex: "#2E2218")
        case "#FF9F0A": return Color(hex: "#2E2518")
        case "#FFCC00": return Color(hex: "#2A2410")
        case "#FFD60A": return Color(hex: "#282408")
        case "#FF375F": return Color(hex: "#2E1820")
        case "#B5E550": return Color(hex: "#1E2610")
        case "#34C759": return Color(hex: "#182818")
        case "#30D158": return Color(hex: "#182818")
        case "#00C7BE": return Color(hex: "#182828")
        case "#30B0C7": return Color(hex: "#182430")
        case "#32ADE6": return Color(hex: "#182030")
        case "#007AFF": return Color(hex: "#1A2030")
        case "#5856D6": return Color(hex: "#201E38")
        case "#AF52DE": return Color(hex: "#261830")
        case "#BF5AF2": return Color(hex: "#261830")
        case "#FF2D55": return Color(hex: "#2E1820")
        case "#FF6492": return Color(hex: "#2E1C24")
        case "#8E8E93": return Color(hex: "#222224")
        case "#A2845E": return Color(hex: "#281E14")
        case "#636366": return Color(hex: "#1E1E20")
        case "#3A3A3C": return Color(hex: "#1C1C1E")
        case "#1C1C1E": return Color(hex: "#1A1A1C")
        case "#C87858": return Color(hex: "#2A1510")
        default:        return Color(hex: "#2E2620")
        }
    }

    static func collectionAccentColor(for hex: String) -> Color {
        switch hex.uppercased() {
        case "#FF3B30": return Color(hex: "#C85850")
        case "#FF6B6B": return Color(hex: "#E07878")
        case "#FF9500": return Color(hex: "#E08830")
        case "#FF9F0A": return Color(hex: "#E08830")
        case "#FFCC00": return Color(hex: "#C8A830")
        case "#FFD60A": return Color(hex: "#B8A030")
        case "#FF375F": return Color(hex: "#C85870")
        case "#B5E550": return Color(hex: "#90C040")
        case "#34C759": return Color(hex: "#50C068")
        case "#30D158": return Color(hex: "#50C068")
        case "#00C7BE": return Color(hex: "#40C0B8")
        case "#30B0C7": return Color(hex: "#40A8C0")
        case "#32ADE6": return Color(hex: "#3888C0")
        case "#007AFF": return Color(hex: "#4878C8")
        case "#5856D6": return Color(hex: "#6860B8")
        case "#AF52DE": return Color(hex: "#9868C8")
        case "#BF5AF2": return Color(hex: "#9868C8")
        case "#FF2D55": return Color(hex: "#C84868")
        case "#FF6492": return Color(hex: "#C86888")
        case "#8E8E93": return Color(hex: "#787880")
        case "#A2845E": return Color(hex: "#987050")
        case "#636366": return Color(hex: "#606068")
        case "#3A3A3C": return Color(hex: "#505055")
        case "#1C1C1E": return Color(hex: "#404045")
        case "#C87858": return Color(hex: "#C87858")
        default:        return Color(hex: "#B8A888")
        }
    }
}

// MARK: - Inkwell Style

struct InkwellStyle: AppThemeStyle {
    var background: Color    { InkwellTheme.background }
    var surface: Color       { InkwellTheme.surface }
    var cardBackground: Color { InkwellTheme.card }
    var primaryText: Color   { InkwellTheme.inkPrimary }
    var secondaryText: Color { InkwellTheme.inkSecondary }
    var tertiaryText: Color  { InkwellTheme.inkTertiary }
    var accent: Color        { InkwellTheme.amber }
    var accentDim: Color     { InkwellTheme.amberDim }
    var largeTitle: Font  { .system(.largeTitle, design: .serif) }
    var title: Font       { .system(.title, design: .serif) }
    var headline: Font    { .system(.headline, design: .serif) }
    var body: Font        { .system(.body, design: .serif) }
    var subheadline: Font { .system(.subheadline, design: .serif) }
    var caption: Font     { .system(.caption, design: .serif) }
    var pillBackground: Color         { InkwellTheme.surface }
        var pillForeground: Color         { InkwellTheme.inkSecondary }
        var personAvatarBackground: Color { InkwellTheme.surface }
        var personAvatarForeground: Color { InkwellTheme.inkPrimary }
        var cardPrimaryText: Color        { InkwellTheme.inkPrimary }
        var cardSecondaryText: Color      { InkwellTheme.inkSecondary }
        var cardMetadataText: Color       { InkwellTheme.inkTertiary }
        var cardDivider: Color            { InkwellTheme.cardBorderTop }
        var cardBorder: Color             { InkwellTheme.cardBorder }
        var showsEntryTypeLabel: Bool     { true }
        var usesSerifFonts: Bool          { true }
    }

    // MARK: - System Style

struct SystemStyle: AppThemeStyle {
    var background: Color     { Color(uiColor: .systemBackground) }
    var surface: Color        { Color(uiColor: .secondarySystemBackground) }
    var cardBackground: Color { Color(uiColor: .secondarySystemBackground) }
    var primaryText: Color   { Color(uiColor: .label) }
    var secondaryText: Color { Color(uiColor: .secondaryLabel) }
    var tertiaryText: Color  { Color(uiColor: .tertiaryLabel) }
    var accent: Color        { .accentColor }
    var accentDim: Color     { .accentColor.opacity(0.5) }
    var largeTitle: Font  { .largeTitle }
    var title: Font       { .title }
    var headline: Font    { .headline }
    var body: Font        { .body }
    var subheadline: Font { .subheadline }
    var caption: Font     { .caption }
    var pillBackground: Color         { Color(uiColor: .systemGray5) }
        var pillForeground: Color         { Color(uiColor: .label) }
        var personAvatarBackground: Color { Color(uiColor: .systemGray4) }
        var personAvatarForeground: Color { Color(uiColor: .label) }
        var cardPrimaryText: Color        { Color(uiColor: .label) }
        var cardSecondaryText: Color      { Color(uiColor: .secondaryLabel) }
        var cardMetadataText: Color       { Color(uiColor: .tertiaryLabel) }
        var cardDivider: Color            { Color(uiColor: .separator) }
        var cardBorder: Color             { Color(uiColor: .separator) }
        var showsEntryTypeLabel: Bool     { false }
        var usesSerifFonts: Bool          { false }
    }
