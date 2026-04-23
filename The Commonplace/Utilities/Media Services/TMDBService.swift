// TMDBService.swift
// Commonplace
//
// Handles all communication with The Movie Database (TMDB) API.
// Used by MediaSearchView to search for movies and TV shows and fetch full metadata.
//
// Two main operations:
//   1. search(query:type:)     — returns a list of results matching a title string
//   2. fetchDetails(id:type:)  — returns full metadata for a single selected result
//
// Poster images are not downloaded here — posterPath is returned as a relative path
// and downloaded separately by MediaSearchView when saving the entry.
//
// API reference: https://developer.themoviedb.org/docs
// Authentication: Bearer token (Read Access Token) passed in Authorization header

import Foundation

// MARK: - Media Subtype

enum TMDBMediaType: String {
    case movie = "movie"
    case tv    = "tv"

    var displayName: String {
        switch self {
        case .movie: return "Movie"
        case .tv:    return "TV Show"
        }
    }
}

// MARK: - Search Result

struct TMDBSearchResult: Identifiable {
    let id: Int
    let title: String
    let year: String
    let overview: String
    let posterPath: String?
    let mediaType: TMDBMediaType

    /// Full poster URL at w342 size — good balance of quality and download speed
    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }

    /// Thumbnail poster URL at w92 size — used in search results list
    var thumbnailURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w92\(path)")
    }
}

// MARK: - Full Detail

struct TMDBDetail {
    let id: Int
    let title: String
    let year: String
    let overview: String
    let genres: [String]
    let posterPath: String?
    let mediaType: TMDBMediaType
    let runtime: Int?
    let seasons: Int?

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }
}

// MARK: - Service

struct TMDBService {

    private static let token = "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIwNjdjYjQyNzZlMzViMWZkNmI1NjdmMGZhZDc4MDBmMiIsIm5iZiI6MTc3NDI3NzcyNC43NDcsInN1YiI6IjY5YzE1NDVjZTkyMGJhOTdjZWEyNTlmOSIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.lOXgWm6KKOBSlNRsVZIWqtShqpqjpX9T2e4QdxMIK_Q"

    private static let baseURL = "https://api.themoviedb.org/3"

    // MARK: - Search

    /// Search for movies or TV shows matching the given query string.
    /// Returns up to 10 results sorted by TMDB popularity.
    static func search(query: String, type: TMDBMediaType) async throws -> [TMDBSearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)/search/\(type.rawValue)?query=\(encoded)&page=1&include_adult=false"

        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let results = json?["results"] as? [[String: Any]] ?? []

        return results.prefix(10).compactMap { item in
            guard let id = item["id"] as? Int else { return nil }

            let title: String
            let rawDate: String
            if type == .movie {
                title = item["title"] as? String ?? "Unknown"
                rawDate = item["release_date"] as? String ?? ""
            } else {
                title = item["name"] as? String ?? "Unknown"
                rawDate = item["first_air_date"] as? String ?? ""
            }

            let year = String(rawDate.prefix(4))
            let overview = item["overview"] as? String ?? ""
            let posterPath = item["poster_path"] as? String

            return TMDBSearchResult(
                id: id,
                title: title,
                year: year,
                overview: overview,
                posterPath: posterPath,
                mediaType: type
            )
        }
    }

    // MARK: - Fetch Detail

    /// Fetch full metadata for a single movie or TV show by its TMDB ID.
    /// Includes genres which are not available in search results.
    static func fetchDetail(id: Int, type: TMDBMediaType) async throws -> TMDBDetail? {
        let urlString = "\(baseURL)/\(type.rawValue)/\(id)"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let item = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let item else { return nil }
        
        let title: String
        let rawDate: String
        if type == .movie {
            title = item["title"] as? String ?? "Unknown"
            rawDate = item["release_date"] as? String ?? ""
        } else {
            title = item["name"] as? String ?? "Unknown"
            rawDate = item["first_air_date"] as? String ?? ""
        }

        let year = String(rawDate.prefix(4))
        let overview = item["overview"] as? String ?? ""
        let posterPath = item["poster_path"] as? String
        let genreObjects = item["genres"] as? [[String: Any]] ?? []
        let genres = genreObjects.compactMap { $0["name"] as? String }
        
        let runtime = item["runtime"] as? Int
        let seasons = item["number_of_seasons"] as? Int
        
        return TMDBDetail(
            id: id,
            title: title,
            year: year,
            overview: overview,
            genres: genres,
            posterPath: posterPath,
            mediaType: type,
            runtime: runtime,
            seasons: seasons
        )
    }

    // MARK: - Download Poster

    /// Downloads poster image data from a TMDBSearchResult or TMDBDetail posterURL.
    /// Returns nil if no poster is available or the download fails.
    static func downloadPoster(from url: URL) async -> Data? {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                return data
            } catch {
                AppLogger.warning("Poster download failed for \(url.lastPathComponent)", domain: .api)
                return nil
            }
        }
}
