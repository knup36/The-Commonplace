// SoundRowView.swift
// Commonplace
//
// Feed card for Sound (.audio) entries.
// Shows an animated waveform, duration, play button,
// optional note text, and tags.
// Tapping the play button loads and plays via SoundPlayerService.
// Waveform animates while this entry is playing.
//
// Updated v1.13 — fully theme-aware, no hardcoded Inkwell references.

import SwiftUI
import SwiftData

struct SoundRowView: View {
    let entry: Entry
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var player = SoundPlayerService.shared
    @Query var allPersonTags: [Tag]
    @Query var allCollections: [Collection]
    
    var style: any AppThemeStyle { themeManager.style }
    var accentColor: Color { entry.type.accentColor(for: themeManager.current) }
    var cardColor: Color { entry.type.cardColor(for: themeManager.current) }
    var labelColor: Color { entry.type.detailAccentColor(for: themeManager.current) }
    var dimLabelColor: Color { labelColor.opacity(0.5) }
    
    var isThisEntryPlaying: Bool {
        player.currentEntryID == entry.id && player.isPlaying
    }
    
    var isThisEntryActive: Bool {
        player.currentEntryID == entry.id && player.isReady
    }
    
    var isThisEntryLoaded: Bool {
        player.currentEntryID == entry.id
    }
    
    var durationText: String {
        if isThisEntryLoaded {
            return player.formattedTime(
                isThisEntryPlaying ? player.currentTime : player.duration
            )
        }
        if let duration = entry.duration {
            let mins = Int(duration) / 60
            let secs = Int(duration) % 60
            return String(format: "%d:%02d", mins, secs)
        }
        return ""
    }
    
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
                        NYLabel("SOUND", color: UIColor(dimLabelColor))
                            .fixedSize()
                    }
                }
            }
            
            // Waveform row
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 8) {
                    SoundWaveformView(
                        entryID: entry.id,
                        accentColor: labelColor,
                        isPlaying: isThisEntryActive && isThisEntryPlaying,
                        barCount: 10
                    )
                    .fixedSize()
                    
                    if !durationText.isEmpty {
                        Text(durationText)
                            .font(style.typeMono)
                            .foregroundStyle(style.cardSecondaryText)
                    }
                }
                
                Spacer()
                
                Button {
                    handlePlayTap()
                } label: {
                    ZStack {
                        Circle()
                            .fill(style.cardDivider)
                            .frame(width: 40, height: 40)
                        Image(systemName: isThisEntryPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(labelColor)
                            .offset(x: isThisEntryPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)
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
            
            // Tags row
            HStack(alignment: .bottom, spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
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
                                    let folioCollection = allCollections.first { $0.isFolio && $0.filterTags.contains(tag) && $0.filterTags.count == 1 }
                                    if let folio = folioCollection {
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
                    }
                }
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
    
    // MARK: - Play Handler
    
    func handlePlayTap() {
        if isThisEntryLoaded {
            player.togglePlayback()
        } else {
            guard let path = entry.audioPath,
                  let data = MediaFileManager.load(path: path) else { return }
            player.load(
                data: data,
                entryID: entry.id,
                title: entry.text.isEmpty ? "Sound" : entry.text
            )
            player.play()
        }
    }
}
