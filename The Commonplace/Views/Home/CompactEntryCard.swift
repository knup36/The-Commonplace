// CompactEntryCard.swift
// Commonplace
//
// Compact card view for entries shown in HomeDashboardView.
// Wider than tall (160×120pts) — landscape orientation like Shortcuts app.
// Shows just enough content to identify the entry at a glance.
// Tapping navigates to the full entry detail view.
//
// Card content per entry type:
//   .text     — first 2-3 lines of text
//   .photo    — thumbnail image filling card
//   .audio    — waveform icon + play indicator
//   .link     — favicon + link title
//   .journal  — date of journal entry
//   .location — location name + category icon
//   .sticky   — list title + X/X progress
//   .music    — album artwork + music note icon
//
// Background color uses entry.type.accentColor at low opacity,
// consistent with the feed card design language.

import SwiftUI

struct CompactEntryCard: View {
    let entry: Entry
    var style: any AppThemeStyle
    @EnvironmentObject var themeManager: ThemeManager
    
    var entryAccent: Color { entry.type.detailAccentColor(for: themeManager.current) }
    var entryCard: Color { entry.type.cardColor(for: themeManager.current) }
    
    private let cardWidth: CGFloat = 160
    private let cardHeight: CGFloat = 80
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background — hidden for photo and music which use full bleed images
            if entry.type != .photo && entry.type != .music && entry.type != .media {
                RoundedRectangle(cornerRadius: 14)
                    .fill(entryCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(style.cardBorder, lineWidth: 0.5)
                    )
            }
            
            // Content
            if entry.type == .photo || entry.type == .music || entry.type == .media {
                cardContent
            } else {
                cardContent
                    .padding(12)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        
    }
    
    @ViewBuilder
    var cardContent: some View {
        switch entry.type {
        case .text:
            textCard
        case .photo:
            photoCard
        case .audio:
            audioCard
        case .link:
            linkCard
        case .journal:
            journalCard
        case .location:
            locationCard
        case .sticky:
            stickyCard
        case .music:
            musicCard
        case .media:
            mediaCard
        }
    }
    
    // MARK: - Text Card
    
    var textCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.text.isEmpty ? "Empty note" : entry.text)
                .font(style.typeCaption)
                .foregroundStyle(style.cardPrimaryText)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Photo Card
    
    var photoCard: some View {
        Group {
            if let path = entry.imagePath,
               let data = MediaFileManager.load(path: path),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 80)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(entryAccent)
                    if !entry.text.isEmpty {
                        Text(entry.text)
                            .font(style.typeCaption)
                            .foregroundStyle(style.cardSecondaryText)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Audio Card
    
    var audioCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "waveform")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(entryAccent)
            Spacer()
            Image(systemName: "play.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(entryAccent)
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer()
            if let transcript = entry.transcript, !transcript.isEmpty {
                Text(transcript)
                    .font(style.typeCaption)
                    .foregroundStyle(style.cardSecondaryText)
                    .lineLimit(2)
            }
        }
    }
    
    // MARK: - Link Card
    
    var linkCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let faviconPath = entry.faviconPath,
                   let data = MediaFileManager.load(path: faviconPath),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 12, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(entryAccent)
                }
            }
            Spacer()
            Text(entry.linkTitle ?? entry.url ?? "Link")
                .font(style.typeCaption)
                .fontWeight(.medium)
                .foregroundStyle(style.cardPrimaryText)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Journal Card
    
    var journalCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                if !entry.weatherEmoji.isEmpty { Text(entry.weatherEmoji).font(.body) }
                if !entry.moodEmoji.isEmpty { Text(entry.moodEmoji).font(.body) }
                if !entry.vibeEmoji.isEmpty { Text(entry.vibeEmoji).font(.body) }
            }
            Spacer()
            Text(entry.createdAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(style.typeCaption)
                .fontWeight(.medium)
                .foregroundStyle(style.cardPrimaryText)
        }
    }
    
    // MARK: - Location Card
    
    var locationCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.locationName ?? "Unknown Location")
                .font(style.typeCaption)
                .fontWeight(.medium)
                .foregroundStyle(style.cardPrimaryText)
                .lineLimit(1)
            if let address = entry.locationAddress {
                Text(address)
                    .font(style.typeCaption)
                    .foregroundStyle(style.cardSecondaryText)
                    .lineLimit(2)
            }
        }
    }
    
    // MARK: - Sticky Card
    
    var stickyCard: some View {
        let total = entry.stickyItems.count
        let checked = entry.stickyChecked.count
        
        return VStack(alignment: .leading, spacing: 4) {
            if let title = entry.stickyTitle, !title.isEmpty {
                Text(title)
                    .font(style.typeCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(style.cardPrimaryText)
                    .lineLimit(2)
            }
            Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(style.typeCaption)
                .foregroundStyle(style.cardMetadataText)
                .padding(.bottom,7)
            if total > 0 {
                HStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(entryAccent.opacity(0.2))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(entryAccent)
                                .frame(width: total > 0 ? geo.size.width * CGFloat(checked) / CGFloat(total) : 0)
                        }
                    }
                    .frame(height: 4)
                    Text("\(checked)/\(total)")
                        .font(style.typeCaption)
                        .foregroundStyle(style.cardSecondaryText)
                        .fixedSize()
                }
            }
        }
    }
    
    // MARK: - Music Card
    
    var musicCard: some View {
        ZStack(alignment: .bottomLeading) {
            if let artworkPath = entry.musicArtworkPath,
               let data = MediaFileManager.load(path: artworkPath),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 80)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.text.isEmpty ? (entry.musicAlbum ?? "Music") : entry.text)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let artist = entry.musicArtist {
                        Text(artist)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                .padding(10)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "music.note")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(entryAccent)
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(entryAccent)
                    Spacer()
                    if let album = entry.musicAlbum {
                        Text(album)
                            .font(style.typeCaption)
                            .foregroundStyle(style.cardSecondaryText)
                            .lineLimit(1)
                    }
                }
                .padding(12)
            }
        }
    }
    // MARK: - Media Card
    
    var mediaCard: some View {
        ZStack(alignment: .bottomLeading) {
            if let coverPath = entry.mediaCoverPath,
               let data = MediaFileManager.load(path: coverPath),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 80)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    )
                if let title = entry.mediaTitle {
                    Text(title)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .padding(10)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "film.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(entryAccent)
                    Spacer()
                    Text(entry.mediaTitle ?? "Media")
                        .font(style.typeCaption)
                        .fontWeight(.medium)
                        .foregroundStyle(style.cardPrimaryText)
                        .lineLimit(2)
                }
            }
        }
    }
}
