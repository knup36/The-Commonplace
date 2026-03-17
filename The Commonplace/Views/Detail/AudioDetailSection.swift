import SwiftUI

// MARK: - AudioDetailSection
// Displays the audio section within EntryDetailView.
// Shown when entry.type == .audio.
// Handles two states:
//   1. No audio recorded yet — shows AudioEntryView (record/import UI)
//   2. Audio exists — shows AudioPlayerView + transcript (or "no transcript" message)
// Screen: Entry Detail (tap any audio entry in the Feed or Collections tab)

struct AudioDetailSection: View {
    @Bindable var entry: Entry
    var style: any AppThemeStyle
    var accentColor: Color

    var body: some View {
        if entry.type == .audio {
            if entry.audioPath == nil {
                AudioEntryView(
                    audioPath: Binding(get: { entry.audioPath }, set: { entry.audioPath = $0 }),
                    transcript: Binding(get: { entry.transcript ?? "" }, set: { entry.transcript = $0.isEmpty ? nil : $0 })
                )
            }
            if let path = entry.audioPath,
               let audioData = MediaFileManager.load(path: path) {
                AudioPlayerView(audioData: audioData)
                if let transcript = entry.transcript, !transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Transcript", systemImage: "text.bubble")
                            .font(.caption)
                            .foregroundStyle(style.secondaryText)
                        Text(transcript)
                            .font(style.body)
                            .foregroundStyle(style.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Label("No transcript available", systemImage: "text.bubble")
                        .font(.caption)
                        .foregroundStyle(style.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(accentColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}
