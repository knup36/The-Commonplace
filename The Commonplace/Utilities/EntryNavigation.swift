import SwiftUI

// MARK: - EntryNavigation
// Central routing for entry detail navigation.
// Used across FeedView, CollectionDetailView, TagFeedView, and TodayView.
// Add new entry types here when they require their own detail view.

@ViewBuilder
func destinationView(for entry: Entry) -> some View {
    if entry.tagNames.contains(WeeklyReviewTheme.weeklyReviewTag) {
        WeeklyReviewDetailView(entry: entry)
    } else {
        switch entry.type {
        case .location: LocationDetailView(entry: entry)
        case .sticky:   StickyDetailView(entry: entry)
        case .media:    MediaDetailView(entry: entry)
        default:        EntryDetailView(entry: entry)
        }
    }
}
