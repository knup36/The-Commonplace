import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CoreLocation

// This is the MAIN view of the Collections tab

struct CollectionsView: View {
    @Query var allCollections: [Collection]
    @Query var allEntries: [Entry]
    @Environment(\.modelContext) var modelContext
    @Environment(\.editMode) var editMode
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddCollection = false
    @State private var collectionToEdit: Collection? = nil
    @State private var currentSort: CollectionSort = .custom
    @State private var navigationPath = NavigationPath()

    var style: any AppThemeStyle { themeManager.style }

    enum CollectionSort: String, CaseIterable {
        case custom = "Custom"
        case name = "Name"
        case entryCount = "Entry Count"
        case dateCreated = "Date Created"
        case recentlyModified = "Recently Modified"
    }

    var pinnedCollections: [Collection] {
        allCollections.filter { $0.isPinned }.sorted { $0.pinnedOrder < $1.pinnedOrder }
    }

    var unpinnedCollections: [Collection] {
        if currentSort == .custom {
            return sortedCollections.filter { !$0.isPinned }
        }
        return sortedCollections
    }

    func entryCount(for collection: Collection) -> Int {
        allEntries.filter { collectionMatches(entry: $0, collection: collection) }.count
    }

    func latestEntry(for collection: Collection) -> Date {
        allEntries
            .filter { collectionMatches(entry: $0, collection: collection) }
            .map { $0.createdAt }
            .max() ?? collection.createdAt
    }

    var sortedCollections: [Collection] {
        switch currentSort {
        case .custom:
            return allCollections.sorted { $0.order < $1.order }
        case .name:
            return allCollections.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .entryCount:
            return allCollections.sorted { entryCount(for: $0) > entryCount(for: $1) }
        case .dateCreated:
            return allCollections.sorted { $0.createdAt > $1.createdAt }
        case .recentlyModified:
            return allCollections.sorted { latestEntry(for: $0) > latestEntry(for: $1) }
        }
    }

    func iconForSort(_ sort: CollectionSort) -> String {
        switch sort {
        case .custom:           return "hand.draw.fill"
        case .name:             return "textformat.abc"
        case .entryCount:       return "number"
        case .dateCreated:      return "calendar"
        case .recentlyModified: return "clock.fill"
        }
    }

    func pinCollection(_ collection: Collection) {
        let currentPinned = allCollections.filter { $0.isPinned }
        guard currentPinned.count < 8 else { return }
        collection.isPinned = true
        collection.pinnedOrder = currentPinned.count
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                // Inkwell title
                if style.usesSerifFonts {
                    Text("Collections")
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .foregroundStyle(style.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                // Pinned collections grid
                if !pinnedCollections.isEmpty && currentSort == .custom {
                    PinnedCollectionsView(
                        collections: pinnedCollections,
                        navigationPath: $navigationPath,
                        entries: allEntries
                    )
                    .listRowInsets(EdgeInsets(top: 16, leading: 8, bottom: 16, trailing: 8))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                // Sort indicator
                if currentSort != .custom {
                    HStack {
                        Image(systemName: iconForSort(currentSort))
                            .font(.caption)
                        Text("Sorted by \(currentSort.rawValue)")
                            .font(.caption)
                        Spacer()
                        Button("Reset") {
                            withAnimation { currentSort = .custom }
                        }
                        .font(.caption)
                        .foregroundStyle(style.accent)
                    }
                    .foregroundStyle(style.secondaryText)
                    .listRowBackground(style.background)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
                }

                // Collections list
                ForEach(unpinnedCollections) { collection in
                    ZStack {
                        NavigationLink(destination: CollectionDetailView(collection: collection)) {
                            EmptyView()
                        }
                        .opacity(0)
                        CollectionListRowView(collection: collection)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if currentSort == .custom {
                            Button {
                                withAnimation { pinCollection(collection) }
                            } label: {
                                Label("Pin", systemImage: "pin.fill")
                            }
                            .tint(.orange)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if !collection.isSystem {
                            Button(role: .destructive) {
                                modelContext.delete(collection)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                collectionToEdit = collection
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
                .onMove { from, to in
                    guard currentSort == .custom else { return }
                    guard editMode?.wrappedValue.isEditing == true else { return }
                    var reordered = unpinnedCollections
                    reordered.move(fromOffsets: from, toOffset: to)
                    for (index, collection) in reordered.enumerated() {
                        if !collection.isSystem {
                            collection.order = index
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(style.background)
            .navigationTitle(style.usesSerifFonts ? "" : "Collections")
            .navigationBarTitleDisplayMode(style.usesSerifFonts ? .inline : .large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentSort == .custom {
                        EditButton()
                            .foregroundStyle(style.accent)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Menu {
                            Picker("Sort", selection: $currentSort) {
                                ForEach(CollectionSort.allCases, id: \.self) { sort in
                                    Label(sort.rawValue, systemImage: iconForSort(sort))
                                        .tag(sort)
                                }
                            }
                        } label: {
                            Image(systemName: currentSort == .custom ? "arrow.up.arrow.down" : "arrow.up.arrow.down.circle.fill")
                                .foregroundStyle(style.accent)
                        }
                        Button {
                            showingAddCollection = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(style.accent)
                        }
                    }
                }
            }
            .navigationDestination(for: Collection.self) { collection in
                CollectionDetailView(collection: collection)
            }
            .sheet(isPresented: $showingAddCollection) {
                AddCollectionView()
            }
            .sheet(item: $collectionToEdit) { collection in
                EditCollectionView(collection: collection)
            }
        }
    }
}
