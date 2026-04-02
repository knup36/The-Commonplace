// VideoPlayerView.swift
// Commonplace
//
// UIViewRepresentable wrapper around AVPlayerLayer.
// Uses resizeAspectFill to eliminate black bars on vertical video.
// Fills the given frame completely while maintaining aspect ratio.

import SwiftUI
import AVFoundation

struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }

    class PlayerUIView: UIView {
        private var playerLayer = AVPlayerLayer()

        var player: AVPlayer? {
            get { playerLayer.player }
            set { playerLayer.player = newValue }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            playerLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) not implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}
