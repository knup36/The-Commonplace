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

struct SoundRowView: View {
    let entry: Entry
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var player = SoundPlayerService.shared
    
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
