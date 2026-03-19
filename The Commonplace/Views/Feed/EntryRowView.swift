import SwiftUI

// MARK: - EntryRowView
// Feed card for all entry types.
// Displays type-specific content, tags, metadata, and favorite indicator.
// Used in FeedView, CollectionDetailView, TagFeedView, and TodayView.
// Screen: Feed, Collections, Tags, Today tabs

struct EntryRowView: View {
    let entry: Entry
    @EnvironmentObject var themeManager: ThemeManager
    
    var style: any AppThemeStyle { themeManager.style }
    
    // MARK: - Sub-views
    
    @ViewBuilder
    var typeLabel: some View {
        if style.usesSerifFonts {
            HStack(spacing: 5) {
                Circle()
                    .fill(entry.type.accentColor)
                    .frame(width: 5, height: 5)
                Text(entry.type.displayName.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .kerning(0.8)
                    .foregroundStyle(entry.type.accentColor)
            }
        }
    }
    
    var metadataColumn: some View {
        HStack(spacing: 6) {
            Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(entry.type.accentColor.opacity(0.5))
            Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(entry.type.accentColor.opacity(0.5))
            if !style.usesSerifFonts {
                ZStack {
                    Circle()
                        .fill(entry.type.accentColor.opacity(0.1))
                        .frame(width: 22, height: 22)
                    Image(systemName: entry.type.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(entry.type.accentColor.opacity(0.7))
                }
            }
        }
        .fixedSize()
    }
    
    @ViewBuilder
    var cardContent: some View {
        switch entry.type {
        case .photo:
            VStack(alignment: .leading, spacing: 8) {
                if let path = entry.imagePath,
                   let imageData = MediaFileManager.load(path: path) {
                    AnimatedImageView(data: imageData, isAnimated: AnimatedImageView.isGIF(data: imageData), crop: false)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if !entry.text.isEmpty {
                    noteText(italic: false)
                }
            }
        case .link:
            VStack(alignment: .leading, spacing: 6) {
                LinkPreviewView(entry: entry)
                if !entry.text.isEmpty {
                    noteText(italic: true)
                }
            }
        case .location:
            VStack(alignment: .leading, spacing: 6) {
                LocationRowView(entry: entry)
                if !entry.text.isEmpty {
                    noteText(italic: true)
                }
            }
        case .journal:
            DailyNoteRowView(entry: entry)
        case .sticky:
            StickyEntryView(entry: entry, isPreview: true)
        case .audio:
            let displayText = entry.text.isEmpty ? (entry.transcript ?? "") : entry.text
            if !displayText.isEmpty {
                Text(displayText)
                    .font(style.body)
                    .lineLimit(4)
                    .foregroundStyle(style.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .text:
            if !entry.text.isEmpty {
                Text(entry.text)
                    .font(style.body)
                    .lineLimit(4)
                    .foregroundStyle(style.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .music:
            MusicEntryView(entry: entry)
        }
    }
    
    func noteText(italic: Bool) -> some View {
        Text(entry.text)
            .font(style.body)
            .italic(italic)
            .lineLimit(4)
            .foregroundStyle(style.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    var tagsRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(alignment: .center) {
                if entry.isFavorited {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(style.accent)
                }
                if !entry.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(entry.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .italic(style.usesSerifFonts)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(entry.type.accentColor.opacity(0.15))
                                .foregroundStyle(entry.type.accentColor.opacity(0.9))
                                .clipShape(Capsule())
                                .overlay(
                                    style.usesSerifFonts
                                    ? Capsule().strokeBorder(entry.type.accentColor.opacity(0.3), lineWidth: 0.5)
                                    : nil
                                )
                        }
                        if entry.tags.count > 3 {
                            Text("+\(entry.tags.count - 3)")
                                .font(.caption)
                                .foregroundStyle(style.secondaryText)
                        }
                    }
                }
                Spacer()
            }
            metadataColumn
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .topLeading) {
                    cardContent
                        .padding(.top, entry.type == .journal ? 0 : 18)
                    if entry.isPinned {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(style.accent.opacity(0.5))
                            .padding(.top, -13)
                    }
                }
                typeLabel
            }
            Divider()
                .overlay(style.usesSerifFonts ? InkwellTheme.cardBorderTop : Color(uiColor: .separator))
                .opacity(style.usesSerifFonts ? 0.6 : 1)
            tagsRow
        }
        .padding(12)
        .background(entry.type.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: style.usesSerifFonts ? 14 : 12))
        .overlay(
            style.usesSerifFonts
            ? RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [InkwellTheme.cardBorderTop, InkwellTheme.cardBorderColor(for: entry.type)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
            : nil
        )
        .shadow(color: style.usesSerifFonts ? Color.black.opacity(0.4) : Color.clear, radius: 6, x: 0, y: 3)
    }
}
