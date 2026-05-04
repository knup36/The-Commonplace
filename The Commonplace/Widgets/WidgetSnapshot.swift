// WidgetSnapshot.swift
// Commonplace + CommonplaceWidgets
//
// Lightweight Codable structs representing entry data for widgets.
// Written to the App Group container by the main app, read by the
// widget extension. No SwiftData dependency — pure value types only.
//
// Add this file to BOTH targets:
//   - The Commonplace (main app)
//   - CommonplaceWidgets (widget extension)
//
// Stored as JSON at:
//   group.com.johncaldwell.commonplace/widget_snapshot.json

import Foundation

// MARK: - WidgetEntrySnapshot

/// Lightweight representation of a single Entry for widget display.
struct WidgetEntrySnapshot: Codable, Identifiable {
    let id: String           // UUID string
    let type: String         // EntryType.rawValue
    let text: String         // entry.text — first line used as preview
    let title: String?       // mediaTitle, linkTitle, locationName, stickyTitle etc.
    let createdAt: Date
    let icon: String         // SF Symbol name
    let accentHex: String    // Entry color inheritance
}

// MARK: - WidgetPayload

/// Container written to App Group — holds the N most recent snapshots.
struct WidgetPayload: Codable {
    let snapshots: [WidgetEntrySnapshot]
    let updatedAt: Date
}

// MARK: - MemorySnapshot

/// Lightweight representation of a random past entry for the Memory widget.
struct MemorySnapshot: Codable {
    let id: String
    let type: String
    let title: String?
    let text: String
    let icon: String
    let accentHex: String
    let createdAt: Date
    let imagePath: String?  // filename in App Group container, nil if not a photo
}

// MARK: - MemorySnapshotStore

struct MemorySnapshotStore {
    static let fileName = "memory_snapshot.json"
    static let lastRefreshKey = "memorySnapshotLastRefresh"

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.johncaldwell.commonplace")?
            .appendingPathComponent(fileName)
    }

    static func load() -> MemorySnapshot? {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MemorySnapshot.self, from: data)
    }

    static func save(_ snapshot: MemorySnapshot) {
        guard let url = fileURL,
              let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Write photo image data to App Group container and return the filename
    static func saveImage(_ data: Data, id: String) -> String? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.johncaldwell.commonplace") else { return nil }
        let filename = "memory_image_\(id).jpg"
        let url = container.appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
        return filename
    }

    /// Load photo image data from App Group container
    static func loadImage(filename: String) -> Data? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.johncaldwell.commonplace") else { return nil }
        let url = container.appendingPathComponent(filename)
        return try? Data(contentsOf: url)
    }

    /// Returns true if 24 hours have passed since last refresh
    static var needsRefresh: Bool {
        guard let last = UserDefaults.standard.object(forKey: lastRefreshKey) as? Date else { return true }
        return Date().timeIntervalSince(last) > 86400
    }

    static func markRefreshed() {
        UserDefaults.standard.set(Date(), forKey: lastRefreshKey)
    }
}

// MARK: - GiftCardSnapshot

/// Lightweight representation of a GiftCard for widget display.
struct GiftCardSnapshot: Codable {
    let title: String
    let message: String
    let icon: String
    let firedAt: Date
    let isEmpty: Bool
    let thumbnailPath: String?  // filename in App Group container, nil if no cover art
}

// MARK: - GiftCardSnapshotStore

struct GiftCardSnapshotStore {
    static let fileName = "gift_card_snapshot.json"
    
    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.johncaldwell.commonplace")?
            .appendingPathComponent(fileName)
    }
    
    static func load() -> GiftCardSnapshot? {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(GiftCardSnapshot.self, from: data)
    }
    
    static func save(_ snapshot: GiftCardSnapshot) {
            guard let url = fileURL,
                  let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }

        /// Write thumbnail image data to App Group container and return the filename
        static func saveThumbnail(_ data: Data, id: String) -> String? {
            guard let container = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.com.johncaldwell.commonplace") else { return nil }
            let filename = "giftcard_thumb_\(id).jpg"
            let url = container.appendingPathComponent(filename)
            try? data.write(to: url, options: .atomic)
            return filename
        }

        /// Load thumbnail image data from App Group container
        static func loadThumbnail(filename: String) -> Data? {
            guard let container = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.com.johncaldwell.commonplace") else { return nil }
            let url = container.appendingPathComponent(filename)
            return try? Data(contentsOf: url)
        }
}

// MARK: - WidgetSnapshotStore (shared read logic)

/// Read-only access to the widget payload from the App Group container.
/// Used by the widget extension. The main app uses WidgetDataStore to write.
struct WidgetSnapshotStore {
    static let fileName = "widget_snapshot.json"
    
    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.johncaldwell.commonplace")?
            .appendingPathComponent(fileName)
    }
    
    static func load() -> WidgetPayload? {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetPayload.self, from: data)
    }
}
