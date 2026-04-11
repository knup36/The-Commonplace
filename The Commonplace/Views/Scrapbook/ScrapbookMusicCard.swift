// ScrapbookMusicCard.swift
// Commonplace
//
// Scrapbook feed card for .music entries.
// Renders as a mini punk rock / DIY gig flyer.
// Construction paper background color cycles through 4 options
// based on entry UUID — deterministic, always the same color per entry.
//
// Layout:
//   - Album artwork inset (not full bleed), B&W desaturated
//   - Artist name in Impact font, HUGE, wraps if needed
//   - Track name and album name below
//   - Thin rules separating sections
//   - Date and note at the bottom
//   - Paper texture overlay via GeometryReader for authentic feel
//
// Slight rotation seeded from UUID — flyers are never perfectly straight.

import SwiftUI

struct ScrapbookMusicCard: View {
    let entry: Entry

    static let flyerColors: [Color] = [
        Color(red: 0.95, green: 0.85, blue: 0.25),  // yellow
        Color(red: 0.95, green: 0.45, blue: 0.55),  // pink
        Color(red: 0.35, green: 0.65, blue: 0.90),  // blue
        Color(red: 0.45, green: 0.82, blue: 0.50),  // green
    ]

    var flyerColor: Color {
        let hash = abs(entry.id.uuidString.hashValue)
        return Self.flyerColors[hash % Self.flyerColors.count]
    }

    var rotation: Double {
        let hash = abs(entry.id.uuidString.hashValue)
        let normalized = Double(hash % 800) / 100.0
        return normalized - 4.0
    }

    private let cardWidth: CGFloat = 220

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 8) {

                // Album artwork — inset, not full bleed, B&W
                if let artworkPath = entry.musicArtworkPath,
                   let data = MediaFileManager.load(path: artworkPath),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardWidth - 20, height: (cardWidth - 20) * 0.65)
                        .clipped()
                        .saturation(0)
                        .contrast(1.3)
                        .overlay(flyerColor.opacity(0.2))
                        .frame(maxWidth: .infinity)
                } else {
                    Rectangle()
                        .fill(Color.black.opacity(0.15))
                        .frame(width: cardWidth - 20, height: (cardWidth - 20) * 0.65)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 44, weight: .black))
                                .foregroundStyle(Color.black.opacity(0.3))
                        )
                        .frame(maxWidth: .infinity)
                }

                // Thin rule
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(height: 1.5)

                // Artist name — Impact, HUGE, wraps
                if let artist = entry.musicArtist {
                    Text(artist.uppercased())
                        .font(.custom("Impact", size: 28))
                        .foregroundStyle(Color.black)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Track name
                if let title = entry.linkTitle, !title.isEmpty {
                    Text(title.uppercased())
                        .font(.custom("Impact", size: 13))
                        .foregroundStyle(Color.black.opacity(0.8))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Album name
                if let album = entry.musicAlbum, !album.isEmpty {
                    Text(album.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.6))
                        .kerning(0.8)
                        .lineLimit(1)
                }

                // Thin rule
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(height: 1)

                // Date + note
                HStack {
                    Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day().year()).uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.6))
                        .kerning(0.5)
                    Spacer()
                    if !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(entry.text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.6))
                            .lineLimit(1)
                            .kerning(0.5)
                    }
                }
            }
            .padding(10)
            .background(flyerColor)

            // Paper texture overlay
            GeometryReader { geo in
                Image("paper_texture")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .blendMode(.multiply)
                    .opacity(0.40)
                    .clipped()
                    .allowsHitTesting(false)
            }
        }
        .frame(width: cardWidth)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shadow(color: .black.opacity(0.25), radius: 6, x: 2, y: 4)
        .rotationEffect(.degrees(rotation))
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}
