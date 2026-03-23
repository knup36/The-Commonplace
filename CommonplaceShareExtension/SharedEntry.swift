// SharedEntry.swift
// Commonplace + CommonplaceShareExtension
//
// Codable struct representing a pending entry captured via the Share Extension.
// Written to the App Group container by the extension, read and ingested
// by the main app on next launch via ShareExtensionIngestor.
//
// Stored as JSON at:
//   group.com.johncaldwell.commonplace/pending_entries/[uuid].json

import Foundation

struct SharedEntry: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let type: String          // matches EntryType.rawValue
    let text: String
    let url: String?
    let imageData: Data?      // for photo entries
    let locationName: String?
    let locationAddress: String?
    let locationLatitude: Double?
    let locationLongitude: Double?
    let tags: [String]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        type: String,
        text: String = "",
        url: String? = nil,
        imageData: Data? = nil,
        locationName: String? = nil,
        locationAddress: String? = nil,
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.type = type
        self.text = text
        self.url = url
        self.imageData = imageData
        self.locationName = locationName
        self.locationAddress = locationAddress
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.tags = tags
    }
}

// MARK: - App Group Container

struct AppGroupContainer {
    static let identifier = "group.com.johncaldwell.commonplace"
    static let pendingEntriesFolder = "pending_entries"

    static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        )
    }

    static var pendingEntriesURL: URL? {
        guard let container = containerURL else { return nil }
        let folder = container.appendingPathComponent(pendingEntriesFolder)
        try? FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        return folder
    }

    /// Write a pending SharedEntry to the App Group container
    static func save(_ entry: SharedEntry) throws {
        guard let folder = pendingEntriesURL else {
            throw AppGroupError.containerUnavailable
        }
        let fileURL = folder.appendingPathComponent("\(entry.id.uuidString).json")
        let data = try JSONEncoder().encode(entry)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Read all pending SharedEntry files from the App Group container
    static func loadPending() throws -> [SharedEntry] {
        guard let folder = pendingEntriesURL else { return [] }
        let files = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }

        return try files.compactMap { url in
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SharedEntry.self, from: data)
        }
    }

    /// Delete a pending entry after it has been ingested
    static func deletePending(id: UUID) {
        guard let folder = pendingEntriesURL else { return }
        let fileURL = folder.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
    }
}

enum AppGroupError: Error {
    case containerUnavailable
}
