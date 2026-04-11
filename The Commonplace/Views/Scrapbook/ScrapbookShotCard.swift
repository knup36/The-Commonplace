// ScrapbookShotCard.swift
// Commonplace
//
// Scrapbook feed card for .photo (Shot) entries.
// Renders as a physical Polaroid — white border, thicker chin,
// tape strip at top, slight rotation seeded from entry UUID.
//
// Layout:
//   - Tape strip centered at top
//   - Photo filling the card (square crop)
//   - White Polaroid border — equal sides, thicker bottom chin
//   - Caption/note text in the chin area, handwritten-style serif
//   - Date below caption in small caps
//
// Rotation range: -5 to +5 degrees, deterministic per entry.
// No image = placeholder with camera icon.

import SwiftUI

struct ScrapbookShotCard: View {
    let entry: Entry

    private let polaroidWidth: CGFloat = 240
    private let borderWidth: CGFloat = 12
    private let chinHeight: CGFloat = 56

    /// Deterministic rotation seeded from entry UUID
    var rotation: Double {
        let hash = abs(entry.id.uuidString.hashValue)
        let normalized = Double(hash % 1000) / 100.0  // 0.0 to 10.0
        return normalized - 5.0  // -5.0 to +5.0 degrees
    }

    var photoSize: CGFloat {
        polaroidWidth - (borderWidth * 2)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Polaroid card
            VStack(spacing: 0) {
                // Photo area
                ZStack {
                    if let path = entry.imagePath,
                       let data = MediaFileManager.load(path: path),
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: photoSize, height: photoSize)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(ScrapbookTheme.inkDecorative.opacity(0.15))
                            .frame(width: photoSize, height: photoSize)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(ScrapbookTheme.inkTertiary)
                            )
                    }
                }
                .frame(width: photoSize, height: photoSize)

                // Chin area
                VStack(spacing: 4) {
                    if !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(entry.text)
                            .font(ScrapbookTheme.bodyFont(size: 13))
                            .italic()
                            .foregroundStyle(ScrapbookTheme.inkSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(ScrapbookTheme.captionFont(size: 9))
                        .kerning(0.8)
                        .foregroundStyle(ScrapbookTheme.inkTertiary)
                }
                .frame(width: photoSize, height: chinHeight)
                .padding(.horizontal, 8)
            }
            .padding(borderWidth)
            .background(ScrapbookTheme.polaroidWhite)
            .clipShape(RoundedRectangle(cornerRadius: ScrapbookTheme.cardCornerRadius))
            .shadow(color: ScrapbookTheme.cardShadowColor, radius: ScrapbookTheme.cardShadowRadius, x: 0, y: ScrapbookTheme.cardShadowY)

            // Tape strip
            RoundedRectangle(cornerRadius: 2)
                .fill(ScrapbookTheme.tapeColor)
                .frame(width: 52, height: 18)
                .offset(y: -9)
        }
        .rotationEffect(.degrees(rotation))
        .padding(.vertical, 24)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}
