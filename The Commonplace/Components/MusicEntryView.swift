import SwiftUI
import AVFoundation

struct MusicEntryView: View {
    let entry: Entry
    @EnvironmentObject var themeManager: ThemeManager
    @State private var player: AVPlayer? = nil
    @State private var isPlaying = false
    @State private var progress: Double = 1.0
    @State private var playbackTimer: Timer? = nil
    private let previewDuration: Double = 30.0
    
    var isInkwell: Bool { themeManager.current == .inkwell }
    var accentColor: Color { isInkwell ? InkwellTheme.accentColor(for: .music) : .red }
    
    var body: some View {
        HStack(spacing: 12) {
            artworkThumbnail
            infoStack
            Spacer()
            if entry.previewURL != nil {
                playButton
            }
        }
    }
    
    // MARK: - Artwork
    
    var artworkThumbnail: some View {
        Group {
            if let path = entry.mediaArtworkPath,
               let data = MediaFileManager.load(path: path),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isInkwell ? InkwellTheme.cardBorderTop.opacity(0.3) : Color.clear, lineWidth: 0.5)
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
                    .font(isInkwell ? .system(.subheadline, design: .serif) : .subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isInkwell ? InkwellTheme.inkPrimary : .primary)
                    .lineLimit(2)
            }
            if let artist = entry.mediaArtist, !artist.isEmpty {
                Text(artist)
                    .font(isInkwell ? .system(.caption, design: .serif) : .caption)
                    .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
                    .lineLimit(1)
            }
            if let album = entry.mediaAlbum, !album.isEmpty {
                Text(album)
                    .font(isInkwell ? .system(.caption, design: .serif) : .caption)
                    .foregroundStyle(isInkwell ? InkwellTheme.inkTertiary : Color(uiColor: .tertiaryLabel))
                    .lineLimit(1)
            }
            if !entry.text.isEmpty {
                Text(entry.text)
                    .font(isInkwell ? .system(.caption, design: .serif) : .caption)
                    .italic()
                    .lineLimit(2)
                    .foregroundStyle(isInkwell ? InkwellTheme.inkTertiary : .secondary)
            }
        }
    }
    
    // MARK: - Play Button
    
    var playButton: some View {
        Button {
            togglePlayback()
        } label: {
            ZStack {
                // Background circle
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                // Countdown ring
                if isPlaying {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90)) // start from top
                        .animation(.linear(duration: 0.1), value: progress)
                }
                
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(accentColor)
                    .offset(x: isPlaying ? 0 : 1)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Playback
    
    func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AVAudioSession configuration failed: \(error)")
        }
    }
    
    func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            if let urlString = entry.previewURL, let url = URL(string: urlString) {
                configureAudioSession()
                if player == nil {
                    player = AVPlayer(url: url)
                }
                player?.play()
                isPlaying = true
                progress = 1.0
                startCountdown()
            }
        }
    }
    
    func startCountdown() {
        playbackTimer?.invalidate()
        let interval = 0.1
        var elapsed = 0.0
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            elapsed += interval
            progress = max(0, 1.0 - (elapsed / previewDuration))
            if elapsed >= previewDuration {
                stopPlayback()
            }
        }
    }
    
    func stopPlayback() {
        player?.pause()
        isPlaying = false
        progress = 1.0
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
}
