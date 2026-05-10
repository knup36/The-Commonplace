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
    
    @EnvironmentObject var editMode: EditModeManager
    @State private var linkURLText = ""
    @State private var isExtracting = false
    @FocusState private var linkFieldFocused: Bool
    
    var body: some View {
        Group {
            if entry.type == .music {
                if entry.url == nil || entry.url?.isEmpty == true {
                    if editMode.isEditing {
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
                    }
                } else {
                    VStack(spacing: 16) {
                        // Large centered artwork
                        Group {
                            if let path = entry.musicArtworkPath,
                               let data = MediaFileManager.load(path: path),
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 192, height: 192)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: accentColor.opacity(0.3), radius: 16, x: 0, y: 8)
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(accentColor.opacity(0.15))
                                    .frame(width: 192, height: 192)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 48))
                                            .foregroundStyle(accentColor.opacity(0.5))
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        // Track info — centered
                        VStack(spacing: 6) {
                            if let title = entry.linkTitle, !title.isEmpty {
                                Text(title)
                                    .font(style.typeTitle1)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(style.cardPrimaryText)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            if let artist = entry.musicArtist, !artist.isEmpty {
                                Text(artist)
                                    .font(style.typeBody)
                                    .foregroundStyle(style.cardSecondaryText)
                                    .multilineTextAlignment(.center)
                            }
                            if let album = entry.musicAlbum, !album.isEmpty {
                                Text(album)
                                    .font(style.typeBodySecondary)
                                    .foregroundStyle(style.cardMetadataText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        // Buttons row — play + Apple Music
                        if let urlString = entry.url, let url = URL(string: urlString) {
                            HStack(spacing: 24) {
                                // Play button
                                if entry.previewURL != nil || entry.musicTrackID != nil {
                                    MusicPlayButton(entry: entry, accentColor: accentColor, size: 52)
                                }
                                
                                // Apple Music button
                                Button {
                                    UIApplication.shared.open(url)
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(accentColor.opacity(0.15))
                                            .frame(width: 52, height: 52)
                                        Image(systemName: "apple.logo")
                                            .font(.system(size: 22, weight: .medium))
                                            .foregroundStyle(accentColor)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        
                        // Fetch status
                        if isExtracting {
                            HStack(spacing: 6) {
                                ProgressView()
                                Text("Fetching music info...")
                                    .font(style.typeCaption)
                                    .foregroundStyle(style.cardSecondaryText)
                            }
                        }
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
        entry.touch()
        linkFieldFocused = false
        isExtracting = true
        Task {
            await fetchMusicMetadata(urlString: urlString)
            isExtracting = false
        }
    }
    
    // MARK: - Fetch Metadata
    
    /// Extracts the iTunes track ID from an Apple Music URL.
    /// Apple Music URLs contain the track ID in the `?i=` parameter.
    /// e.g. https://music.apple.com/us/album/song-name/123456789?i=987654321
    func extractTrackID(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let trackID = components.queryItems?.first(where: { $0.name == "i" })?.value
        else { return nil }
        return trackID
    }
    
    /// Fetches song metadata from iTunes API and saves to entry.
    /// Uses track ID lookup when available (always correct) — falls back to title search.
    func fetchMusicMetadata(urlString: String?) async {
        guard let urlString else { return }
        
        // Try to extract track ID directly from the URL first
        let extractedTrackID = extractTrackID(from: urlString)
        
        // Build API URL — lookup by ID if available, search by title as fallback
        let apiURL: URL?
        if let trackID = extractedTrackID {
            apiURL = URL(string: "https://itunes.apple.com/lookup?id=\(trackID)&entity=song")
        } else {
            // Fallback: fetch title from link preview then search
            let fetcher = await LinkPreviewFetcher()
            await fetcher.fetch(urlString: urlString)
            if let metadata = await fetcher.metadata {
                await MainActor.run { entry.linkTitle = metadata.title }
            }
            guard let searchTerm = entry.linkTitle?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            else { return }
            apiURL = URL(string: "https://itunes.apple.com/search?term=\(searchTerm)&limit=1&entity=song")
        }
        
        guard let apiURL else { return }
        
        do {
            let (apiData, _) = try await URLSession.shared.data(from: apiURL)
            guard let json = try JSONSerialization.jsonObject(with: apiData) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first
            else { return }
            
            await MainActor.run {
                entry.linkTitle = first["trackName"] as? String ?? entry.linkTitle
                entry.musicArtist = first["artistName"] as? String
                entry.musicAlbum = first["collectionName"] as? String
                entry.previewURL = first["previewUrl"] as? String
                
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
        } catch {
            AppLogger.error("iTunes metadata fetch failed", domain: .api, error: error)
        }
    }
}
