// WeeklyReviewTheme.swift
// Commonplace
//
// Visual constants for the Weekly Review feature.
// Purple-to-blue diagonal gradient used across feed card,
// detail view background, and review flow section cards.
// Gold ring border matches Person avatar ring language.

import SwiftUI

enum WeeklyReviewTheme {

    // MARK: - Gradient
    static let gradientColors: [Color] = [
        Color(hex: "#2D1F4E"),
        Color(hex: "#1A2A5E")
    ]

    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#1e1040"), Color(hex: "#0f1a3d")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Gold Ring
    static var goldRingGradient: AngularGradient {
        AngularGradient(
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

    // MARK: - Text Colors
    static let primaryText      = Color(hex: "#E2D9F3")
    static let secondaryText    = Color(hex: "#B4A0FF").opacity(0.7)
    static let tertiaryText     = Color(hex: "#A08CFF").opacity(0.5)
    static let accentGold       = Color(hex: "#F5D478")
    static let accentPurple     = Color(hex: "#A78BFA")

    // MARK: - Surface
    static let sectionDivider   = Color(hex: "#9682FF").opacity(0.15)
    static let statBackground   = Color.white.opacity(0.06)
    static let tagBackground    = Color(hex: "#7864C8").opacity(0.2)

    // MARK: - Tag name
    static let weeklyReviewTag  = "weekly-review"
}
