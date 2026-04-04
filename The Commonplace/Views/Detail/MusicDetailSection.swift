// MusicDetailSection.swift
// Commonplace
//
// Displays the music section within EntryDetailView.
// Shown when entry.type == .music.
//
// Handles two states:
//   1. No URL yet — shows a text field to paste an Apple Music link
//   2. URL exists — shows MusicEntryView, fetch status, and Open in Apple Music button
//
// Auto-saves URL when an Apple Music link is detected while typing.
// Fetches metadata via iTunes Search API including trackId for full playback.
//
// Key change from previous version:
//   Now saves entry.musicTrackID from iTunes API trackId field,
//   enabling full Apple Music playback via MusicPlayerService.
//
// Screen: Entry Detail (tap any music entry in the Feed or Collections tab)

import SwiftUI
import LinkPresentation

struct MusicDetailSection: View {
    @Bindable var entry: Entry
    var style: any AppThemeStyle
    var accentColor: Color

    @State private var linkURLText = ""
    @State private var isExtracting = false
    @FocusState private var linkFieldFocused: Bool

    var body: some View {
        Group {
            if entry.type == .music {
                if entry.url == nil || entry.url?.isEmpty == true {
                    TextField("Paste Apple Music link...", text: $linkURLText)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($linkFieldFocused)
                        .padding(12)
                        .background(style.cardDivider)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .onChange(of: linkURLText) { _, newValue in
                            if newValue.contains("music.apple.com") {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    if linkURLText == newValue { saveMusicURL() }
                                }
                            }
                        }
                } else {
                    MusicEntryView(entry: entry)
                    if let urlString = entry.url, let url = URL(string: urlString) {
                        if isExtracting {
                                                    HStack(spacing: 6) {
                                                        ProgressView()
                                                        Text("Fetching music info...")
                                                            .font(style.typeCaption)
                                                            .foregroundStyle(style.cardSecondaryText)
                                                    }
                                                } else if entry.linkTitle != nil {
                                                    Label("Music info saved", systemImage: "checkmark.circle.fill")
                                                        .font(style.typeCaption)
                                                        .foregroundStyle(style.cardSecondaryText)
                                                }
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Label("Open in Apple Music", systemImage: "music.note")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accentColor)
                    }
                }
            }
        }
        .onAppear {
            if entry.type == .music && entry.url != nil && entry.linkTitle == nil {
                isExtracting = true
                Task {
                    await fetchMusicMetadata(urlString: entry.url)
                    isExtracting = false
                }
            }
        }
    }

    // MARK: - Save URL

    func saveMusicURL() {
        guard !linkURLText.isEmpty else { return }
        let urlString = linkURLText.hasPrefix("http") ? linkURLText : "https://\(linkURLText)"
        entry.url = urlString
        linkFieldFocused = false
        isExtracting = true
        Task {
            await fetchMusicMetadata(urlString: urlString)
            isExtracting = false
        }
    }

    // MARK: - Fetch Metadata

    /// Fetches song metadata from iTunes Search API and saves to entry.
    /// Saves trackId as musicTrackID for full Apple Music playback via MusicPlayerService.
    func fetchMusicMetadata(urlString: String?) async {
        guard let urlString else { return }

        let fetcher = await LinkPreviewFetcher()
        await fetcher.fetch(urlString: urlString)
        if let metadata = await fetcher.metadata {
            await MainActor.run { entry.linkTitle = metadata.title }
        }

        guard let searchTerm = entry.linkTitle?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let apiURL = URL(string: "https://itunes.apple.com/search?term=\(searchTerm)&limit=1&entity=song")
        else { return }

        guard let (apiData, _) = try? await URLSession.shared.data(from: apiURL),
              let json = try? JSONSerialization.jsonObject(with: apiData) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let first = results.first
        else { return }

        await MainActor.run {
            entry.musicArtist = first["artistName"] as? String
            entry.musicAlbum = first["collectionName"] as? String
            entry.previewURL = first["previewUrl"] as? String

            // Save Apple Music track ID for full playback via MusicPlayerService
            if let trackID = first["trackId"] as? Int {
                entry.musicTrackID = String(trackID)
            }
        }

        // Fetch and save artwork
        if let artworkURLString = first["artworkUrl100"] as? String {
            let hdArtworkURL = artworkURLString.replacingOccurrences(of: "100x100bb", with: "600x600bb")
            if let artworkURL = URL(string: hdArtworkURL),
               let (artworkData, _) = try? await URLSession.shared.data(from: artworkURL) {
                await MainActor.run {
                    entry.musicArtworkPath = try? MediaFileManager.save(
                        artworkData,
                        type: .image,
                        id: "\(entry.id.uuidString)_artwork"
                    )
                }
            }
        }
    }
}
