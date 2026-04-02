// SoundPlayerService.swift
// Commonplace
//
// Singleton audio player service for Sound entries.
// Persists playback across scrolling and navigation using
// AVAudioSession .playback category.
//
// Any view can observe this service to show playback state.
// MiniSoundPlayerBar observes it to show/hide the persistent bar.
// Only one sound plays at a time — loading new audio stops current.

import Foundation
import AVFoundation
import Combine

@MainActor
class SoundPlayerService: ObservableObject {
    static let shared = SoundPlayerService()

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isReady = false
    @Published var currentEntryID: UUID? = nil
    @Published var currentTitle: String? = nil

    private var player: AVAudioPlayer?
    private var timer: Timer?

    private init() {}

    // MARK: - Load

    func load(data: Data, entryID: UUID, title: String?) {
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(data: data)
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            currentTime = 0
            currentEntryID = entryID
            currentTitle = title
            isReady = true
        } catch {
            print("SoundPlayerService: load error \(error)")
        }
    }

    // MARK: - Playback

    func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            stopTimer()
        } else {
            player.play()
            startTimer()
        }
        isPlaying.toggle()
    }

    func play() {
        guard let player, !isPlaying else { return }
        player.play()
        startTimer()
        isPlaying = true
    }

    func pause() {
        guard let player, isPlaying else { return }
        player.pause()
        stopTimer()
        isPlaying = false
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        currentTime = 0
        isPlaying = false
        isReady = false
        currentEntryID = nil
        currentTitle = nil
        stopTimer()
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    // MARK: - Formatted Time

    func formattedTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
                if !player.isPlaying {
                    self.isPlaying = false
                    self.currentTime = 0
                    self.stopTimer()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
