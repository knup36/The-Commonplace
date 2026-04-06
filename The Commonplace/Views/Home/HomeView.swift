// HomeView.swift
// Commonplace
//
// Personal dashboard — the main entry point of the app.
// Shows pinned collections, pages, and tags.
// Screen: Home tab (leftmost tab)

import SwiftUI
import SwiftData

struct HomeView: View {
    @Query var allCollections: [Collection]
    @Query(sort: \Entry.createdAt, order: .reverse) var allEntries: [Entry]
    @Query var allTags: [Tag]
    
    var favoritedEntries: [Entry] {
        allEntries
            .filter { $0.isFavorited }
            .prefix(5)
            .map { $0 }
    }
    @EnvironmentObject var themeManager: ThemeManager
    var style: any AppThemeStyle { themeManager.style }
    
    var pinnedCollections: [Collection] {
        allCollections
            .filter { $0.isPinned }
            .sorted { $0.pinnedOrder < $1.pinnedOrder }
            .prefix(5)
            .map { $0 }
    }
    
    var pinnedEntries: [Entry] {
        allEntries
            .filter { $0.isPinned }
            .prefix(5)
            .map { $0 }
    }
    var pinnedTags: [Tag] {
        allTags
            .filter { $0.isPinned }
            .sorted { $0.createdAt < $1.createdAt }
            .prefix(5)
            .map { $0 }
    }
    
    func entryCount(for tag: Tag) -> Int {
        allEntries.filter { $0.tagNames.contains(tag.name) }.count
    }
    
    var hasAnyPinned: Bool {
        !pinnedCollections.isEmpty || !pinnedEntries.isEmpty ||
        !favoritedEntries.isEmpty || !pinnedTags.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Title
                HStack {
                    Text("Home")
                        .font(style.typeLargeTitle)
                        .foregroundStyle(style.primaryText)
                    Spacer()
                }
                .padding(.leading, 8)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                
                // Pages section
                if !pinnedEntries.isEmpty {
                    pagesSection
                }
                
                // Collections section
                if !pinnedCollections.isEmpty {
                    collectionsSection
                }
                // Favorites Section
                if !favoritedEntries.isEmpty {
                    favoritesSection
                }
                
                // Tags section
                if !pinnedTags.isEmpty {
                    tagsSection
                }
                
                // Empty state
                if !hasAnyPinned {
                    emptyState
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(style.background)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Pages Section
    
    var pagesSection: some View {
        Section {
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
        } header: {
            NavigationLink(destination: PinnedPagesListView()) {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(style.accent)
                    Text("Bookmarks")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(style.primaryText)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(style.primaryText)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
        }
    }
    
    // MARK: - Collections Section
    
    var collectionsSection: some View {
        Section {
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
        } header: {
            NavigationLink(destination: PinnedCollectionsListView()) {
                HStack(spacing: 6) {
                    Image(systemName: "magazine.fill")
                        .font(.caption)
                        .foregroundStyle(style.accent)
                    Text("Collections")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(style.primaryText)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(style.primaryText)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
        }
    }
    
    // MARK: Favorites Section
    
    var favoritesSection: some View {
        Section {
            ForEach(favoritedEntries) { entry in
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
        } header: {
            HStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(style.accent)
                    Text("Favorites")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(style.primaryText)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(style.primaryText)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
        }
    }
    
    // MARK: - Empty State
    
    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "pin.slash")
                .font(.system(size: 36))
                .foregroundStyle(style.tertiaryText)
            Text("Nothing pinned yet")
                .font(.headline)
                .foregroundStyle(style.secondaryText)
            Text("Swipe left on a collection, entry, or tag to bookmark it here.")
                .font(.caption)
                .foregroundStyle(style.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    // MARK: - Tags Section
    
    var tagsSection: some View {
        Section {
            ForEach(pinnedTags) { tag in
                NavigationLink(destination: TagFeedView(tag: tag.name)) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "number")
                                .font(.caption)
                                .foregroundStyle(style.accent)
                            Text(tag.name)
                                .font(style.typeBody)
                                .foregroundStyle(style.primaryText)
                        }
                        Spacer()
                        Text("\(entryCount(for: tag))")
                            .font(style.typeBodySecondary)
                            .fontWeight(.semibold)
                            .foregroundStyle(style.accent)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 24))
                .listRowSeparator(.visible)
            }
            Color.clear
                .frame(height: 50)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "tag.fill")
                    .font(.caption)
                    .foregroundStyle(style.accent)
                Text("Tags")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(style.primaryText)
                Spacer()
            }
            .padding(.horizontal, 8)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
        }
    }
}

