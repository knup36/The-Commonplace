import SwiftUI

struct AudioPlayerView: View {
    let audioData: Data
    @StateObject private var player = AudioPlayerService()

    var body: some View {
        VStack(spacing: 12) {

            // Progress bar
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }
                    ),
                    in: 0...max(player.duration, 1)
                )
                .tint(.orange)

                // Time labels
                HStack {
                    Text(formatTime(player.currentTime))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatTime(player.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            // Play/pause button
            Button {
                player.togglePlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
            }
            .disabled(!player.isReady)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            player.load(data: audioData)
        }
        .onDisappear {
            player.stop()
        }
    }

    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
