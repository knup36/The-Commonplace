// ShotRowView.swift
// Commonplace
//
// Feed card for Shot (.photo) entries that contain a video clip.
// Shows the video thumbnail with a play button overlay.
// Photo-only Shot entries continue to use regularBody in EntryRowView.
//
// Tapping the card navigates to the detail view where VideoPlayer plays inline.

import SwiftUI

struct ShotRowView: View {
    let entry: Entry
    @EnvironmentObject var themeManager: ThemeManager

    var style: any AppThemeStyle { themeManager.style }
    var accentColor: Color { entry.type.accentColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Type label — Inkwell only
            if style.usesSerifFonts {
                HStack {
                    Spacer()
                    HStack(spacing: 5) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 5, height: 5)
                        HStack(spacing: 0) {
                            Text("SHOT")
                                .font(.system(size: 9, weight: .medium))
                                .kerning(0.8)
                                .foregroundStyle(accentColor)
                            Text(" · VIDEO")
                                .font(.system(size: 9, weight: .medium))
                                .kerning(0.8)
                                .foregroundStyle(accentColor.opacity(0.5))
                        }
                    }
                }
            }

            // Thumbnail with play overlay
            ZStack {
                if let thumbPath = entry.videoThumbnailPath,
                   let data = MediaFileManager.load(path: thumbPath),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(0.1))
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                }

                // Play button overlay
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.45))
                        .frame(width: 48, height: 48)
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .offset(x: 2)
                }

                // Duration badge
                if let duration = entry.videoDuration {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(formatDuration(duration))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.55))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .padding(8)
                        }
                    }
                }
            }

            // Note text
            if !entry.text.isEmpty {
                Text(entry.text)
                    .font(style.body)
                    .foregroundStyle(style.primaryText)
                    .lineLimit(2)
            }

            Divider()
                .overlay(style.usesSerifFonts
                    ? InkwellTheme.cardBorderTop
                    : Color(uiColor: .separator))
                .opacity(style.usesSerifFonts ? 0.6 : 1)

            // Tags + metadata row
            HStack {
                let visibleTags = entry.tagNames.filter { !$0.hasPrefix("@") }
                if !visibleTags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(visibleTags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .italic(style.usesSerifFonts)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(accentColor.opacity(0.15))
                                .foregroundStyle(accentColor.opacity(0.9))
                                .clipShape(Capsule())
                        }
                        if visibleTags.count > 3 {
                            Text("+\(visibleTags.count - 3)")
                                .font(.caption)
                                .foregroundStyle(style.secondaryText)
                        }
                    }
                }
                Spacer()
                HStack(spacing: 6) {
                    Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(accentColor.opacity(0.5))
                    Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(accentColor.opacity(0.5))
                }
            }
        }
        .padding(12)
        .background(entry.type.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: style.usesSerifFonts ? 14 : 12))
        .overlay(
            style.usesSerifFonts
            ? RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [InkwellTheme.cardBorderTop,
                                 InkwellTheme.cardBorderColor(for: entry.type)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
            : nil
        )
        .shadow(color: style.usesSerifFonts
            ? Color.black.opacity(0.4)
            : Color.clear,
            radius: 6, x: 0, y: 3)
    }

    func formatDuration(_ duration: Double) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
