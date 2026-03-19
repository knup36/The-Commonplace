import SwiftUI
import SwiftData
import CoreLocation

// MARK: - LibraryView
// Combined Collections and Tags view with a segmented picker.
// Follows the same single-ScrollView pattern as TodayView for stable layout.
// Screen: Library tab (4th tab)

struct LibraryView: View {
    @Query var allCollections: [Collection]
    @Query var allEntries: [Entry]
    @Query var allEntryTags: [Entry]
    @Environment(\.modelContext) var modelContext
    @Environment(\.editMode) var editMode
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()
    @State private var showingAddCollection = false
    @State private var currentSort: CollectionSort = .custom
    @State private var collectionToEdit: Collection? = nil
    
    var style: any AppThemeStyle { themeManager.style }
    
    // MARK: - Collections logic
    
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
    
    // MARK: - Tags logic
    
    var allTags: [(tag: String, count: Int)] {
        var tagCounts: [String: Int] = [:]
        for entry in allEntries {
            for tag in entry.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        return tagCounts
            .map { (tag: $0.key, count: $0.value) }
            .sorted { $0.tag < $1.tag }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text(selectedTab == 0 ? "Collections" : "Tags")
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
                
                // Collections content
                if selectedTab == 0 {
                    if currentSort != .custom {
                        HStack {
                            Image(systemName: iconForSort(currentSort)).font(.caption)
                            Text("Sorted by \(currentSort.rawValue)").font(.caption)
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
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                withAnimation { collection.isPinned.toggle() }
                            } label: {
                                Label(collection.isPinned ? "Unpin" : "Pin", systemImage: collection.isPinned ? "pin.slash.fill" : "pin.fill")
                            }
                            .tint(.orange)
                        }
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
                
                // Tags content
                if selectedTab == 1 {
                    if allTags.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tag.slash")
                                .font(.system(size: 48))
                                .foregroundStyle(style.tertiaryText)
                            Text("No Tags Yet")
                                .font(.headline)
                                .foregroundStyle(style.secondaryText)
                            Text("Add tags to your entries to see them here")
                                .font(.caption)
                                .foregroundStyle(style.tertiaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(allTags, id: \.tag) { item in
                            NavigationLink(destination: TagFeedView(tag: item.tag)) {
                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: "number")
                                            .font(.caption)
                                            .foregroundStyle(style.accent)
                                        Text(item.tag)
                                            .font(style.body)
                                            .foregroundStyle(style.primaryText)
                                    }
                                    Spacer()
                                    Text("\(item.count)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(style.accent)
                                        .padding(.trailing, -12)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)
                            }
                            .listRowBackground(
                                style.usesSerifFonts
                                ? style.surface
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 16)
                                : nil
                            )
                            .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 24))
                            .listRowSeparator(style.usesSerifFonts ? .hidden : .visible)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(style.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if selectedTab == 0 && currentSort == .custom {
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
                        if selectedTab == 0 {
                            Button {
                                showingAddCollection = true
                            } label: {
                                Image(systemName: "plus")
                                    .foregroundStyle(style.accent)
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: Collection.self) { collection in
                CollectionDetailView(collection: collection)
            }
            .navigationDestination(for: Entry.self) { entry in
                destinationView(for: entry)
            }
            .sheet(isPresented: $showingAddCollection) {
                CollectionFormView()
            }
            .sheet(item: $collectionToEdit) { collection in
                CollectionFormView(collection: collection)
            }
        }
    }
}
