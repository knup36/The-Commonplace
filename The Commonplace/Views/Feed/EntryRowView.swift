// EntryRowView.swift
// Commonplace
//
// Feed card for all entry types.
// Displays type-specific content, tags, metadata, and favorite indicator.
// Used in FeedView, CollectionDetailView, TagFeedView, and TodayView.
//
// Updated v1.13 — fully theme-aware, no hardcoded Inkwell references.
// All colors derived from theme system. Shadows removed for Dusk theme.

import SwiftUI
import SwiftData

// MARK: - ShimmerView

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
            if let cached = ImageCache.shared.get(path: path) {
                imageData = cached
                return
            }
            let loaded = await Task.detached(priority: .userInitiated) {
                MediaFileManager.load(path: path)
            }.value
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
    @Query var allTagObjects: [Tag]
    @Query var allPersonTags: [Tag]
    @Query var allCollections: [Collection]
    
    var style: any AppThemeStyle { themeManager.style }
    var accentColor: Color { entry.type.accentColor(for: themeManager.current) }
    var cardColor: Color { entry.type.cardColor(for: themeManager.current) }
    var labelColor: Color { entry.type.detailAccentColor(for: themeManager.current) }
    var dimLabelColor: Color { labelColor.opacity(0.5) }
    
    // MARK: - Type Label
    
    @ViewBuilder
    var typeLabel: some View {
        if style.showsEntryTypeLabel {
            HStack(spacing: 5) {
                Circle()
                    .fill(dimLabelColor)
                    .frame(width: 5, height: 5)
                if entry.type == .link, let contentType = entry.linkContentType {
                    HStack(spacing: 0) {
                        NYLabel("LINK", color: UIColor(dimLabelColor))
                            .fixedSize()
                        NYLabel(" · \(contentType.uppercased())",
                                color: UIColor(dimLabelColor).withAlphaComponent(0.5))
                        .fixedSize()
                    }
                } else if entry.type == .photo {
                    let subtype = entry.videoPath != nil ? "VIDEO" : (entry.isScreenshot ? "SCREENSHOT" : "PHOTO")
                    HStack(spacing: 0) {
                        NYLabel("SHOT", color: UIColor(dimLabelColor))
                            .fixedSize()
                        NYLabel(" · \(subtype)",
                                color: UIColor(dimLabelColor).withAlphaComponent(0.5))
                        .fixedSize()
                    }
                } else {
                    NYLabel(typeLabelText.uppercased(), color: UIColor(dimLabelColor))
                        .fixedSize()
                }
            }
        }
    }
    
    var typeLabelText: String {
        if entry.type == .media {
            switch entry.mediaType {
            case "movie":   return "Movie"
            case "tv":      return "TV Show"
            case "podcast": return "Podcast"
            case "game":    return "Game"
            default:        return "Media"
            }
        }
        if entry.type == .link, let contentType = entry.linkContentType {
            return "Link · \(contentType.capitalized)"
        }
        if entry.type == .photo {
            if entry.videoPath != nil { return "Shot · Video" }
            return entry.isScreenshot ? "Shot · Screenshot" : "Shot · Photo"
        }
        return entry.type.displayName
    }
    
    // MARK: - Metadata Column
    
    var metadataColumn: some View {
        HStack(spacing: 6) {
            Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                .font(style.typeCaption)
                .foregroundStyle(style.cardMetadataText)
            Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(style.typeCaption)
                .foregroundStyle(style.cardMetadataText)
        }
        .fixedSize()
    }
    
    // MARK: - Card Content
    
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
        case .audio:
            let displayText = entry.text.isEmpty ? (entry.transcript ?? "") : entry.text
            if !displayText.isEmpty {
                Text(displayText)
                    .font(style.typeBody)
                    .lineLimit(4)
                    .foregroundStyle(style.cardPrimaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .text:
            if !entry.text.isEmpty {
                let parts = entry.text.components(separatedBy: "\n")
                let titleLine = parts.first ?? entry.text
                let bodyLines = parts.dropFirst().joined(separator: " ")
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleLine)
                        .font(style.typeTitle3)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundStyle(style.cardPrimaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !bodyLines.isEmpty {
                        Text(bodyLines)
                            .font(style.typeBody)
                            .lineLimit(2)
                            .foregroundStyle(style.cardSecondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        case .music:
            MusicEntryView(entry: entry)
        case .media:
            HStack(spacing: 10) {
                let isPodcast = entry.mediaType == "podcast"
                let isGame = entry.mediaType == "game"
                let thumbWidth: CGFloat = 50
                let thumbHeight: CGFloat = isPodcast ? 50 : 75
                let thumbRadius: CGFloat = isPodcast ? 8 : 6
                if let path = entry.mediaCoverPath,
                   let data = MediaFileManager.load(path: path),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: thumbWidth, height: thumbHeight)
                        .clipShape(RoundedRectangle(cornerRadius: thumbRadius))
                } else {
                    RoundedRectangle(cornerRadius: thumbRadius)
                        .fill(style.cardDivider)
                        .frame(width: thumbWidth, height: thumbHeight)
                        .overlay(
                            Image(systemName: isPodcast ? "mic.fill" : isGame ? "gamecontroller.fill" : "film.fill")
                                .foregroundStyle(style.cardSecondaryText)
                        )
                }
                VStack(alignment: .leading, spacing: 4) {
                    if let title = entry.mediaTitle {
                        Text(title)
                            .font(style.typeTitle3)
                            .fontWeight(.medium)
                            .foregroundStyle(style.cardPrimaryText)
                            .lineLimit(2)
                    }
                    HStack(spacing: 6) {
                        if let year = entry.mediaYear, !year.isEmpty {
                            Text(year)
                                .font(style.typeCaption)
                                .foregroundStyle(style.cardSecondaryText)
                        }
                        if let genre = entry.mediaGenre, !genre.isEmpty {
                            Text("· \(genre)")
                                .font(style.typeCaption)
                                .foregroundStyle(style.cardSecondaryText)
                        }
                        if let runtime = entry.mediaRuntime, entry.mediaType == "movie" {
                            let hours = runtime / 60
                            let mins = runtime % 60
                            let label = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
                            Text("· \(label)")
                                .font(style.typeCaption)
                                .foregroundStyle(style.cardSecondaryText)
                        }
                        if let seasons = entry.mediaSeasons, entry.mediaType == "tv" {
                            Text("· \(seasons) \(seasons == 1 ? "Season" : "Seasons")")
                                .font(style.typeCaption)
                                .foregroundStyle(style.cardSecondaryText)
                        }
                    }
                    if let status = entry.mediaStatus {
                        Text(mediaStatusLabel(for: status, mediaType: entry.mediaType).uppercased())
                            .font(.system(size: 8, weight: .semibold))
                            .kerning(0.6)
                            .foregroundStyle(mediaStatusColor(for: status, theme: themeManager.current))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(mediaStatusColor(for: status, theme: themeManager.current).opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
            }
        case .sticky:
            StickyEntryView(entry: entry, isPreview: true)
        }
    }
    
    // MARK: - Note Text
    
    func noteText(italic: Bool) -> some View {
        Text(entry.text)
            .font(style.typeBody)
            .italic(italic)
            .lineLimit(4)
            .foregroundStyle(style.cardSecondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Tags Row
    
    @ViewBuilder
    var tagsRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                // People avatars
                let personTags = entry.tagNames.filter { $0.hasPrefix("@") }
                if !personTags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(personTags.prefix(3), id: \.self) { tag in
                            let name = String(tag.dropFirst())
                            let personTag = allPersonTags.first { $0.name == name && $0.isPerson }
                            ZStack {
                                Circle()
                                    .strokeBorder(SharedTheme.goldRingGradient, lineWidth: 1)
                                    .frame(width: 22, height: 22)
                                if let path = personTag?.profilePhotoPath,
                                   let data = MediaFileManager.load(path: path),
                                   let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 20, height: 20)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(style.personAvatarBackground)
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Text(String(name.prefix(1)).uppercased())
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundStyle(style.personAvatarForeground)
                                        )
                                }
                            }
                        }
                        if personTags.count > 3 {
                            Text("+\(personTags.count - 3)")
                                .font(style.typeCaption)
                                .foregroundStyle(style.cardMetadataText)
                        }
                    }
                }
                // Tag pills
                let visibleTags = entry.tagNames.filter { !$0.hasPrefix("@") }
                if !visibleTags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(visibleTags.prefix(3), id: \.self) { tag in
                            let folioTag = allTagObjects.first { $0.name == tag && $0.isFolio }
                                                        let folioCollection = allCollections.first { $0.isFolio && $0.filterTags.contains(tag) && $0.filterTags.count == 1 }
                            if let folio = folioTag {
                                // Old Tag-based Folio
                                HStack(spacing: 3) {
                                    if let emoji = folio.subjectEmoji {
                                        Text(emoji).font(.system(size: 10))
                                    }
                                    Text(folio.folioDisplayName)
                                        .font(style.typeCaption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: folio.colorHex ?? "#888780").opacity(0.2))
                                .foregroundStyle(style.cardPrimaryText)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().strokeBorder(
                                        LinearGradient(
                                            colors: [Color(white: 0.85), Color(white: 0.6), Color(white: 0.85), Color(white: 0.5), Color(white: 0.85)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                                )
                            } else if let folio = folioCollection {
                                // New Collection-based Folio
                                HStack(spacing: 3) {
                                    if let emoji = folio.folioEmoji {
                                        Text(emoji).font(.system(size: 10))
                                    }
                                    Text(folio.name)
                                        .font(style.typeCaption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: folio.colorHex).opacity(0.2))
                                .foregroundStyle(style.cardPrimaryText)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().strokeBorder(
                                        LinearGradient(
                                            colors: [Color(white: 0.85), Color(white: 0.6), Color(white: 0.85), Color(white: 0.5), Color(white: 0.85)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                                )
                            } else {
                                Text(tag)
                                    .font(style.typeCaption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(labelColor.opacity(0.2))
                                    .foregroundStyle(labelColor)
                                    .clipShape(Capsule())
                            }
                        }
                        if visibleTags.count > 3 {
                            Text("+\(visibleTags.count - 3)")
                                .font(style.typeCaption)
                                .foregroundStyle(style.cardMetadataText)
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
        if entry.tagNames.contains(WeeklyReviewTheme.weeklyReviewTag) {
            WeeklyReviewRowView(entry: entry)
        } else if entry.type == .audio {
            SoundRowView(entry: entry)
        } else if entry.type == .photo && entry.videoPath != nil {
            ShotRowView(entry: entry)
        } else {
            regularBody
        }
    }
    
    var regularBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .topLeading) {
                    cardContent
                        .padding(.top, entry.type == .journal ? 0 : 18)
                    if entry.isPinned {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(style.cardSecondaryText)
                            .padding(.top, -13)
                    }
                }
                typeLabel
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            Divider()
                .overlay(style.cardDivider)
            tagsRow
        }
        .padding(12)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style.cardBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Helpers

func mediaStatusLabel(for status: String, mediaType: String? = nil) -> String {
    if mediaType == "podcast" {
        switch status {
        case "wantTo":     return "Want to Listen"
        case "inProgress": return "Listening"
        case "finished":   return "Finished"
        default:           return status
        }
    }
    if mediaType == "game" {
        switch status {
        case "wantTo":     return "Someday"
        case "inProgress": return "Playing"
        case "finished":   return "Finished"
        default:           return status
        }
    }
    switch status {
    case "wantTo":     return "Want to Watch"
    case "inProgress": return "In Progress"
    case "finished":   return "Finished"
    default:           return status
    }
}

func mediaStatusColor(for status: String, theme: AppTheme) -> Color {
    switch theme {
    case .dusk:
        switch status {
                case "wantTo":     return Color(hex: "#7A5855")
                case "inProgress": return Color(hex: "#877662")
                case "finished":   return Color(hex: "#526349")
                case "rewatch":    return Color(hex: "#4A6070")
                case "replay":     return Color(hex: "#4A6070")
                default:           return Color.white.opacity(0.5)
                }
    default:
        switch status {
                case "wantTo":     return InkwellTheme.mediaAccent
                case "inProgress": return InkwellTheme.stickyAccent
                case "finished":   return InkwellTheme.locationAccent
                case "rewatch":    return InkwellTheme.audioAccent
                case "replay":     return InkwellTheme.audioAccent
                default:           return InkwellTheme.inkSecondary
                }
    }
}
