// ChroniclesTheme.swift
// Commonplace
//
// Visual constants for the Chronicles tab (v2.0).
// Warm amber/gold palette — evokes candlelight, old photographs,
// archival paper. The retrospective complement to Today's present-tense energy.
//
// Mental model: Chronicles is your past, warmly lit.
// Today = present tense. Chronicles = past tense.
//
// Color language:
//   Deep warm brown backgrounds — like aged leather or worn paper
//   Amber/gold accents — consistent with the gold ring language elsewhere
//   Soft cream text — warm and readable against dark backgrounds

import SwiftUI

enum ChroniclesTheme {

    // MARK: - Gradients

    /// Card background gradient — deep warm brown, top to bottom
    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#2C1A0E"), Color(hex: "#1A0F08")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Full background gradient — slightly lighter than card
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#1E1208"), Color(hex: "#120A04")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Amber ring gradient — used for section borders and decorative rings
    static var amberRingGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(hex: "#C8903A"),
                Color(hex: "#F5D478"),
                Color(hex: "#E8A84A"),
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

    /// Subtle amber stroke for card borders
    static var cardBorderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#C8903A").opacity(0.6),
                Color(hex: "#F5D478").opacity(0.3),
                Color(hex: "#C8903A").opacity(0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Text Colors

    static let primaryText   = Color(hex: "#F5E6C8")   // warm cream
    static let secondaryText = Color(hex: "#D4A96A").opacity(0.8)  // amber mid
    static let tertiaryText  = Color(hex: "#B8864A").opacity(0.6)  // amber dim
    static let accentAmber   = Color(hex: "#F5D478")   // bright gold
    static let accentWarm    = Color(hex: "#E8A84A")   // warm amber

    // MARK: - Surface Colors

    static let sectionDivider  = Color(hex: "#C8903A").opacity(0.15)
    static let statBackground  = Color.white.opacity(0.05)
    static let tagBackground   = Color(hex: "#8A6028").opacity(0.25)
    static let cardSurface     = Color(hex: "#3D2410").opacity(0.6)

    // MARK: - Icon

    /// SF Symbol used as the Chronicles icon throughout the app
    static let icon = "scroll.fill"

    /// Decorative symbol used in headers — mirrors Weekly Review's ✦
    static let headerSymbol = "◆"
}
