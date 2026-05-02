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
