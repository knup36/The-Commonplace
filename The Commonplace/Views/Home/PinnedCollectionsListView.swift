import SwiftUI
import SwiftData

// MARK: - PinnedCollectionsListView
// Full list of all pinned collections.
// Accessed via the chevron on the Collections section of HomeView.
// Screen: Home tab → Collections →

struct PinnedCollectionsListView: View {
    @Query var allCollections: [Collection]
    @EnvironmentObject var themeManager: ThemeManager
    var style: any AppThemeStyle { themeManager.style }

    var pinnedCollections: [Collection] {
        allCollections
            .filter { $0.isPinned }
            .sorted { $0.pinnedOrder < $1.pinnedOrder }
    }

    var body: some View {
        List {
            ForEach(pinnedCollections) { collection in
                ZStack {
                    NavigationLink(destination: CollectionDetailView(collection: collection)) {
                        EmptyView()
                    }
                    .opacity(0)
                    CollectionListRowView(collection: collection)
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
        .navigationTitle("Collections")
        .navigationBarTitleDisplayMode(.large)
    }
}
