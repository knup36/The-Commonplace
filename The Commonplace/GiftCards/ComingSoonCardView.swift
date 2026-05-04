//
//  ComingSoonCardView.swift
//  The Commonplace
//
//  Created by John Caldwell on 5/3/26.
//


// ComingSoonCardView.swift
// Commonplace
//
// Feed card surfaced on Mondays when one or more saved movies or TV shows
// are releasing within the next 14 days.
//
// Displays all qualifying entries in a single card with release date labels.
// Dismissing the card removes it from the feed for the rest of the week.
// The card is archived to Chronicles on fire — dismissal does not re-archive.
//
// Animated shimmer border follows the same pattern as other gift cards.

import SwiftUI

struct ComingSoonCardView: View {
    let card: ComingSoonCard
    let onDismiss: () -> Void

    @State private var shimmerAngle: Double = 0
    @EnvironmentObject var themeManager: ThemeManager
    var style: any AppThemeStyle { themeManager.style }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack(spacing: 8) {
                Image(systemName: "popcorn.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("Coming Soon")
                    .font(style.typeCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(style.secondaryText)
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(style.tertiaryText)
                }
                .buttonStyle(.plain)
            }

            // Entry rows
            VStack(alignment: .leading, spacing: 10) {
                ForEach(card.items) { item in
                    HStack(spacing: 12) {
                        // Cover art
                        Group {
                            if let path = item.coverPath,
                               let data = MediaFileManager.load(path: path),
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Rectangle()
                                    .fill(style.surface)
                                    .overlay(
                                        Image(systemName: item.mediaType == "tv" ? "tv.fill" : "film.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(style.tertiaryText)
                                    )
                            }
                        }
                        .frame(width: 36, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        // Title + release label
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(style.typeBody)
                                .fontWeight(.medium)
                                .foregroundStyle(style.primaryText)
                                .lineLimit(1)
                            Text("Releases \(item.releaseDateLabel)")
                                .font(style.typeCaption)
                                .foregroundStyle(.orange)
                        }

                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(style.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    AngularGradient(
                        colors: [.orange, .yellow, .orange.opacity(0.4), .orange],
                        center: .center,
                        startAngle: .degrees(shimmerAngle),
                        endAngle: .degrees(shimmerAngle + 360)
                    ),
                    lineWidth: 1.5
                )
        )
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                shimmerAngle = 360
            }
        }
    }
}