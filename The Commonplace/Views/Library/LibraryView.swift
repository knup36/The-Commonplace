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
        let persons = allPersonTags.filter { $0.isPerson }
        switch currentPersonSort {
        case .name:
            return persons.sorted { $0.name < $1.name }
        case .entryCount:
            return persons.sorted { entryCount(for: $0) > entryCount(for: $1) }
        }
    }
    @Environment(\.modelContext) var modelContext
    @Environment(\.editMode) var editMode
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()
    @State private var showingAddCollection = false
    @State private var currentSort: CollectionSort = .custom
    @State private var currentTagSort: TagSort = .name
    @State private var currentPersonSort: TagSort = .name
    @State private var collectionToEdit: Collection? = nil
    @State private var reorderedCollections: [Collection] = []
    @State private var isEditingGroups = false
    @StateObject private var groupService = TagGroupService.shared
    
    var style: any AppThemeStyle { themeManager.style }
    
    var isNonDefaultSort: Bool {
        if selectedTab == 0 { return currentSort != .custom }
        if selectedTab == 3 { return currentTagSort != .name }
        if selectedTab == 2 { return currentPersonSort != .name }
        return false
    }
    
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
            return reorderedCollections.filter { !$0.isFolio }
        case .name:
            return allCollections.filter { !$0.isFolio }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .entryCount:
            return allCollections.filter { !$0.isFolio }.sorted { entryCount(for: $0) > entryCount(for: $1) }
        case .dateCreated:
            return allCollections.filter { !$0.isFolio }.sorted { $0.createdAt > $1.createdAt }
        case .recentlyModified:
            return allCollections.filter { !$0.isFolio }.sorted { latestEntry(for: $0) > latestEntry(for: $1) }
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
        let folioNames = Set(allTagObjects.filter { $0.isFolio }.map { $0.name })
        // Hide tags that are the sole filter in a Folio's filterTags
        let soloFolioTags = Set(allCollections.filter { collection in
            guard collection.isFolio else { return false }
            guard collection.filterTags.count == 1 else { return false }
            // Only hide if no other filter rules are active
            return collection.filterTypes.isEmpty &&
            collection.filterSearchText == nil &&
            collection.filterLocationLatitude == nil &&
            (DateFilterRange(rawValue: collection.filterDateRange) ?? .allTime) == .allTime
        }.flatMap { $0.filterTags })
        var tagCounts: [String: Int] = [:]
        for entry in allEntries {
            for tag in entry.tagNames where !tag.hasPrefix("@") && !folioNames.contains(tag) && !soloFolioTags.contains(tag) {
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
                        Text(selectedTab == 0 ? "Collections" : selectedTab == 1 ? "Folios" : selectedTab == 2 ? "People" : "Tags")
                            .font(style.typeLargeTitle)
                            .foregroundStyle(style.primaryText)
                            .padding(.leading, 8)
                        
                        Picker("", selection: $selectedTab) {
                            Text("Collections").tag(0)
                            Text("Folios").tag(1)
                            Text("People").tag(2)
                            Text("Tags").tag(3)
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
                                Image(systemName: iconForSort(currentSort)).font(style.typeCaption)
                                Text("Sorted by \(currentSort.rawValue)").font(style.typeCaption)
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
                            Button {
                                navigationPath.append(collection)
                            } label: {
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
                    if selectedTab == 3 {
                        LibraryTagsView(
                            allTags: allTags,
                            allTagObjects: allTagObjects,
                            style: style,
                            isEditingGroups: $isEditingGroups
                        )
                    }
                    
                    // People content
                    if selectedTab == 2 {
                        peopleContent
                    }
                    
                    // Folios content
                    if selectedTab == 1 {
                        foliosContent
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
                reorderedCollections = allCollections.filter { !$0.isFolio }.sorted { $0.order < $1.order }
            }
            .onChange(of: allCollections) {
                reorderedCollections = allCollections.filter { !$0.isFolio }.sorted { $0.order < $1.order }
            }
            .scrollContentBackground(.hidden)
            .background(style.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EmptyView()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if selectedTab != 3 {
                            Menu {
                                if selectedTab == 0 {
                                    Picker("Sort", selection: $currentSort) {
                                        ForEach(CollectionSort.allCases, id: \.self) { sort in
                                            Label(sort.rawValue, systemImage: iconForSort(sort))
                                                .tag(sort)
                                        }
                                    }
                                } else if selectedTab == 2 {
                                    Picker("Sort", selection: $currentPersonSort) {
                                        Label("Name", systemImage: "textformat.abc").tag(TagSort.name)
                                        Label("Entry Count", systemImage: "number").tag(TagSort.entryCount)
                                    }
                                } else {
                                    Text("Sorted by Name")
                                        .foregroundStyle(style.accent)
                                }
                            } label: {
                                Image(systemName: isNonDefaultSort ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down")
                                    .foregroundStyle(style.accent)
                            }
                        }
                        if selectedTab == 0 {
                            Button {
                                showingAddCollection = true
                            } label: {
                                Image(systemName: "plus")
                                    .foregroundStyle(style.accent)
                            }
                        }
                        if selectedTab == 3 && !groupService.groupOrder.isEmpty {
                            Button(isEditingGroups ? "Done" : "Edit") {
                                isEditingGroups.toggle()
                            }
                            .foregroundStyle(style.accent)
                        }
                    }
                }
            }
            .navigationDestination(for: Collection.self) { collection in
                CollectionDetailView(collection: collection)
            }
            .navigationDestination(for: Entry.self) { entry in
                NavigationRouter.destination(for: entry)
            }
            .navigationDestination(for: Tag.self) { tag in
                PersonDetailView(tag: tag)
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
    
    
    // MARK: - Folios Content
    
    var allFolios: [Collection] {
        allCollections
            .filter { $0.isFolio }
            .sorted { $0.name < $1.name }
    }
    
    @ViewBuilder
    var foliosContent: some View {
        if allFolios.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(style.tertiaryText)
                Text("No Folios Yet")
                    .font(style.typeTitle3)
                    .foregroundStyle(style.secondaryText)
                Text("Promote a tag to a Folio to see it here")
                    .font(style.typeCaption)
                    .foregroundStyle(style.tertiaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                spacing: 16
            ) {
                ForEach(allFolios) { folio in
                    Button {
                        navigationPath.append(folio)
                    } label: {
                        folioGridCell(folio: folio)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
    }
    
    func folioGridCell(folio: Collection) -> some View {
        ZStack {
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(white: 0.85),
                            Color(white: 0.6),
                            Color(white: 0.85),
                            Color(white: 0.5),
                            Color(white: 0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .background(Color(hex: folio.colorHex).opacity(0.2))
                .clipShape(Capsule())
                .frame(height: 64)
            VStack(spacing: 3) {
                Text(folio.folioEmoji ?? "◆")
                    .font(.system(size: 24))
                Text(folio.name)
                    .font(style.typeCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(style.primaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
        }
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
                    .font(style.typeTitle3)
                    .foregroundStyle(style.secondaryText)
                Text("Tag people on your entries to see them here")
                    .font(style.typeCaption)
                    .foregroundStyle(style.tertiaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                spacing: 20
            ) {
                ForEach(allPersons) { person in
                    Button {
                        navigationPath.append(person)
                    } label: {
                        personGridCell(person: person)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
    }
    
    func personGridCell(person: Tag) -> some View {
        let count = entryCount(for: person)
        return VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .strokeBorder(SharedTheme.goldRingGradient, lineWidth: 1.5)
                        .frame(width: 76, height: 76)
                    personAvatar(person: person, size: 73)
                }
                .frame(width: 76, height: 76)
                
                if count > 0 {
                    Text("\(count)")
                        .font(style.typeCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(style.accent)
                        .clipShape(Capsule())
                        .offset(x: 4, y: 4)
                }
            }
            
            Text(abbreviatedName(person.name))
                .font(style.typeCaption)
                .foregroundStyle(style.primaryText)
                .lineLimit(1)
                .multilineTextAlignment(.center)
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
//MARK: HELPERS

func abbreviatedName(_ name: String) -> String {
    guard name.count > 12 else { return name }
    let parts = name.components(separatedBy: " ")
    guard parts.count >= 2,
          let lastName = parts.last,
          let lastInitial = lastName.first else { return name }
    let firstName = parts.dropLast().joined(separator: " ")
    return "\(firstName) \(lastInitial)."
}
