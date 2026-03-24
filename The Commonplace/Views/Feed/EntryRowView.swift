// EntryRowView.swift
// Commonplace
//
// Feed card for all entry types.
// Displays type-specific content, tags, metadata, and favorite indicator.
// Used in FeedView, CollectionDetailView, TagFeedView, and TodayView.
// Screen: Feed, Collections, Tags, Today tabs
//
// Performance notes:
//   - drawingGroup() flattens the entire card into a single Metal layer,
//     eliminating per-frame redraw cost during scrolling
//   - Photo images are loaded asynchronously via AsyncMediaImage to avoid
//     blocking the main thread with disk reads during scroll
//   - Shadows are only rendered on the Inkwell theme (style.usesSerifFonts)

import SwiftUI

// MARK: - ShimmerView
// Animated placeholder shown while an image loads from disk.
// Uses a sliding gradient to create a left-to-right shimmer effect.

struct ShimmerView: View {
    @State private var phase: CGFloat = -1
    
    var body: some View {
        GeometryReader { geo in
            let gradient = LinearGradient(
                colors: [
                    Color.gray.opacity(0.15),
                    Color.gray.opacity(0.30),
                    Color.gray.opacity(0.15)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            Rectangle()
                .fill(gradient)
                .frame(width: geo.size.width * 3)
                .offset(x: phase * geo.size.width * 3)
                .onAppear {
                    withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
        .clipped()
    }
}

// MARK: - AsyncMediaImage
// Loads a media file from disk on a background thread and displays it.
// Shows a shimmer placeholder while loading, then cross-fades to the image.
// Handles both static images and GIFs via AnimatedImageView.

struct AsyncMediaImage: View {
    let path: String
    
    @State private var imageData: Data? = nil
    @State private var isLoaded = false
    
    var body: some View {
        Group {
            if let data = imageData {
                AnimatedImageView(
                    data: data,
                    isAnimated: AnimatedImageView.isGIF(data: data),
                    crop: false
                )
                .opacity(isLoaded ? 1 : 0)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.2)) {
                        isLoaded = true
                    }
                }
            } else {
                ShimmerView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            }
        }
        .task {
            guard imageData == nil else { return }
            
            // Check cache first — avoids disk read if already loaded recently
            if let cached = ImageCache.shared.get(path: path) {
                imageData = cached
                return
            }
            
            // Not in cache — load from disk on background thread
            let loaded = await Task.detached(priority: .userInitiated) {
                MediaFileManager.load(path: path)
            }.value
            
            // Store in cache for next time
            if let loaded {
                ImageCache.shared.set(path: path, data: loaded)
            }
            
            await MainActor.run {
                imageData = loaded
            }
        }
    }
}

// MARK: - EntryRowView

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
                    Text(typeLabelText.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .kerning(0.8)
                        .foregroundStyle(entry.type.accentColor)
                }
            }
        }

        var typeLabelText: String {
            if entry.type == .media {
                switch entry.mediaType {
                case "movie": return "Movie"
                case "tv":    return "TV Show"
                default:      return "Media"
                }
            }
            return entry.type.displayName
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
                if let path = entry.imagePath {
                    AsyncMediaImage(path: path)
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
        case .media:
            HStack(spacing: 10) {
                // Poster thumbnail
                if let path = entry.mediaCoverPath,
                   let data = MediaFileManager.load(path: path),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 75)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(entry.type.accentColor.opacity(0.2))
                        .frame(width: 50, height: 75)
                        .overlay(
                            Image(systemName: "film.fill")
                                .foregroundStyle(entry.type.accentColor)
                        )
                }
                // Title + metadata
                VStack(alignment: .leading, spacing: 4) {
                    if let title = entry.mediaTitle {
                        Text(title)
                            .font(style.usesSerifFonts ? .system(.body, design: .serif) : .body)
                            .fontWeight(.medium)
                            .foregroundStyle(style.primaryText)
                            .lineLimit(2)
                    }
                    HStack(spacing: 6) {
                        if let year = entry.mediaYear, !year.isEmpty {
                            Text(year)
                                .font(.caption)
                                .foregroundStyle(style.secondaryText)
                        }
                        if let genre = entry.mediaGenre, !genre.isEmpty {
                            Text("· \(genre)")
                                .font(.caption)
                                .foregroundStyle(style.secondaryText)
                        }
                        if let runtime = entry.mediaRuntime, entry.mediaType == "movie" {
                            let hours = runtime / 60
                            let mins = runtime % 60
                            let label = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
                            Text("· \(label)")
                                .font(.caption)
                                .foregroundStyle(style.secondaryText)
                        }
                        if let seasons = entry.mediaSeasons, entry.mediaType == "tv" {
                            Text("· \(seasons) \(seasons == 1 ? "Season" : "Seasons")")
                                .font(.caption)
                                .foregroundStyle(style.secondaryText)
                        }
                    }
                }
                Spacer()
            }
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
                if !entry.tagNames.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(entry.tagNames.prefix(3), id: \.self) { tag in
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
                        if entry.tagNames.count > 3 {
                            Text("+\(entry.tagNames.count - 3)")
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
                    .frame(maxWidth: .infinity, alignment: .trailing)
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
