// OpenLibraryService.swift
// Commonplace
//
// Handles all communication with the OpenLibrary API.
// Used by MediaDetailView to search for books and fetch cover art.
//
// Two main operations:
//   1. search(query:)       — returns a list of results matching a title string
//   2. downloadCover(isbn:) — downloads cover art by ISBN
//
// API reference: https://openlibrary.org/developers/api
// No API key required. Free for personal use with no rate limiting concerns.
//
// Cover art: https://covers.openlibrary.org/b/isbn/{ISBN}-L.jpg
// Search:    https://openlibrary.org/search.json?title=...

import Foundation

// MARK: - Search Result

struct OpenLibrarySearchResult: Identifiable {
    let id: String          // OpenLibrary key e.g. "/works/OL45804W"
    let title: String
    let author: String
    let year: String
    let pageCount: Int?
    let isbn: String?
        let coverId: Int?
        let coverURL: URL?
        let thumbnailURL: URL?
}

// MARK: - Service

struct OpenLibraryService {

    private static let searchBase = "https://openlibrary.org/search.json"
    private static let coverBase  = "https://covers.openlibrary.org/b/isbn"

    // MARK: - Search

    /// Search for books by title. Returns up to 10 results.
    static func search(query: String) async throws -> [OpenLibrarySearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(searchBase)?title=\(encoded)&limit=10&fields=key,title,author_name,first_publish_year,number_of_pages_median,isbn,cover_i"

        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let docs = json?["docs"] as? [[String: Any]] ?? []

        return docs.prefix(10).compactMap { doc in
            guard let key = doc["key"] as? String,
                  let title = doc["title"] as? String else { return nil }

            let authors = doc["author_name"] as? [String] ?? []
            let author = authors.first ?? "Unknown Author"
            let year = (doc["first_publish_year"] as? Int).map { String($0) } ?? ""
            let pageCount = doc["number_of_pages_median"] as? Int
            let isbns = doc["isbn"] as? [String]
                        let isbn = isbns?.first
                        let coverId = doc["cover_i"] as? Int

                        var coverURL: URL? = nil
                        var thumbnailURL: URL? = nil
                        if let coverId {
                            coverURL     = URL(string: "https://covers.openlibrary.org/b/id/\(coverId)-L.jpg")
                            thumbnailURL = URL(string: "https://covers.openlibrary.org/b/id/\(coverId)-M.jpg")
                        } else if let isbn {
                            coverURL     = URL(string: "\(coverBase)/\(isbn)-L.jpg")
                            thumbnailURL = URL(string: "\(coverBase)/\(isbn)-M.jpg")
                        }

                        return OpenLibrarySearchResult(
                            id: key,
                            title: title,
                            author: author,
                            year: year,
                            pageCount: pageCount,
                            isbn: isbn,
                            coverId: coverId,
                            coverURL: coverURL,
                            thumbnailURL: thumbnailURL
                        )
        }
    }

    // MARK: - Download Cover

    /// Downloads cover image data from an OpenLibrarySearchResult coverURL.
    /// Returns nil if no cover is available or the download fails.
    static func downloadCover(from url: URL) async -> Data? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            // OpenLibrary returns a 1x1 gif when no cover exists — reject tiny responses
            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  data.count > 1000 else { return nil }
            return data
        } catch {
            AppLogger.warning("Cover download failed for \(url.lastPathComponent)", domain: .api)
            return nil
        }
    }
}
