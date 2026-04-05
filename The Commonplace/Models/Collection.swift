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
