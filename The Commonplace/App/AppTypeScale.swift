// AppTypeScale.swift
// Commonplace
//
// Defines the app-wide type scale as static Font values.
// All views should reference these constants rather than hardcoding
// font sizes. Changing a value here ripples out everywhere.
//
// Type scale steps: 9 → 11 → 13 → 15 → 17 → 22 → 28 → 34
//
// Two typefaces:
//   - New York (serif) — hero titles and entry type labels
//   - SF Rounded — all UI chrome, body text, captions
//
// New York is accessed via .system(design: .serif) which resolves
// to New York on iOS 16+ automatically — no custom font setup needed.

import SwiftUI

enum AppTypeScale {

    // MARK: - Display / Hero

    /// 34pt New York Black — entry detail titles (Tuesday, On Happiness)
    static let largeTitle: Font = Font.custom(".NewYorkLarge-Black", size: 34)

    /// 28pt New York Semibold — reserved for future large section headers
    static let title1: Font = Font.custom(".NewYorkLarge-Semibold", size: 28)

    /// 22pt New York Semibold — feed nav titles, weekly review header
    static let title2: Font = Font.custom(".NewYorkMedium-Semibold", size: 22)

    // MARK: - Content

    /// 17pt SF Rounded Semibold — album title, media title, secondary headers
    static let title3: Font = .system(size: 17, weight: .semibold, design: .rounded)

    /// 17pt SF Rounded Regular — note body, journal body
    static let body: Font = .system(size: 17, weight: .regular, design: .rounded)

    /// 15pt SF Rounded Regular — article previews, track name, descriptions
    static let bodySecondary: Font = .system(size: 15, weight: .regular, design: .rounded)

    // MARK: - UI Chrome

    /// 11pt New York Regular uppercase +1pt tracking — feed card type label (NOTE, LINK · ARTICLE)
    /// Apply with .tracking(1) at the call site
    static let entryTypeLabel: Font = Font.custom(".NewYork-Regular", size: 11)

    /// 13pt SF Rounded Semibold — tag pills, stat pills
    static let label: Font = .system(size: 13, weight: .semibold, design: .rounded)

    /// 11pt SF Rounded Regular — metadata footer, location, timestamps
    static let caption: Font = .system(size: 11, weight: .regular, design: .rounded)

    /// 9pt SF Rounded Semibold uppercase +0.6pt tracking — section dividers (PEOPLE, THIS WEEK)
    /// Apply with .tracking(0.6) and .textCase(.uppercase) at the call site
    static let sectionHeader: Font = .system(size: 9, weight: .semibold, design: .rounded)

    // MARK: - Special

    /// 13pt SF Mono Regular — durations, timestamps in audio/sound
    static let mono: Font = .system(size: 13, weight: .regular, design: .monospaced)
}
