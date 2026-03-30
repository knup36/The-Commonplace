import SwiftUI
import SwiftData
import CoreLocation

// MARK: - LibraryView
// Combined Collections, Tags, and People view with a segmented picker.
// Follows the same single-ScrollView pattern as TodayView for stable layout.
// Screen: Library tab (4th tab)

struct LibraryView: View {
    @Query var allCollections: [Collection]
    @Query var allEntries: [Entry]
    @Query var allEntryTags: [Entry]
    @Query var allTagObjects: [Tag]
    @Query var allPersonTags: [Tag]

    var allPersons: [Tag] {
        allPersonTags.filter { $0.isPerson }.sorted { $0.name < $1.name }
    }
    @Environment(\.modelContext) var modelContext
    @Environment(\.editMode) var editMode
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()
    @State private var showingAddCollection = false
    @State private var currentSort: CollectionSort = .custom
    @State private var currentTagSort: TagSort = .name
    @State private var collectionToEdit: Collection? = nil
    @State private var reorderedCollections: [Collection] = []
    
    var style: any AppThemeStyle { themeManager.style }
    
    // MARK: - Collections logic
    
    enum CollectionSort: String, CaseIterable {
        case custom = "Custom"
        case name = "Name"
        case entryCount = "Entry Count"
        case dateCreated = "Date Created"
        case recentlyModified = "Recently Modified"
    }
    enum TagSort: String, CaseIterable {
        case name = "Name"
        case entryCount = "Entry Count"
    }
    
    var displayedCollections: [Collection] {
        switch currentSort {
        case .custom:
            return reorderedCollections
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
            for tag in entry.tagNames where !tag.hasPrefix("@") {
                tagCounts[tag, default: 0] += 1
            }
        }
        let mapped = tagCounts.map { (tag: $0.key, count: $0.value) }
        switch currentTagSort {
        case .name:
            return mapped.sorted { $0.tag < $1.tag }
        case .entryCount:
            return mapped.sorted { $0.count > $1.count }
        }
    }
    
    // MARK: - People logic
    
    func entryCount(for person: Tag) -> Int {
        allEntries.filter { $0.tagNames.contains("@\(person.name)") }.count
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                style.background.ignoresSafeArea()
                List {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(selectedTab == 0 ? "Collections" : selectedTab == 1 ? "Tags" : "People")
                            .font(style.usesSerifFonts
                                  ? .system(size: 34, weight: .bold, design: .serif)
                                  : .largeTitle.bold())
                            .foregroundStyle(style.primaryText)
                            .padding(.leading, 8)
                        
                        Picker("", selection: $selectedTab) {
                            Text("Collections").tag(0)
                            Text("Tags").tag(1)
                            Text("People").tag(2)
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
                                    Label(collection.isPinned ? "Unbookmark" : "Bookmark", systemImage: collection.isPinned ? "bookmark.slash.fill" : "bookmark.fill")
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
                            var reordered = reorderedCollections.isEmpty
                                ? allCollections.sorted { $0.order < $1.order }
                                : reorderedCollections
                            reordered.move(fromOffsets: from, toOffset: to)
                            for (index, collection) in reordered.enumerated() {
                                if !collection.isSystem {
                                    collection.order = index
                                }
                            }
                            reorderedCollections = reordered
                            try? modelContext.save()
                        }
                    }
                    
                    // MARK: Tags content
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
                        }
                        ForEach(allTags, id: \.tag) { item in
                            ZStack {
                                NavigationLink(destination: TagFeedView(tag: item.tag)) {
                                    EmptyView()
                                }
                                .opacity(0)
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
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading) {
                                Button {
                                    if let tag = allTagObjects.first(where: { $0.name == item.tag }) {
                                        tag.isPinned.toggle()
                                    }
                                } label: {
                                    let isPinned = allTagObjects.first(where: { $0.name == item.tag })?.isPinned == true
                                    Label(
                                        isPinned ? "Unbookmark" : "Bookmark",
                                        systemImage: isPinned ? "bookmark.slash.fill" : "bookmark.fill"
                                    )
                                }
                                .tint(.orange)
                            }
                        }
                    }
                    
                    // People content
                    if selectedTab == 2 {
                        peopleContent
                    }
                    
                }
            }
            .listStyle(.plain)
            .onAppear {
                let sorted = allCollections.sorted { $0.order < $1.order }
                // Fix collections that all have order 0
                let needsInit = sorted.allSatisfy { $0.order == 0 }
                if needsInit {
                    for (index, collection) in sorted.enumerated() {
                        collection.order = index
                    }
                    try? modelContext.save()
                }
                reorderedCollections = allCollections.sorted { $0.order < $1.order }
            }
            .onChange(of: allCollections) {
                print("allCollections changed, reorderedCollections.isEmpty: \(reorderedCollections.isEmpty)")
                if reorderedCollections.isEmpty {
                    reorderedCollections = allCollections.sorted { $0.order < $1.order }
                }
            }
            .scrollContentBackground(.hidden)
            .background(style.background.ignoresSafeArea())
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
                            if selectedTab == 0 {
                                Picker("Sort", selection: $currentSort) {
                                    ForEach(CollectionSort.allCases, id: \.self) { sort in
                                        Label(sort.rawValue, systemImage: iconForSort(sort))
                                            .tag(sort)
                                    }
                                }
                            } else if selectedTab == 1 {
                                Picker("Sort", selection: $currentTagSort) {
                                    Label("Name", systemImage: "textformat.abc").tag(TagSort.name)
                                    Label("Entry Count", systemImage: "number").tag(TagSort.entryCount)
                                }
                            } else {
                                // People — always sorted by name for now
                                Text("Sorted by Name")
                                    .foregroundStyle(.secondary)
                            }
                        } label: {
                            Image(systemName: (selectedTab == 0 ? currentSort != .custom : currentTagSort != .name) ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down")
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
        .background(style.background)
    }
    
    
    // MARK: - People Content
    
    @ViewBuilder
    var peopleContent: some View {
        if allPersons.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "person.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(style.tertiaryText)
                Text("No People Yet")
                    .font(.headline)
                    .foregroundStyle(style.secondaryText)
                Text("Tag people on your entries to see them here")
                    .font(.caption)
                    .foregroundStyle(style.tertiaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        ForEach(allPersons) { person in
            ZStack {
                NavigationLink(destination: PersonDetailView(tag: person)) {
                    EmptyView()
                }
                .opacity(0)
                HStack(spacing: 12) {
                    personAvatar(person: person, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.name)
                            .font(style.usesSerifFonts
                                  ? .system(.body, design: .serif)
                                  : .body)
                            .fontWeight(.medium)
                            .foregroundStyle(style.primaryText)
                        if let bio = person.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.caption)
                                .foregroundStyle(style.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    let count = entryCount(for: person)
                    Text("\(count)")
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
            .buttonStyle(.plain)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    withAnimation { person.isPinned.toggle() }
                } label: {
                    Label(person.isPinned ? "Unbookmark" : "Bookmark",
                          systemImage: person.isPinned ? "bookmark.slash.fill" : "bookmark.fill")
                }
                .tint(.orange)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    modelContext.delete(person)
                    try? modelContext.save()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
    
    // MARK: - Person Avatar
    
    func personAvatar(person: Tag, size: CGFloat) -> some View {
        Group {
            if let path = person.profilePhotoPath,
               let data = MediaFileManager.load(path: path),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(style.accent.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(person.name.prefix(1)).uppercased())
                            .font(.system(size: size * 0.4, weight: .semibold))
                            .foregroundStyle(style.accent)
                    )
            }
        }
    }
}
