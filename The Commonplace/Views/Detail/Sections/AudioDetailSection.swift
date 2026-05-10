// AudioDetailSection.swift
// Commonplace
//
// Displays the audio section within EntryDetailView.
// Shown when entry.type == .audio.
//
// Handles two states:
//   1. No audio recorded yet — shows AudioEntryView (record/import UI)
//   2. Audio exists — shows AudioPlayerView + transcript
//
// Title and body are split from entry.text using \n delimiter,
// matching the same pattern as note entries. EntryDetailView owns
// the audioTitle/audioBody state and passes title as a Binding here.
//
// Screen: Entry Detail (tap any audio entry in the Feed or Collections tab)

import SwiftUI

struct AudioDetailSection: View {
    @Bindable var entry: Entry
    var style: any AppThemeStyle
    var accentColor: Color
    @Binding var audioTitle: String
    var onTitleChange: (String) -> Void
    
    @EnvironmentObject var editMode: EditModeManager
    
    var body: some View {
        if entry.type == .audio {
            if entry.audioPath == nil {
                if editMode.isEditing {
                    AudioEntryView(
                        audioPath: Binding(get: { entry.audioPath }, set: { entry.audioPath = $0 }),
                        transcript: Binding(get: { entry.transcript ?? "" }, set: { entry.transcript = $0.isEmpty ? nil : $0 }),
                        style: style,
                        accentColor: accentColor
                    )
                    .onChange(of: entry.audioPath) { _, newValue in
                        if newValue != nil { entry.touch() }
                    }
                }
            }
            
            if let path = entry.audioPath,
               let audioData = MediaFileManager.load(path: path) {
                AudioPlayerView(
                    audioData: audioData,
                    style: style,
                    accentColor: accentColor,
                    titleText: audioTitle,
                    onTitleChange: onTitleChange
                )
                
                if let transcript = entry.transcript, !transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Transcript", systemImage: "text.bubble")
                            .font(style.typeCaption)
                            .foregroundStyle(style.cardSecondaryText)
                        Text(transcript)
                            .font(style.typeBody)
                            .foregroundStyle(style.cardPrimaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(style.cardDivider)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if editMode.isEditing {
                    Label("No transcript available", systemImage: "text.bubble")
                        .font(style.typeCaption)
                        .foregroundStyle(style.cardSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(style.cardDivider)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}
