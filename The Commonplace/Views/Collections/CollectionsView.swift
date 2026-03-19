import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CoreLocation

// MARK: - CollectionsView
// Content view for the Collections section of the Library tab.
// NavigationStack is owned by LibraryView — this view is content only.
// Pinned collections removed — they will live on the Home tab.
// Screen: Library tab → Collections segment

struct CollectionsView: View {
    @Query var allCollections: [Collection]
    @Query var allEntries: [Entry]
    @Environment(\.modelContext) var modelContext
    @Environment(\.editMode) var editMode
    @EnvironmentObject var themeManager: ThemeManager

    @Binding var navigationPath: NavigationPath
    @Binding var selectedTab: Int
    @Binding var showingAddCollection: Bool
    @Binding var currentSort: CollectionSort
    @State private var collectionToEdit: Collection? = nil

    var style: any AppThemeStyle { themeManager.style }

    enum CollectionSort: String, CaseIterable {
        case custom = "Custom"
        case name = "Name"
        case entryCount = "Entry Count"
        case dateCreated = "Date Created"
        case recentlyModified = "Recently Modified"
    }

    var displayedCollections: [Collection] {
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

    func entryCount(for collection: Collection) -> Int {
        allEntries.filter { collectionMatches(entry: $0, collection: collection) }.count
    }

    func latestEntry(for collection: Collection) -> Date {
        allEntries
            .filter { collectionMatches(entry: $0, collection: collection) }
            .map { $0.createdAt }
            .max() ?? collection.createdAt
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

    // MARK: - Body

    var body: some View {
        List {
            // Header — title + picker
            VStack(alignment: .leading, spacing: 12) {
                Text("Collections")
                    .font(style.usesSerifFonts
                          ? .system(size: 34, weight: .bold, design: .serif)
                          : .largeTitle.bold())
                    .foregroundStyle(style.primaryText)
                    .padding(.leading, 8)
                Picker("", selection: $selectedTab) {
                    Text("Collections").tag(0)
                    Text("Tags").tag(1)
                }
                .pickerStyle(.segmented)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

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

            // Collections
            ForEach(displayedCollections) { collection in
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
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        modelContext.delete(collection)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    if !collection.isSystem {
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
                var reordered = displayedCollections
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
        .sheet(item: $collectionToEdit) { collection in
            CollectionFormView(collection: collection)
        }
    }
}
