// AudioPlayerView.swift
// Commonplace
//
// Player UI for audio (Sound) entries in EntryDetailView.
// Shows an editable title field (edit mode only), scrub bar,
// time labels, and a play/pause button within a themed card.
//
// Title is passed in as a value + change callback from AudioDetailSection,
// which receives it as a Binding from EntryDetailView. This keeps the
// title/body split logic owned by EntryDetailView, matching the note pattern.
//
// Updated v2.4 — theme-aware colors, title field, improved card styling,
//               title/body separation via \n split pattern.

import SwiftUI

struct AudioPlayerView: View {
    let audioData: Data
    var style: any AppThemeStyle
    var accentColor: Color
    var titleText: String
    var onTitleChange: ((String) -> Void)?

    @StateObject private var player = AudioPlayerService()
    @EnvironmentObject var editMode: EditModeManager

    @State private var localTitle: String = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // MARK: - Title
            if editMode.isEditing {
                CommonplaceTextEditor(
                    text: $localTitle,
                    placeholder: "Untitled recording",
                    usesSerifFont: true,
                    fontSize: 34,
                    fontWeight: .black,
                    minHeight: 44
                )
                .focused($titleFocused)
                .foregroundStyle(style.cardPrimaryText)
                .onChange(of: localTitle) { _, newValue in
                    onTitleChange?(newValue)
                }
            } else if !titleText.isEmpty {
                Text(titleText)
                    .font(AppTypeScale.largeTitle)
                    .foregroundStyle(style.cardPrimaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // MARK: - Player card
            VStack(spacing: 16) {

                // Scrub bar
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { player.currentTime },
                            set: { player.seek(to: $0) }
                        ),
                        in: 0...max(player.duration, 1)
                    )
                    .tint(accentColor)
                    .padding(.horizontal, 4)

                    HStack {
                        Text(formatTime(player.currentTime))
                            .font(AppTypeScale.mono)
                            .foregroundStyle(style.cardSecondaryText)
                        Spacer()
                        Text(formatTime(player.duration))
                            .font(AppTypeScale.mono)
                            .foregroundStyle(style.cardSecondaryText)
                    }
                    .padding(.horizontal, 4)
                }

                // Play/pause button
                Button {
                    player.togglePlayback()
                } label: {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.18))
                            .frame(width: 60, height: 60)
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(accentColor)
                    }
                }
                .disabled(!player.isReady)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(accentColor.opacity(0.25), lineWidth: 0.5)
            )
            .shadow(color: accentColor.opacity(0.15), radius: 8, x: 0, y: 3)
            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
        }
        .onAppear {
                    player.load(data: audioData)
                    localTitle = titleText
                }
                .onChange(of: titleText) { _, newValue in
                    if localTitle != newValue {
                        localTitle = newValue
                    }
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
