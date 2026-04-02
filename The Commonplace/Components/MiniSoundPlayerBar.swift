// MiniSoundPlayerBar.swift
// Commonplace
//
// Persistent mini player bar shown above the tab bar when a
// sound entry is playing or paused via SoundPlayerService.
// Disappears when playback is stopped entirely.
//
// Shows: waveform animation, title, current time, play/pause, stop.

import SwiftUI

struct MiniSoundPlayerBar: View {
    @ObservedObject var player = SoundPlayerService.shared
    @EnvironmentObject var themeManager: ThemeManager

    var style: any AppThemeStyle { themeManager.style }
    var accentColor: Color { EntryType.audio.accentColor }

    var body: some View {
        if player.isReady {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Waveform
                    if let id = player.currentEntryID {
                        SoundWaveformView(
                            entryID: id,
                            accentColor: accentColor,
                            isPlaying: player.isPlaying,
                            barCount: 10,
                            height: 20
                        )
                        .frame(width: 60)
                    }

                    // Title + time
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.currentTitle ?? "Sound")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(style.primaryText)
                            .lineLimit(1)
                        Text(player.formattedTime(player.currentTime) + " / " + player.formattedTime(player.duration))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(style.tertiaryText)
                    }

                    Spacer()

                    // Play/Pause
                    Button {
                        player.togglePlayback()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(accentColor)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)

                    // Stop
                    Button {
                        withAnimation(.easeOut(duration: 0.3)) {
                            player.stop()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(style.secondaryText)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(style.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, 16)
                }
                .transition(.opacity)
                .animation(.spring(response: 0.3), value: player.isReady)
        }
    }
}
