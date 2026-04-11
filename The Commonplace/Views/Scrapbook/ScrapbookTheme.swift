// ScrapbookTheme.swift
// Commonplace
//
// Centralized visual constants for Scrapbook feed mode.
// All scrapbook cards draw from this single source of truth.
//
// Design philosophy:
//   The scrapbook is a distinct visual world — warm, physical, analog.
//   Nothing here inherits from AppThemeStyle — the scrapbook aesthetic
//   IS the theme. Like a physical notebook, it looks the same regardless
//   of the user's preferred app theme.
//
// Color language:
//   Paper    — warm aged cream, slightly darker than white
//   Ink      — deep warm brown, like fountain pen ink
//   Muted    — mid-tone warm brown for secondary text
//   Subtle   — light warm tone for decorative elements and dates
//   Tape     — semi-transparent warm white for Polaroid tape strips
//
// Typography:
//   All scrapbook cards use Georgia serif — a reliable system serif
//   that renders well at all sizes without requiring NYLabel.
//   Sizes are fixed and do not scale with Dynamic Type by design.

import SwiftUI

enum ScrapbookTheme {

    // MARK: - Paper

    /// Main background — warm aged cream, like an old Moleskine page
    static let paperColor = Color(red: 0.94, green: 0.91, blue: 0.84)

    /// Dot grid color for the background pattern
    static let dotColor = Color(red: 0.55, green: 0.48, blue: 0.35)

    /// Dot grid opacity — very subtle, should barely be noticeable
    static let dotOpacity: Double = 0.2

    /// Dot radius in points
    static let dotRadius: CGFloat = 1.0

    /// Dot grid spacing in points
    static let dotSpacing: CGFloat = 20.0

    // MARK: - Ink Colors

    /// Primary text — deep warm brown, like fountain pen ink
    static let inkPrimary = Color(red: 0.12, green: 0.09, blue: 0.05)

    /// Secondary text — mid warm brown
    static let inkSecondary = Color(red: 0.32, green: 0.25, blue: 0.15)

    /// Tertiary text — lighter warm brown for captions and dates
    static let inkTertiary = Color(red: 0.52, green: 0.44, blue: 0.30)

    /// Decorative elements — subtle warm tone for dividers, ornaments
    static let inkDecorative = Color(red: 0.62, green: 0.54, blue: 0.38)

    // MARK: - Card Surfaces

    /// Polaroid / photo card white — slightly warm white
    static let polaroidWhite = Color(red: 0.97, green: 0.96, blue: 0.93)

    /// Sticky note yellow
    static let stickyYellow = Color(red: 0.97, green: 0.92, blue: 0.42)

    /// Sticky note shadow color
    static let stickyShadow = Color(red: 0.7, green: 0.65, blue: 0.1).opacity(0.3)

    /// Tape strip color — semi-transparent warm white
    static let tapeColor = Color(red: 0.92, green: 0.88, blue: 0.78).opacity(0.7)

    // MARK: - Typography

    /// Large title serif — for Note titles, Polaroid captions
    static func titleFont(size: CGFloat = 22) -> Font {
        .custom("Georgia", size: size)
    }

    /// Body serif — for note body text, clipping content
    static func bodyFont(size: CGFloat = 16) -> Font {
        .custom("Georgia", size: size)
    }

    /// Caption — small caps style for dates and metadata
    static func captionFont(size: CGFloat = 10) -> Font {
        .system(size: size, weight: .medium)
    }

    // MARK: - Decorative

    /// Ornament used as section divider in Note cards
    static let ornament = "✦"

    /// Standard corner radius for scrapbook cards
    static let cardCornerRadius: CGFloat = 4.0

    /// Shadow for cards sitting on the paper
    static let cardShadowColor = Color.black.opacity(0.12)
    static let cardShadowRadius: CGFloat = 6.0
    static let cardShadowY: CGFloat = 3.0
}
