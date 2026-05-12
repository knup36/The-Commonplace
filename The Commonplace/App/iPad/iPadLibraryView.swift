// iPadLibraryView.swift
// Commonplace
//
// iPad Library tab — content column of NavigationSplitView.
//
// Owns a NavigationStack that navigates internally:
//   Root: Collections/Folios/People/Tags list (segmented picker)
//   Push: CollectionDetailView, PersonDetailView, or iPadTagFeedPanel
//         when the user taps a collection, person, or tag.
//
// selectedEntry is owned by iPadRootView and passed as a Binding.
// When the user taps an entry in any feed view, selectedEntry is set
// and iPadLibraryDetailPanel renders it as a floating card.
// This keeps the detail column purely for entry cards — never feeds.
//
// The LibrarySelection enum is retained for internal navigationDestination
// routing only — it is no longer shared with the detail panel.
//
// iPhone: completely unaffected — ContentView still shows LibraryView.

import SwiftUI
import SwiftData

// MARK: - Library Navigation Destination
// Used internally by iPadLibraryView's NavigationStack.

enum LibraryDestination: Hashable {
    case collection(Collection)
    case person(Tag)
    case tag(String)
}

// MARK: - iPadLibraryView

struct iPadLibraryView: View {
    @Binding var selectedEntry: Entry?
    
    @Query var allCollections: [Collection]
    @Query var allEntries: [Entry]
    @Query var allTagObjects: [Tag]
    @Query var allPersonTags: [Tag]
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedTab = 0
    @State private var currentSort: LibraryView.CollectionSort = .custom
    @State private var currentPersonSort: LibraryView.TagSort = .name
    @State private var currentTagSort: LibraryView.TagSort = .name
    @State private var reorderedCollections: [Collection] = []
    @State private var showingAddCollection = false
    @State private var collectionToEdit: Collection? = nil
    @StateObject private var groupService = TagGroupService.shared
    @State private var isEditingGroups = false
    @State private var navigationPath = NavigationPath()
    
    var style: any AppThemeStyle { themeManager.style }
    
    // MARK: - Derived data (mirrors LibraryView logic)
    
    var displayedCollections: [Collection] {
        switch currentSort {
        case .custom:
            return reorderedCollections.filter { !$0.isFolio }
        case .name:
            return allCollections.filter { !$0.isFolio }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .entryCount:
            return allCollections.filter { !$0.isFolio }
                .sorted { entryCount(for: $0) > entryCount(for: $1) }
        case .dateCreated:
            return allCollections.filter { !$0.isFolio }.sorted { $0.createdAt > $1.createdAt }
        case .recentlyModified:
            return allCollections.filter { !$0.isFolio }
                .sorted { latestEntry(for: $0) > latestEntry(for: $1) }
        }
    }
    
    var allFolios: [Collection] {
        allCollections.filter { $0.isFolio }.sorted { $0.name < $1.name }
    }
    
    var allPersons: [Tag] {
        let persons = allPersonTags.filter { $0.isPerson }
        switch currentPersonSort {
        case .name: return persons.sorted { $0.name < $1.name }
        case .entryCount: return persons.sorted { personEntryCount($0) > personEntryCount($1) }
        }
    }
    
    var allTags: [(tag: String, count: Int)] {
        let folioNames = Set(allTagObjects.filter { $0.isFolio }.map { $0.name })
        let soloFolioTags = Set(allCollections.filter { collection in
            guard collection.isFolio, collection.filterTags.count == 1 else { return false }
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
        case .name: return mapped.sorted { $0.tag < $1.tag }
        case .entryCount: return mapped.sorted { $0.count > $1.count }
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
    
    func personEntryCount(_ person: Tag) -> Int {
        allEntries.filter { $0.tagNames.contains("@\(person.name)") }.count
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                style.background.ignoresSafeArea()
                List {
                    // Header: controls + segmented picker
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center) {
                            Spacer()
                            HStack(spacing: 12) {
                                if selectedTab != 3 {
                                    Menu {
                                        if selectedTab == 0 {
                                            Picker("Sort", selection: $currentSort) {
                                                ForEach(LibraryView.CollectionSort.allCases, id: \.self) { sort in
                                                    Text(sort.rawValue).tag(sort)
                                                }
                                            }
                                        } else if selectedTab == 2 {
                                            Picker("Sort", selection: $currentPersonSort) {
                                                Label("Name", systemImage: "textformat.abc").tag(LibraryView.TagSort.name)
                                                Label("Entry Count", systemImage: "number").tag(LibraryView.TagSort.entryCount)
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "arrow.up.arrow.down")
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
                                    .font(style.typeBody)
                                }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    
                    // Segmented picker
                    Picker("", selection: $selectedTab) {
                        Text("Collections").tag(0)
                        Text("Folios").tag(1)
                        Text("People").tag(2)
                        Text("Tags").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    
                    switch selectedTab {
                    case 0: collectionsContent
                    case 1: foliosContent
                    case 2: peopleContent
                    case 3: tagsContent
                    default: EmptyView()
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { initCollectionOrder() }
            .onChange(of: allCollections) {
                reorderedCollections = allCollections.filter { !$0.isFolio }
                    .sorted { $0.order < $1.order }
            }
            .sheet(isPresented: $showingAddCollection) {
                CollectionFormView()
            }
            .sheet(item: $collectionToEdit) { collection in
                CollectionFormView(collection: collection)
            }
            // MARK: - Navigation destinations
            .navigationDestination(for: Collection.self) { collection in
                CollectionDetailView(collection: collection, onSelectEntry: { entry in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedEntry = entry
                    }
                })
            }
            .navigationDestination(for: Tag.self) { tag in
                PersonDetailView(tag: tag, onSelectEntry: { entry in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedEntry = entry
                    }
                })
            }
            .navigationDestination(for: String.self) { tagName in
                TagFeedView(tag: tagName, onSelectEntry: { entry in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedEntry = entry
                    }
                })
            }
        }
    }
    
    // MARK: - Collections Content
    
    @ViewBuilder
    var collectionsContent: some View {
        ForEach(displayedCollections) { collection in
            NavigationLink(value: collection) {
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
                    Label(collection.isPinned ? "Unbookmark" : "Bookmark",
                          systemImage: collection.isPinned ? "bookmark.slash.fill" : "bookmark.fill")
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
            for (index, c) in reordered.enumerated() {
                if !c.isSystem { c.order = index }
            }
            reorderedCollections = reordered
            try? modelContext.save()
        }
    }
    
    // MARK: - Folios Content
    
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
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                spacing: 16
            ) {
                ForEach(allFolios) { folio in
                    NavigationLink(value: folio) {
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
                    AnyShapeStyle(LinearGradient(
                        colors: [Color(white: 0.85), Color(white: 0.6),
                                 Color(white: 0.85), Color(white: 0.5), Color(white: 0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )),
                    lineWidth: 1.5
                )
                .background(Color(hex: folio.colorHex).opacity(0.2))
                .clipShape(Capsule())
                .frame(height: 64)
            VStack(spacing: 3) {
                Text(folio.folioEmoji ?? "◆").font(.system(size: 22))
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
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
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
        let count = personEntryCount(person)
        return VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .strokeBorder(AnyShapeStyle(SharedTheme.goldRingGradient), lineWidth: 1.5)
                        .frame(width: 64, height: 64)
                    personAvatarView(person: person, size: 60)
                }
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
        }
    }
    
    func personAvatarView(person: Tag, size: CGFloat) -> some View {
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
    
    // MARK: - Tags Content
    
    @ViewBuilder
    var tagsContent: some View {
        LibraryTagsView(
            allTags: allTags,
            allTagObjects: allTagObjects,
            style: style,
            isEditingGroups: $isEditingGroups,
            onTagSelect: { tagName in
                navigationPath.append(tagName)
            }
        )
    }
    
    // MARK: - Helpers
    
    func initCollectionOrder() {
        let sorted = allCollections.sorted { $0.order < $1.order }
        let needsInit = sorted.allSatisfy { $0.order == 0 }
        if needsInit {
            for (index, c) in sorted.enumerated() { c.order = index }
            try? modelContext.save()
        }
        reorderedCollections = allCollections.filter { !$0.isFolio }
            .sorted { $0.order < $1.order }
    }
}
