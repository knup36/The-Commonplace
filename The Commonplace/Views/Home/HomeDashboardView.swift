// HomeDashboardView.swift
// Commonplace
//
// New dashboard-style Home tab replacing HomeView.
// Inspired by Apple Music / Shortcuts app layout:
//   - Vertical scroll overall
//   - Each section scrolls horizontally
//   - 2 rows × 6 columns = 12 cards max per section
//   - "See All" button appears when section has more than 12 items
//
// Sections:
//   Bookmarks  — isPinned entries
//   Collections — isPinned collections
//   Tags       — isPinned tags
//
// Cards are 160×120pts with entry accent color background.
// Each card type shows minimal but meaningful content.
//
// Keep HomeView.swift around as fallback — swap back in
// ContentView if this needs to be rolled back.

import SwiftUI
import SwiftData

struct HomeDashboardView: View {
    @Query var allCollections: [Collection]
    @Query(sort: \Entry.createdAt, order: .reverse) var allEntries: [Entry]
    @Query var allTags: [Tag]
    @EnvironmentObject var themeManager: ThemeManager
    
    var style: any AppThemeStyle { themeManager.style }
    
    // Max cards per section (2 rows × 6 columns)
    private let maxCards = 12
    private let rows = [GridItem(.fixed(80), spacing: 10), GridItem(.fixed(80), spacing: 10)]
    
    // MARK: - Filtered Data
    
    var pinnedEntries: [Entry] {
        allEntries.filter { $0.isPinned }
    }
    
    var pinnedCollections: [Collection] {
        allCollections
            .filter { $0.isPinned }
            .sorted { $0.pinnedOrder < $1.pinnedOrder }
    }
    
    var pinnedTags: [Tag] {
        allTags
            .filter { $0.isPinned }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    var hasAnything: Bool {
        !pinnedEntries.isEmpty || !pinnedCollections.isEmpty ||
        !pinnedTags.isEmpty
    }
    
    func entryCount(for collection: Collection) -> Int {
        allEntries.filter { collectionMatches(entry: $0, collection: collection) }.count
    }
    
    func entryCount(for tag: Tag) -> Int {
        allEntries.filter { $0.tagNames.contains(tag.name) }.count
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    
                    // Title
                    Text("Home")
                        .font(style.usesSerifFonts
                              ? .system(size: 34, weight: .bold, design: .serif)
                              : .largeTitle.bold())
                        .foregroundStyle(style.primaryText)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    if !hasAnything {
                        emptyState
                    }
                    
                    // Bookmarks section
                    if !pinnedEntries.isEmpty {
                        horizontalSection(
                            title: "Bookmarks",
                            icon: "bookmark.fill",
                            count: pinnedEntries.count,
                            seeAllDestination: AnyView(PinnedPagesListView())
                        ) {
                            ForEach(pinnedEntries.prefix(maxCards)) { entry in
                                NavigationLink(destination: destinationView(for: entry)) {
                                    CompactEntryCard(entry: entry, style: style)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Collections section
                    if !pinnedCollections.isEmpty {
                        horizontalSection(
                            title: "Collections",
                            icon: "magazine.fill",
                            count: pinnedCollections.count,
                            seeAllDestination: AnyView(PinnedCollectionsListView())
                        ) {
                            ForEach(pinnedCollections.prefix(maxCards)) { collection in
                                NavigationLink(destination: CollectionDetailView(collection: collection)) {
                                    CompactCollectionCard(
                                        collection: collection,
                                        entryCount: entryCount(for: collection),
                                        style: style
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Tags section
                    if !pinnedTags.isEmpty {
                        horizontalSection(
                            title: "Tags",
                            icon: "tag.fill",
                            count: pinnedTags.count,
                            seeAllDestination: nil
                        ) {
                            ForEach(pinnedTags.prefix(maxCards)) { tag in
                                NavigationLink(destination: TagFeedView(tag: tag.name)) {
                                    CompactTagCard(
                                        tag: tag,
                                        entryCount: entryCount(for: tag),
                                        style: style
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Bottom padding
                    Color.clear.frame(height: 50)
                }
            }
            .background(style.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(style.accent)
                    }
                }
            }
        }
    }
    
    // MARK: - Horizontal Section Builder
    
    /// Builds a section with a header and a 2-row horizontal scroll grid.
    /// Shows a "See All" button in the header if count exceeds maxCards.
    @ViewBuilder
    func horizontalSection<Content: View>(
        title: String,
        icon: String,
        count: Int,
        seeAllDestination: AnyView?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(style.accent)
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(style.primaryText)
                Spacer()
                if count > maxCards, let destination = seeAllDestination {
                    NavigationLink(destination: destination) {
                        Text("See All")
                            .font(.caption)
                            .foregroundStyle(style.accent)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // 2-row horizontal grid
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: rows, spacing: 10) {
                    content()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .scrollClipDisabled()
        }
    }
    
    // MARK: - Empty State
    
    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "pin.slash")
                .font(.system(size: 36))
                .foregroundStyle(style.tertiaryText)
            Text("Nothing here yet")
                .font(.headline)
                .foregroundStyle(style.secondaryText)
            Text("Bookmark entries, collections, or tags to see them here.")
                .font(.caption)
                .foregroundStyle(style.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 20)
    }
}
