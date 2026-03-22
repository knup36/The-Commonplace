// MusicPlayerService.swift
// Commonplace
//
// Singleton service for full Apple Music playback via ApplicationMusicPlayer.
// Requires MusicKit capability and Apple Music subscription.
//
// Responsibilities:
//   - Request MusicKit authorization on first use
//   - Play full tracks via ApplicationMusicPlayer using Apple Music track ID
//   - Fall back to 30-second preview via AVPlayer if not authorized or no track ID
//   - Expose playback state (isPlaying, currentEntryID) for UI updates
//
// Usage:
//   await MusicPlayerService.shared.play(entry: entry)
//   MusicPlayerService.shared.stop()
//
// Architecture note:
//   ApplicationMusicPlayer plays through the system music player —
//   appears on Dynamic Island, lock screen, and Control Center automatically.
//   No mini-player needed in Commonplace.

import SwiftUI
import Combine
import MusicKit
import AVFoundation

@MainActor
class MusicPlayerService: ObservableObject {
    static let shared = MusicPlayerService()

    @Published var isPlaying = false
    @Published var currentEntryID: UUID? = nil
    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined

    private var previewPlayer: AVPlayer? = nil
    private var previewTimer: Timer? = nil

    private init() {
        Task {
            await checkAuthorization()
        }
    }

    // MARK: - Authorization

    func checkAuthorization() async {
        authorizationStatus = await MusicAuthorization.currentStatus
    }

    func requestAuthorization() async {
        authorizationStatus = await MusicAuthorization.request()
    }

    // MARK: - Playback

    /// Play a music entry — uses full Apple Music playback if authorized and track ID exists,
    /// falls back to 30-second preview via AVPlayer otherwise.
    func play(entry: Entry) async {
        // Stop any current playback first
        stop()

        // Notify other music views to stop
        NotificationCenter.default.post(name: .musicPlaybackStarted, object: entry.id)

        currentEntryID = entry.id

        // Try full Apple Music playback first
        if authorizationStatus == .authorized, let trackIDString = entry.musicTrackID {
            await playFullTrack(trackID: trackIDString, entry: entry)
        } else if authorizationStatus == .notDetermined {
            // Request authorization and try again
            await requestAuthorization()
            if authorizationStatus == .authorized, let trackIDString = entry.musicTrackID {
                await playFullTrack(trackID: trackIDString, entry: entry)
            } else {
                playPreview(entry: entry)
            }
        } else {
            // Not authorized or no track ID — fall back to preview
            playPreview(entry: entry)
        }
    }

    /// Play full track via ApplicationMusicPlayer
    private func playFullTrack(trackID: String, entry: Entry) async {
        do {
            let musicID = MusicItemID(trackID)
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: musicID)
            let response = try await request.response()

            guard let song = response.items.first else {
                print("MusicPlayerService: song not found for ID \(trackID), falling back to preview")
                playPreview(entry: entry)
                return
            }

            ApplicationMusicPlayer.shared.queue = [song]
            try await ApplicationMusicPlayer.shared.play()
            isPlaying = true
            print("MusicPlayerService: playing full track — \(song.title)")
        } catch {
            print("MusicPlayerService: full playback failed — \(error), falling back to preview")
            playPreview(entry: entry)
        }
    }

    /// Fall back to 30-second preview via AVPlayer
    private func playPreview(entry: Entry) {
        guard let urlString = entry.previewURL, let url = URL(string: urlString) else {
            print("MusicPlayerService: no preview URL available")
            isPlaying = false
            currentEntryID = nil
            return
        }

        configureAudioSession()
        previewPlayer = AVPlayer(url: url)
        previewPlayer?.play()
        isPlaying = true

        // Auto-stop after 30 seconds
        previewTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stop()
            }
        }
        print("MusicPlayerService: playing 30-second preview")
    }

    // MARK: - Stop

    func stop() {
        // Stop full track player
        ApplicationMusicPlayer.shared.stop()

        // Stop preview player
        previewPlayer?.pause()
        previewPlayer = nil
        previewTimer?.invalidate()
        previewTimer = nil

        isPlaying = false
        currentEntryID = nil
    }

    func toggle(entry: Entry) async {
        if isPlaying && currentEntryID == entry.id {
            stop()
        } else {
            await play(entry: entry)
        }
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("MusicPlayerService: AVAudioSession configuration failed — \(error)")
        }
    }
}
