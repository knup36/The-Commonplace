import SwiftUI
import SwiftData

// MARK: - PinnedPagesListView
// Full list of all pinned entries.
// Accessed via the chevron on the Pages section of HomeView.
// Screen: Home tab → Pages →

struct PinnedPagesListView: View {
    @Query(sort: \Entry.createdAt, order: .reverse) var allEntries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager
    var style: any AppThemeStyle { themeManager.style }

    var pinnedEntries: [Entry] {
        allEntries.filter { $0.isPinned }
    }

    var body: some View {
        List {
            ForEach(pinnedEntries) { entry in
                ZStack {
                    NavigationLink(destination: NavigationRouter.destination(for: entry)) {
                        EmptyView()
                    }
                    .opacity(0)
                    EntryRowView(entry: entry)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(style.background)
        .navigationTitle("Bookmarks")
        .navigationBarTitleDisplayMode(.large)
    }
}
