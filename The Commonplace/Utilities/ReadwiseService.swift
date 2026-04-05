// ReadwiseService.swift
// Commonplace
//
// Handles all network communication with the Readwise and Reader APIs.
// This service is responsible ONLY for fetching data — it has no knowledge
// of SwiftData, Entry models, or Commonplace business logic.
//
// Two APIs are used:
//   - Reader API v3 (/api/v3/list/) — fetches saved documents and their highlights
//     Highlights in Reader are returned as child Documents with a parent_id field.
//
//   - Classic Readwise API v2 (/api/v2/) — reserved for future book/Kindle support
//
// Sync strategy:
//   - Fetches all Reader documents tagged "commonplace"
//   - Separates parent documents (articles) from child documents (highlights)
//   - Returns them paired so ReadwiseSyncCoordinator can build entries
//
// Authentication:
//   - API token stored in iOS Keychain via ReadwiseKeychainService
//   - Header format: "Authorization: Token <user_token>"
//
// Rate limits:
//   - Reader v3 list: 20 requests/minute
//   - This service respects rate limits via Retry-After header handling
//
// Usage:
//   let service = ReadwiseService()
//   let result = try await service.fetchTaggedDocuments(tag: "commonplace")

import Foundation

// MARK: - Response Models

/// A single document returned by the Reader /v3/list/ endpoint.
/// Both articles AND highlights are "documents" in Reader's model.
/// Highlights have a non-nil parent_id pointing to their source article.
struct ReaderDocument: Codable {
    let id: String
    let url: String
    let sourceURL: String?
    let title: String?
    let author: String?
    let category: String?
    let imageURL: String?
    let parentID: String?       // nil = top-level article, non-nil = highlight or note
    let tags: [String: ReaderTag]
    let createdAt: String?
    let updatedAt: String?
    let summary: String?
    let content: String?
    let siteName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case url
        case sourceURL  = "source_url"
        case title
        case author
        case category
        case imageURL   = "image_url"
        case parentID   = "parent_id"
        case tags
        case createdAt  = "created_at"
        case updatedAt  = "updated_at"
        case summary
        case content
        case siteName   = "site_name"
    }
}

/// Reader returns tags as a dictionary keyed by tag ID, each with a name.
struct ReaderTag: Codable {
    let name: String
}

/// Paginated response envelope from /v3/list/
struct ReaderListResponse: Codable {
    let count: Int
    let nextPageCursor: String?
    let results: [ReaderDocument]
    
    enum CodingKeys: String, CodingKey {
        case count
        case nextPageCursor = "nextPageCursor"
        case results
    }
}

// MARK: - Paired Result

/// A top-level article document paired with all its highlight child documents.
/// This is what ReadwiseSyncCoordinator receives and converts into Commonplace entries.
struct ReaderDocumentWithHighlights {
    let document: ReaderDocument
    let highlights: [ReaderDocument]
}

// MARK: - Errors

enum ReadwiseServiceError: LocalizedError {
    case missingToken
    case invalidToken
    case rateLimited(retryAfter: Int)
    case networkError(Error)
    case decodingError(Error)
    case unexpectedResponse(Int)
    
    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "No Readwise API token found. Please add your token in Settings."
        case .invalidToken:
            return "Your Readwise API token is invalid. Please check it in Settings."
        case .rateLimited(let seconds):
            return "Readwise rate limit hit. Please wait \(seconds) seconds and try again."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse Readwise response: \(error.localizedDescription)"
        case .unexpectedResponse(let code):
            return "Unexpected response from Readwise (HTTP \(code))."
        }
    }
}

// MARK: - Service

class ReadwiseService {
    
    private let baseURLv3 = "https://readwise.io/api/v3"
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Public API
    
    /// Validates that the stored token is accepted by Readwise.
    /// Uses the lightweight /api/v2/auth/ endpoint — expects HTTP 204.
    func validateToken(_ token: String) async throws -> Bool {
        let url = URL(string: "https://readwise.io/api/v2/auth/")!
        var request = URLRequest(url: url)
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 204
    }
    
    /// Fetches all Reader documents tagged with the given tag (e.g. "commonplace"),
    /// then fetches their highlight children and pairs them together.
    ///
    /// - Parameter tag: The Readwise tag to filter by (default: "commonplace")
    /// - Parameter updatedAfter: Optional ISO8601 date string — only fetch docs updated after this date
    /// - Returns: Array of documents paired with their highlights
    func fetchTaggedDocuments(
        tag: String = "commonplace",
        updatedAfter: String? = nil
    ) async throws -> [ReaderDocumentWithHighlights] {
        
        // Step 1: Fetch all top-level documents with the given tag
        let taggedDocuments = try await fetchAllPages(tag: tag, updatedAfter: updatedAfter)
        let articles = taggedDocuments.filter { $0.parentID == nil }
        guard !articles.isEmpty else { return [] }
        
        // Step 2: Fetch ALL highlight-category documents from Reader.
        // The API does not support filtering highlights by parent_id as a query param,
        // so we fetch all highlights and group them client-side.
        let allHighlights = try await fetchAllHighlights(updatedAfter: updatedAfter)
        
        // Step 3: Group highlights by parent_id
        var highlightsByParent: [String: [ReaderDocument]] = [:]
        for highlight in allHighlights {
            guard let parentID = highlight.parentID else { continue }
            highlightsByParent[parentID, default: []].append(highlight)
        }
        
        // Step 4: Pair each tagged article with its highlights
        let paired = articles.map { article in
            let highlights = highlightsByParent[article.id] ?? []
            return ReaderDocumentWithHighlights(
                document: article,
                highlights: highlights
            )
        }
        
        return paired
    }
    
    // MARK: - Private Pagination
    
    /// Fetches all pages from /v3/list/ for the given tag, following nextPageCursor until done.
    private func fetchAllPages(
        tag: String,
        updatedAfter: String?
    ) async throws -> [ReaderDocument] {
        
        var allResults: [ReaderDocument] = []
        var pageCursor: String? = nil
        
        repeat {
            let response = try await fetchPage(
                tag: tag,
                updatedAfter: updatedAfter,
                pageCursor: pageCursor
            )
            allResults.append(contentsOf: response.results)
            pageCursor = response.nextPageCursor
        } while pageCursor != nil
        
        return allResults
    }
    
    /// Fetches all highlight-category documents from Reader, paginating until complete.
    /// Highlights are child documents with a parent_id pointing to their source article.
    private func fetchAllHighlights(updatedAfter: String?) async throws -> [ReaderDocument] {
        var allResults: [ReaderDocument] = []
        var pageCursor: String? = nil
        
        repeat {
            let token = try storedToken()
            var components = URLComponents(string: "\(baseURLv3)/list/")!
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "category", value: "highlight")
            ]
            if let updatedAfter {
                queryItems.append(URLQueryItem(name: "updatedAfter", value: updatedAfter))
            }
            if let pageCursor {
                queryItems.append(URLQueryItem(name: "pageCursor", value: pageCursor))
            }
            components.queryItems = queryItems
            
            guard let url = components.url else { break }
            var request = URLRequest(url: url)
            request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { break }
            
            let decoded = try JSONDecoder().decode(ReaderListResponse.self, from: data)
            // Debug: print raw JSON of first highlight to find correct field names
            if allResults.isEmpty, let firstHighlight = decoded.results.first(where: { $0.category == "highlight" }) {
                if let raw = try? JSONSerialization.jsonObject(with: data),
                   let dict = raw as? [String: Any],
                   let results = dict["results"] as? [[String: Any]],
                   let first = results.first(where: { $0["category"] as? String == "highlight" }) {
                }
            }
            allResults.append(contentsOf: decoded.results)
            pageCursor = decoded.nextPageCursor
        } while pageCursor != nil
        
        return allResults
    }
    
    /// Fetches a single page from /v3/list/
    private func fetchPage(
        tag: String,
        updatedAfter: String?,
        pageCursor: String?
    ) async throws -> ReaderListResponse {
        
        let token = try storedToken()
        
        // Build URL with query parameters
        var components = URLComponents(string: "\(baseURLv3)/list/")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "tag", value: tag)
        ]
        if let updatedAfter {
            queryItems.append(URLQueryItem(name: "updatedAfter", value: updatedAfter))
        }
        if let pageCursor {
            queryItems.append(URLQueryItem(name: "pageCursor", value: pageCursor))
        }
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw ReadwiseServiceError.unexpectedResponse(0)
        }
        
        var request = URLRequest(url: url)
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ReadwiseServiceError.networkError(error)
        }
        
        guard let http = response as? HTTPURLResponse else {
            throw ReadwiseServiceError.unexpectedResponse(0)
        }
        
        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            throw ReadwiseServiceError.invalidToken
        case 429:
            let retryAfter = Int(http.value(forHTTPHeaderField: "Retry-After") ?? "60") ?? 60
            throw ReadwiseServiceError.rateLimited(retryAfter: retryAfter)
        default:
            throw ReadwiseServiceError.unexpectedResponse(http.statusCode)
        }
        
        do {
            let decoded = try JSONDecoder().decode(ReaderListResponse.self, from: data)
            return decoded
        } catch {
            throw ReadwiseServiceError.decodingError(error)
        }
    }
    
    // MARK: - Keychain
    
    /// Retrieves the stored Readwise API token from the Keychain.
    /// Throws .missingToken if none has been saved yet.
    private func storedToken() throws -> String {
        guard let token = ReadwiseKeychainService.retrieveToken(), !token.isEmpty else {
            throw ReadwiseServiceError.missingToken
        }
        return token
    }
}

// MARK: - Keychain Helper

/// Thin wrapper around Security framework for storing the Readwise API token.
/// Tokens must never be stored in UserDefaults — Keychain only.
enum ReadwiseKeychainService {
    
    private static let service = "com.johncaldwell.commonplace"
    private static let account = "readwise_api_token"
    
    static func saveToken(_ token: String) -> Bool {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String:   data
        ]
        SecItemDelete(query as CFDictionary) // remove any existing entry first
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    static func retrieveToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }
    
    static func deleteToken() -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
