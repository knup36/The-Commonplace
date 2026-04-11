// ChroniclesCardContainer.swift
// Commonplace
//
// Shared card container used by all Chronicles cards.
// Provides consistent visual treatment — dark amber gradient background,
// gold border, amber section header with icon.
//
// Usage:
//   ChroniclesCardContainer(title: "On This Day", icon: "calendar") {
//       // card content here
//   }

import SwiftUI

struct ChroniclesCardContainer<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ChroniclesTheme.accentAmber)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(ChroniclesTheme.accentAmber)
            }
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ChroniclesTheme.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(ChroniclesTheme.cardBorderGradient, lineWidth: 0.5)
                )
        )
    }
}
