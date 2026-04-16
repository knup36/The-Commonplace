// PodcastService.swift
// Commonplace
//
// Handles podcast search via the iTunes Search API.
// Used by MediaDetailView to search for podcasts and populate .media entries.
//
// iTunes Search API is free, requires no authentication, and returns
// podcast metadata including title, publisher, artwork, genre, and website.
//
// API reference: https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI
// Base URL: https://itunes.apple.com/search

import Foundation

// MARK: - Podcast Search Result

struct PodcastSearchResult: Identifiable {
    let id: Int                  // iTunes trackId
    let title: String            // collectionName
    let publisher: String        // artistName
    let genre: String            // primaryGenreName
    let artworkURL: URL?         // artworkUrl100
    let feedURL: String?         // feedUrl
    let websiteURL: String?      // collectionViewUrl

    /// Thumbnail artwork URL — used in search results list
    var thumbnailURL: URL? { artworkURL }

    /// Full size artwork — replace 100x100 with 600x600
    var fullArtworkURL: URL? {
        guard let url = artworkURL else { return nil }
        return URL(string: url.absoluteString.replacingOccurrences(of: "100x100", with: "600x600"))
    }
}

// MARK: - Service

struct PodcastService {

    private static let baseURL = "https://itunes.apple.com/search"

    // MARK: - Search

    /// Search for podcasts matching the given query string.
    /// Returns up to 10 results sorted by iTunes relevance.
    static func search(query: String) async throws -> [PodcastSearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)?term=\(encoded)&media=podcast&entity=podcast&limit=10"

        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let results = json?["results"] as? [[String: Any]] ?? []

        return results.compactMap { item in
            guard let id = item["collectionId"] as? Int else { return nil }

            let title = item["collectionName"] as? String ?? "Unknown"
            let publisher = item["artistName"] as? String ?? ""
            let genre = item["primaryGenreName"] as? String ?? ""
            let feedURL = item["feedUrl"] as? String
            let websiteURL = item["collectionViewUrl"] as? String

            let artworkURL: URL?
            if let artworkString = item["artworkUrl100"] as? String {
                artworkURL = URL(string: artworkString)
            } else {
                artworkURL = nil
            }

            return PodcastSearchResult(
                id: id,
                title: title,
                publisher: publisher,
                genre: genre,
                artworkURL: artworkURL,
                feedURL: feedURL,
                websiteURL: websiteURL
            )
        }
    }

    // MARK: - Download Artwork

    /// Downloads artwork data from a PodcastSearchResult fullArtworkURL.
    /// Returns nil if no artwork is available or the download fails.
    static func downloadArtwork(from url: URL) async -> Data? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            AppLogger.warning("Podcast artwork download failed for \(url.lastPathComponent)", domain: .api)
            return nil
        }
    }
}
