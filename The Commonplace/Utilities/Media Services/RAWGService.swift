// RAWGService.swift
// Commonplace
//
// Handles game search via the RAWG Video Games Database API.
// Used by MediaDetailView to search for games and populate .media entries.
//
// RAWG API is free with an API key (sign up at rawg.io).
// Returns game metadata including title, cover art, release year,
// genres, platforms, and developer/publisher.
//
// API reference: https://rawg.io/apidocs

import Foundation

// MARK: - Game Search Result

struct RAWGSearchResult: Identifiable {
    let id: Int                     // RAWG game ID
    let title: String               // name
    let year: String                // released (first 4 chars)
    let genre: String               // genres[0].name
    let platforms: String           // joined platform names
    let backgroundImageURL: URL?    // background_image
    let developer: String           // developers[0].name (from detail fetch)
    let publisher: String           // publishers[0].name (from detail fetch)

    var thumbnailURL: URL? { backgroundImageURL }
    var fullImageURL: URL? { backgroundImageURL }
}

// MARK: - Service

struct RAWGService {

    private static let apiKey = "393b645348eb49be8a545256601b7c16"
    private static let baseURL = "https://api.rawg.io/api"

    // MARK: - Search

    /// Search for games matching the given query string.
    /// Returns up to 10 results sorted by RAWG relevance.
    static func search(query: String) async throws -> [RAWGSearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)/games?key=\(apiKey)&search=\(encoded)&page_size=10"

        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let results = json?["results"] as? [[String: Any]] ?? []

        return results.compactMap { item in
            guard let id = item["id"] as? Int else { return nil }

            let title = item["name"] as? String ?? "Unknown"
            let released = item["released"] as? String ?? ""
            let year = String(released.prefix(4))

            let genreObjects = item["genres"] as? [[String: Any]] ?? []
            let genre = genreObjects.first?["name"] as? String ?? ""

            let platformObjects = item["platforms"] as? [[String: Any]] ?? []
            let platforms = platformObjects.compactMap {
                ($0["platform"] as? [String: Any])?["name"] as? String
            }.joined(separator: ", ")

            let imageURLString = item["background_image"] as? String
            let backgroundImageURL = imageURLString.flatMap { URL(string: $0) }

            return RAWGSearchResult(
                id: id,
                title: title,
                year: year,
                genre: genre,
                platforms: platforms,
                backgroundImageURL: backgroundImageURL,
                developer: "",
                publisher: ""
            )
        }
    }

    // MARK: - Fetch Detail

    /// Fetch full metadata for a single game by its RAWG ID.
    /// Includes developers and publishers not available in search results.
    static func fetchDetail(id: Int) async throws -> RAWGSearchResult? {
        let urlString = "\(baseURL)/games/\(id)?key=\(apiKey)"
        guard let url = URL(string: urlString) else { return nil }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let item = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let title = item["name"] as? String ?? "Unknown"
        let released = item["released"] as? String ?? ""
        let year = String(released.prefix(4))

        let genreObjects = item["genres"] as? [[String: Any]] ?? []
        let genre = genreObjects.first?["name"] as? String ?? ""

        let platformObjects = item["platforms"] as? [[String: Any]] ?? []
        let platforms = platformObjects.compactMap {
            ($0["platform"] as? [String: Any])?["name"] as? String
        }.joined(separator: ", ")

        let imageURLString = item["background_image"] as? String
        let backgroundImageURL = imageURLString.flatMap { URL(string: $0) }

        let developerObjects = item["developers"] as? [[String: Any]] ?? []
        let developer = developerObjects.first?["name"] as? String ?? ""

        let publisherObjects = item["publishers"] as? [[String: Any]] ?? []
        let publisher = publisherObjects.first?["name"] as? String ?? ""

        return RAWGSearchResult(
            id: id,
            title: title,
            year: year,
            genre: genre,
            platforms: platforms,
            backgroundImageURL: backgroundImageURL,
            developer: developer,
            publisher: publisher
        )
    }

    // MARK: - Download Artwork

    /// Downloads cover art from a RAWGSearchResult backgroundImageURL.
    /// Returns nil if no image is available or the download fails.
    static func downloadArtwork(from url: URL) async -> Data? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            AppLogger.warning("RAWG artwork download failed for \(url.lastPathComponent)", domain: .api)
            return nil
        }
    }
}
