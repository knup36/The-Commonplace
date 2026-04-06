// Collection.swift
// Commonplace
//
// SwiftData model representing a user-defined collection of entries.
// Collections are smart filters — they match entries dynamically based on
// filter criteria rather than storing explicit entry references.
//
// ============================================================
// SCHEMA VERSION: 3
// Last updated: v1.14.1
//
// Schema change policy: same as Entry.swift — optional fields are safe to
// add at any time. Never remove fields without deprecating first.
//
// Field version history:
//   v1.1  — id, createdAt, name, icon, colorHex, order, isPinned, pinnedOrder, isSystem
//   v1.1  — filterTypes, filterTags, filterDateRange, filterSearchText
//   v1.3  — filterLocationName, filterLocationLatitude, filterLocationLongitude, filterLocationRadius
//   v1.5  — filterMediaStatus (movie/TV watch status filter)
//   v1.14.1 — filterLocationStatus (Want to Visit / Been Here filter)
//
// Filter notes:
//   - filterSearchText == "__bookmarks__" or "__favorites__" are magic values
//     that filter by isPinned — not actual text search
//   - filterTypes contains EntryType rawValues (strings)
//   - filterMediaStatus contains: "wantTo", "inProgress", "finished"
//   - filterLocationStatus contains: "wantToVisit", "beenHere"
//   - All filter fields are AND-combined in CollectionMatching.swift
// ============================================================

import SwiftData
import Foundation

@Model
class Collection {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var name: String = ""
    var icon: String = "folder.fill"
    var colorHex: String = "#007AFF"
    var order: Int = 0
    var isPinned: Bool = false
    var pinnedOrder: Int = 0
    var isSystem: Bool = false
    // Filters
    var filterTypes: [String] = []
    var filterTags: [String] = []
    var filterDateRange: String = DateFilterRange.allTime.rawValue
    var filterSearchText: String? = nil
    
    // Location radius filter
    var filterLocationName: String? = nil
    var filterLocationLatitude: Double? = nil
    var filterLocationLongitude: Double? = nil
    var filterLocationRadius: Double? = nil
    var filterMediaStatus: [String] = []
        var filterLocationStatus: [String] = []
    
    init(name: String, icon: String = "folder.fill", colorHex: String = "#007AFF", order: Int = 0) {
        self.id = UUID()
        self.createdAt = Date()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.order = order
        self.filterTypes = []
        self.filterTags = []
        self.filterDateRange = DateFilterRange.allTime.rawValue
    }
}

enum DateFilterRange: String, CaseIterable {
    case today = "Today"
    case last7Days = "Last 7 Days"
    case last30Days = "Last 30 Days"
    case last90Days = "Last 90 Days"
    case allTime = "All Time"
}
