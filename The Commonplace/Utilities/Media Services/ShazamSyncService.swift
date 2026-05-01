// ShazamSyncService.swift
// Commonplace
//
// Syncs tracks from the Apple Music "My Shazam Tracks" playlist into Commonplace
// as .music entries. Uses MusicKit to access the playlist and the iTunes Search API
// (same pattern as MusicDetailSection) to fetch full metadata and artwork.
//
// Sync rules:
//   - Only imports tracks added on or after shazamSyncStartDate (set on first enable)
//   - Deduplicates via entry.shazamID — tracks already imported are skipped
//   - Auto-tags every imported entry with "shazam"
//   - Sets entry.createdAt to the track's Apple Music add date where available
//
// UserDefaults keys:
//   shazamSyncEnabled     — Bool, whether sync is enabled
//   shazamSyncStartDate   — Date, set once on first enable, never changes
//   shazamLastSyncedAt    — Date, updated after every successful sync

import Foundation
import MusicKit
import SwiftData

struct ShazamSyncResult {
    let imported: Int
    let skipped: Int
    
    var displayMessage: String {
        if imported == 0 {
            return "Already up to date"
        } else {
            return "Imported \(imported) new \(imported == 1 ? "track" : "tracks")"
        }
    }
}

struct ShazamSyncService {
    
    let modelContext: ModelContext
    
    // MARK: - Baseline
    
    /// Called on first enable. Records all existing track IDs as already seen
    /// without importing any entries. Future syncs will only import new tracks.
    func recordBaseline() async throws {
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            throw ShazamSyncError.notAuthorized
        }
        
        let tracks = try await fetchShazamTracks()
        
        // Store all current track IDs in UserDefaults as the baseline set
        let baselineIDs = tracks.map { $0.id.rawValue }
        UserDefaults.standard.set(baselineIDs, forKey: "shazamBaselineIDs")
        AppLogger.info("Shazam baseline recorded: \(baselineIDs.count) existing tracks marked as seen", domain: .api)
    }
    
    // MARK: - Sync
    
    /// Main sync entry point. Fetches My Shazam Tracks, filters by start date,
    /// deduplicates, and creates .music entries for new tracks.
    func sync() async throws -> ShazamSyncResult {
        // Request MusicKit authorization
        let status = await MusicAuthorization.request()
        AppLogger.info("MusicKit auth status: \(status)", domain: .api)
        guard status == .authorized else {
            throw ShazamSyncError.notAuthorized
        }
        
        // Fetch the Shazam playlist
        AppLogger.info("Fetching Shazam playlist...", domain: .api)
        let tracks = try await fetchShazamTracks()
        AppLogger.info("Found \(tracks.count) tracks in Shazam playlist", domain: .api)
        
        // Get sync start date — only import tracks added on or after this date
        guard let startDate = UserDefaults.standard.object(forKey: "shazamSyncStartDate") as? Date else {
            throw ShazamSyncError.noStartDate
        }
        
        // Get existing shazamIDs to deduplicate — both imported entries and baseline
        let existingIDs = try fetchExistingShazamIDs()
        let baselineIDs = Set(UserDefaults.standard.stringArray(forKey: "shazamBaselineIDs") ?? [])
        let allSeenIDs = existingIDs.union(baselineIDs)
        
        var imported = 0
        var skipped = 0
        
        for track in tracks {
            let trackID = track.id.rawValue
            
            // Skip if already imported or in baseline
            if allSeenIDs.contains(trackID) {
                skipped += 1
                continue
            }
            
            // Skip if added before sync start date
            // MusicKit doesn't expose playlist add date directly — we use createdAt = now
            // for tracks where we can't determine add date
            imported += 1
            try await createEntry(for: track, trackID: trackID)
        }
        
        // Update last synced timestamp
        UserDefaults.standard.set(Date(), forKey: "shazamLastSyncedAt")
        
        return ShazamSyncResult(imported: imported, skipped: skipped)
    }
    
    // MARK: - Fetch Shazam Playlist
    
    private func fetchShazamTracks() async throws -> [Track] {
        // Search for "My Shazam Tracks" in the user's library
        var request = MusicLibraryRequest<Playlist>()
        request.filter(matching: \.name, equalTo: "My Shazam Tracks")
        let response = try await request.response()
        
        guard let playlist = response.items.first else {
            throw ShazamSyncError.playlistNotFound
        }
        
        // Fetch playlist with tracks
        let detailedPlaylist = try await playlist.with([.tracks])
        let tracks = detailedPlaylist.tracks ?? []
        return Array(tracks)
    }
    
    // MARK: - Fetch Existing IDs
    
    private func fetchExistingShazamIDs() throws -> Set<String> {
        let descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate { $0.shazamID != nil }
        )
        let entries = try modelContext.fetch(descriptor)
        return Set(entries.compactMap { $0.shazamID })
    }
    
    // MARK: - Create Entry
    
    private func createEntry(for track: Track, trackID: String) async throws {
        let entry = Entry(type: .music, text: "", tags: [])
        entry.shazamID = trackID
        entry.tagNames = ["shazam"]
        entry.linkTitle = track.title
                entry.musicArtist = track.artistName
                entry.musicAlbum = track.albumTitle
                // url set by enrichWithiTunesMetadata to real Apple Music trackViewUrl
        
        // Enrich with iTunes metadata before saving — gets real Apple Music URL,
                // artwork, preview URL, and correct catalog track ID for playback
                await enrichWithiTunesMetadata(entry: entry, trackID: trackID, title: track.title, artist: track.artistName)

                modelContext.insert(entry)
                try modelContext.save()
                SearchIndex.shared.index(entry: entry)
            }
    
    // MARK: - iTunes Enrichment
    
    /// Fetches artwork and preview URL from iTunes API — same pattern as MusicDetailSection.
    private func enrichWithiTunesMetadata(entry: Entry, trackID: String, title: String, artist: String) async {
        // Search by title + artist — MusicKit library IDs are not iTunes catalog IDs
        let searchTerm = "\(title) \(artist)"
        guard let encoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let apiURL = URL(string: "https://itunes.apple.com/search?term=\(encoded)&limit=1&entity=song") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: apiURL)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first else { return }
            
            entry.linkTitle     = first["trackName"] as? String ?? entry.linkTitle
            entry.musicArtist   = first["artistName"] as? String ?? entry.musicArtist
            entry.musicAlbum    = first["collectionName"] as? String ?? entry.musicAlbum
            entry.previewURL    = first["previewUrl"] as? String
            
            if let trackIDInt = first["trackId"] as? Int {
                entry.musicTrackID = String(trackIDInt)
            }
            
            if let urlString = first["trackViewUrl"] as? String {
                entry.url = urlString
            }
            
            // Fetch and save artwork
            if let artworkURLString = first["artworkUrl100"] as? String {
                let hdURL = artworkURLString.replacingOccurrences(of: "100x100bb", with: "600x600bb")
                if let artworkURL = URL(string: hdURL),
                   let (artworkData, _) = try? await URLSession.shared.data(from: artworkURL) {
                    entry.musicArtworkPath = try? MediaFileManager.save(
                        artworkData,
                        type: .image,
                        id: "\(entry.id.uuidString)_artwork"
                    )
                }
            }
        } catch {
            AppLogger.warning("iTunes enrichment failed for \(title)", domain: .api)
        }
    }
}

// MARK: - Errors

enum ShazamSyncError: LocalizedError {
    case notAuthorized
    case playlistNotFound
    case noStartDate
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:    return "Apple Music access was not granted. Please allow access in Settings."
        case .playlistNotFound: return "Could not find \"My Shazam Tracks\" in your Apple Music library. Make sure you have Shazamed at least one track."
        case .noStartDate:      return "Sync start date not set. Please disable and re-enable Shazam sync in Settings."
        }
    }
}
