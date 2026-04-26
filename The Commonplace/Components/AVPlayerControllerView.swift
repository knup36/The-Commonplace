// AVPlayerControllerView.swift
// Commonplace
//
// Full-featured video player with native controls for Attachment entries.
// Wraps AVPlayerViewController as a proper child view controller to support
// full screen transitions, scrubbing, and rotation without interruption.
//
// Distinct from VideoPlayerView which is a bare AVPlayerLayer used by
// Shot entries that implement their own custom playback controls.

import SwiftUI
import AVKit

struct AVPlayerControllerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}
}
