import Foundation
import CoreLocation

func collectionMatches(entry: Entry, collection: Collection) -> Bool {
    if collection.filterSearchText == "__favorites__" {
        return entry.isFavorited
    }
    if !collection.filterTypes.isEmpty {
        guard collection.filterTypes.contains(entry.type.rawValue) else { return false }
    }
    if !collection.filterTags.isEmpty {
        let hasTag = collection.filterTags.contains(where: { entry.tagNames.contains($0) })
        guard hasTag else { return false }
    }
    if let range = DateFilterRange(rawValue: collection.filterDateRange) {
        let now = Date()
        switch range {
        case .today:
            guard Calendar.current.isDateInToday(entry.createdAt) else { return false }
        case .last7Days:
            guard entry.createdAt > now.addingTimeInterval(-7 * 24 * 60 * 60) else { return false }
        case .last30Days:
            guard entry.createdAt > now.addingTimeInterval(-30 * 24 * 60 * 60) else { return false }
        case .last90Days:
            guard entry.createdAt > now.addingTimeInterval(-90 * 24 * 60 * 60) else { return false }
        case .allTime:
            break
        }
    }
    if let filterLat = collection.filterLocationLatitude,
       let filterLon = collection.filterLocationLongitude,
       let radius = collection.filterLocationRadius {
        guard let entryLat = entry.captureLatitude,
              let entryLon = entry.captureLongitude else { return false }
        let entryLocation = CLLocation(latitude: entryLat, longitude: entryLon)
        let filterLocation = CLLocation(latitude: filterLat, longitude: filterLon)
        let distanceMiles = entryLocation.distance(from: filterLocation) / 1609.34
        guard distanceMiles <= radius else { return false }
    }
    if let searchText = collection.filterSearchText,
       !searchText.isEmpty,
       searchText != "__favorites__" {
        guard entry.text.localizedCaseInsensitiveContains(searchText) ||
                entry.extractedText?.localizedCaseInsensitiveContains(searchText) == true ||
                entry.linkTitle?.localizedCaseInsensitiveContains(searchText) == true ||
                entry.transcript?.localizedCaseInsensitiveContains(searchText) == true ||
                entry.locationName?.localizedCaseInsensitiveContains(searchText) == true ||
                entry.locationAddress?.localizedCaseInsensitiveContains(searchText) == true ||
                entry.captureLocationName?.localizedCaseInsensitiveContains(searchText) == true ||
                            entry.locationCategory?.localizedCaseInsensitiveContains(searchText) == true
                    else { return false }
    }
    return true
}
func entryMatchesSearch(_ entry: Entry, searchText: String) -> Bool {
    guard !searchText.isEmpty else { return true }
    let matchingIDs = SearchIndex.shared.search(query: searchText)
    return matchingIDs.contains(entry.id)
}
