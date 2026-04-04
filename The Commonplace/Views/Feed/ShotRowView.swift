// ShotRowView.swift
// Commonplace
//
// Feed card for Shot (.photo) entries that contain a video clip.
// Shows the video thumbnail with a play button overlay.
// Photo-only Shot entries continue to use regularBody in EntryRowView.
//
// Updated v1.13 — theme-aware colors via themeManager.current

import SwiftUI

struct ShotRowView: View {
    let entry: Entry
    @EnvironmentObject var themeManager: ThemeManager
    
    var style: any AppThemeStyle { themeManager.style }
    var accentColor: Color { entry.type.accentColor(for: themeManager.current) }
    var cardColor: Color { entry.type.cardColor(for: themeManager.current) }
    var labelColor: Color { entry.type.detailAccentColor(for: themeManager.current) }
    var dimLabelColor: Color { labelColor.opacity(0.5) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // Type label
            if style.showsEntryTypeLabel {
                HStack {
                    Spacer()
                    HStack(spacing: 5) {
                        Circle()
                            .fill(dimLabelColor)
                            .frame(width: 5, height: 5)
                        HStack(spacing: 0) {
                            NYLabel("SHOT", color: UIColor(dimLabelColor))
                                .fixedSize()
                            NYLabel(" · VIDEO", color: UIColor(dimLabelColor).withAlphaComponent(0.5))
                                .fixedSize()
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
                        .fill(style.cardDivider)
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                }
                
                // Play button
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
                                .font(style.typeMono)
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
                    .font(style.typeBody)
                    .foregroundStyle(style.cardPrimaryText)
                    .lineLimit(2)
            }
            
            Divider()
                .overlay(style.cardDivider)
            
            // Tags + metadata row
            HStack {
                let visibleTags = entry.tagNames.filter { !$0.hasPrefix("@") }
                if !visibleTags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(visibleTags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(style.typeCaption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(labelColor.opacity(0.2))
                                .foregroundStyle(labelColor)
                                .clipShape(Capsule())
                        }
                        if visibleTags.count > 3 {
                            Text("+\(visibleTags.count - 3)")
                                .font(style.typeCaption)
                                .foregroundStyle(style.cardMetadataText)
                        }
                    }
                }
                Spacer()
                HStack(spacing: 6) {
                    Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(style.typeCaption)
                        .foregroundStyle(style.cardMetadataText)
                    Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(style.typeCaption)
                        .foregroundStyle(style.cardMetadataText)
                }
            }
        }
        .padding(12)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style.cardBorder, lineWidth: 0.5)
        )
    }
    
    func formatDuration(_ duration: Double) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
