// MusicEntryView.swift
// Commonplace
//
// Feed card and detail view for music entries.
// Displays album artwork, track title, artist, album, and play button.
//
// Playback:
//   Uses MusicPlayerService.shared which handles full Apple Music playback
//   via ApplicationMusicPlayer when authorized and track ID is available,
//   falling back to 30-second AVPlayer preview otherwise.
//
//   Playback appears on Dynamic Island, lock screen, and Control Center
//   automatically — no mini-player needed in Commonplace.
//
// The countdown ring is only shown during preview playback (30 sec).
// During full Apple Music playback the ring is hidden since duration is unknown.
//
// Screen: Feed cards and Entry Detail for music entries.

import SwiftUI
import AVFoundation
import MusicKit

struct MusicEntryView: View {
    let entry: Entry
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var musicService = MusicPlayerService.shared
    
    // Preview-specific state (only used when falling back to AVPlayer)
    @State private var progress: Double = 1.0
    @State private var previewTimer: Timer? = nil
    private let previewDuration: Double = 30.0
    
    var style: any AppThemeStyle { themeManager.style }
    var accentColor: Color { EntryType.music.detailAccentColor(for: themeManager.current) }
    
    var isCurrentlyPlaying: Bool {
        musicService.isPlaying && musicService.currentEntryID == entry.id
    }
    
    var hasFullPlayback: Bool {
        entry.musicTrackID != nil && musicService.authorizationStatus == .authorized
    }
    
    var body: some View {
        HStack(spacing: 12) {
            artworkThumbnail
            infoStack
            Spacer()
            if entry.previewURL != nil || entry.musicTrackID != nil {
                playButton
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .musicPlaybackStarted)) { notification in
            if let id = notification.object as? UUID, id != entry.id {
                // Another entry started playing — reset our progress ring
                progress = 1.0
                previewTimer?.invalidate()
                previewTimer = nil
            }
        }
    }
    
    // MARK: - Artwork
    
    var artworkThumbnail: some View {
        Group {
            if let path = entry.musicArtworkPath,
               let data = MediaFileManager.load(path: path),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(style.cardBorder, lineWidth: 0.5)
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 24))
                            .foregroundStyle(accentColor.opacity(0.5))
                    )
            }
        }
    }
    
    // MARK: - Info
    
    var infoStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = entry.linkTitle, !title.isEmpty {
                Text(title)
                    .font(style.typeBodySecondary)
                    .fontWeight(.semibold)
                    .foregroundStyle(style.cardPrimaryText)
                    .lineLimit(2)
            }
            if let artist = entry.musicArtist, !artist.isEmpty {
                Text(artist)
                    .font(style.typeCaption)
                    .foregroundStyle(style.cardSecondaryText)
                    .lineLimit(1)
            }
            if let album = entry.musicAlbum, !album.isEmpty {
                Text(album)
                    .font(style.typeCaption)
                    .foregroundStyle(style.cardMetadataText)
                    .lineLimit(1)
            }
        }
    }
    
    // MARK: - Play Button
    
    var playButton: some View {
        Button {
            Task {
                await musicService.toggle(entry: entry)
                if isCurrentlyPlaying && !hasFullPlayback {
                    startPreviewCountdown()
                } else {
                    progress = 1.0
                    previewTimer?.invalidate()
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                // Only show countdown ring for preview playback
                if isCurrentlyPlaying && !hasFullPlayback {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: progress)
                }
                
                Image(systemName: isCurrentlyPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(accentColor)
                    .offset(x: isCurrentlyPlaying ? 0 : 1)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Preview Countdown (fallback only)
    
    func startPreviewCountdown() {
        previewTimer?.invalidate()
        let interval = 0.1
        var elapsed = 0.0
        progress = 1.0
        previewTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            elapsed += interval
            progress = max(0, 1.0 - (elapsed / previewDuration))
            if elapsed >= previewDuration {
                timer.invalidate()
                previewTimer = nil
                progress = 1.0
            }
        }
    }
}
