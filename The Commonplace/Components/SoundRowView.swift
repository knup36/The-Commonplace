// SoundRowView.swift
// Commonplace
//
// Feed card for Sound (.audio) entries.
// Shows an animated waveform, duration, play button,
// optional note text, and tags.
// Tapping the play button loads and plays via SoundPlayerService.
// Waveform animates while this entry is playing.

import SwiftUI

struct SoundRowView: View {
    let entry: Entry
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var player = SoundPlayerService.shared

    var style: any AppThemeStyle { themeManager.style }
    var accentColor: Color { entry.type.accentColor }

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
            // Type label — Inkwell only
            if style.usesSerifFonts {
                HStack {
                    Spacer()
                    HStack(spacing: 5) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 5, height: 5)
                        Text("SOUND")
                            .font(.system(size: 9, weight: .medium))
                            .kerning(0.8)
                            .foregroundStyle(accentColor)
                    }
                }
            }

            // Waveform row
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 8) {
                    SoundWaveformView(
                        entryID: entry.id,
                        accentColor: accentColor,
                        isPlaying: isThisEntryActive && isThisEntryPlaying,
                        barCount: 10
                    )
                    .fixedSize()

                    if !durationText.isEmpty {
                        Text(durationText)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(accentColor.opacity(0.7))
                    }
                }

                Spacer()

                Button {
                    handlePlayTap()
                } label: {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: isThisEntryPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(accentColor)
                            .offset(x: isThisEntryPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)
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

            // Tags row
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
