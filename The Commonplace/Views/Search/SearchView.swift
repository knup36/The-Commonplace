// SearchView.swift
// Commonplace
//
// Global search tab. Shows recent searches when idle, live results when typing.
//
// Results grouped in order: People → Tags → Collections → Entries
// Each section truncated at 3 results.
//
// Search bar pinned to bottom above tab bar via safeAreaInset.
// Results scroll above it.
//
// Recent searches stored in UserDefaults, max 15, newest at bottom.
// Searches saved on submit or when tapping a recent search.
//
// Entries searched via SearchIndex (GRDB FTS5).
// People, Tags, Collections matched in memory.
// Debounced at 150ms.

import SwiftUI
import SwiftData

struct SearchView: View {
    @Query var allEntries: [Entry]
    @Query var allPersonTags: [Tag]
    
    var allPersons: [Tag] {
        allPersonTags.filter { $0.isPerson }.sorted { $0.name < $1.name }
    }
    @Query var allTags: [Tag]
    @Query var allCollections: [Collection]
    @EnvironmentObject var themeManager: ThemeManager
    
    var style: any AppThemeStyle { themeManager.style }
    
    @State private var query = ""
    @State private var recentSearches: [String] = []
    @State private var searchTask: Task<Void, Never>? = nil
    
    // Result sets
    @State private var matchingEntries: [Entry] = []
    @State private var taggedEntries: [Entry] = []
    @State private var mentionedEntries: [Entry] = []
    @State private var matchingPersons: [Tag] = []
    @State private var matchingTags: [Tag] = []
    @State private var matchingCollections: [Collection] = []
    
    private let maxResults = 3
    private let recentSearchesKey = "recentSearches"
    private let maxRecentSearches = 15
    
    var isSearching: Bool { !query.isEmpty }
    var hasResults: Bool {
        !matchingPersons.isEmpty || !matchingTags.isEmpty ||
        !matchingCollections.isEmpty || !matchingEntries.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                style.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Title
                        Text("Search")
                            .font(style.typeLargeTitle)
                            .foregroundStyle(style.primaryText)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 20)
                        
                        if isSearching {
                            searchResults
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        } else {
                            recentSearchesView
                                .transition(.opacity)
                        }
                        
                        Color.clear.frame(height: 80)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search entries, people, tags...")
            .onChange(of: query) { _, newValue in
                scheduleSearch(newValue)
            }
            .onSubmit(of: .search) {
                saveRecentSearch(query)
            }
            .navigationBarTitleDisplayMode(.inline)
            .animation(.easeOut(duration: 0.2), value: isSearching)
            .animation(.easeOut(duration: 0.15), value: matchingEntries.count)
        }
        .onAppear {
            loadRecentSearches()
        }
    }
    
    
    // MARK: - Recent Searches
    
    var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if recentSearches.isEmpty {
                emptyRecentState
            } else {
                HStack {
                    Text("Recent")
                        .font(style.typeTitle3)
                        .foregroundStyle(style.secondaryText)
                    Spacer()
                    Button("Clear") {
                        recentSearches = []
                        saveRecentSearches()
                    }
                    .font(.subheadline)
                    .foregroundStyle(style.accent)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                
                let reversed = recentSearches.reversed()
                ForEach(Array(reversed.enumerated()), id: \.offset) { index, search in
                    let opacity = opacityForIndex(index, total: recentSearches.count)
                    
                    Button {
                        query = search
                        scheduleSearch(search)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundStyle(style.tertiaryText)
                            Text(search)
                                .font(style.typeBody)
                                .foregroundStyle(style.primaryText)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .font(.caption)
                                .foregroundStyle(style.tertiaryText)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .opacity(opacity)
                    
                    if index < recentSearches.count - 1 {
                        Divider()
                            .overlay(style.tertiaryText.opacity(0.3))
                            .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
    
    func opacityForIndex(_ index: Int, total: Int) -> Double {
        guard total > 1 else { return 1.0 }
        let minOpacity = 0.2
        let step = (1.0 - minOpacity) / Double(total - 1)
        return 1.0 - step * Double(index)
    }
    
    var emptyRecentState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(style.tertiaryText)
            Text("No recent searches")
                .font(style.typeTitle3)
                .foregroundStyle(style.secondaryText)
            Text("Your searches will appear here.")
                .font(style.typeCaption)
                .foregroundStyle(style.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
    
    // MARK: - Search Results
    
    var searchResults: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !hasResults {
                noResultsState
            } else {
                if !matchingPersons.isEmpty {
                    peopleResultsSection
                    resultDivider
                }
                if !matchingTags.isEmpty {
                    tagsResultsSection
                    resultDivider
                }
                if !matchingCollections.isEmpty {
                    collectionsResultsSection
                    resultDivider
                }
                if !matchingEntries.isEmpty {
                    entriesResultsSection
                }
            }
        }
    }
    
    var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(style.tertiaryText)
            Text("No results for \"\(query)\"")
                .font(style.typeTitle3)
                .foregroundStyle(style.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
    
    var resultDivider: some View {
        Divider()
            .overlay(style.tertiaryText.opacity(0.3))
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
    }
    
    // MARK: - People Results
    
    var peopleResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("People", icon: "person.fill")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(matchingPersons.prefix(maxResults)) { person in
                        NavigationLink(destination: PersonDetailView(tag: person)) {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .strokeBorder(SharedTheme.goldRingGradient, lineWidth: 1.5)
                                        .frame(width: 58, height: 58)
                                    personAvatar(person: person, size: 54)
                                }
                                Text(person.name)
                                    .font(style.typeCaption)
                                    .foregroundStyle(style.secondaryText)
                                    .lineLimit(1)
                            }
                            .frame(width: 64)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 4)
    }
    
    // MARK: - Tags Results
    
    var tagsResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Tags", icon: "tag.fill")
            
            FlowLayout(spacing: 8, maxRows: 2) {
                ForEach(matchingTags.prefix(maxResults), id: \.name) { tag in
                    NavigationLink(destination: TagFeedView(tag: tag.name)) {
                        HStack(spacing: 4) {
                            Text(tag.name)
                                .font(style.typeCaption)
                                .foregroundStyle(style.accent)
                            Text("(\(allEntries.filter { $0.tagNames.contains(tag.name) }.count))")
                                .font(style.typeCaption)
                                .foregroundStyle(style.tertiaryText)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(style.accent.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(style.accent.opacity(0.25), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 4)
    }
    
    // MARK: - Collections Results
    
    var collectionsResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Collections", icon: "magazine.fill")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(matchingCollections.prefix(maxResults)) { collection in
                        NavigationLink(destination: CollectionDetailView(collection: collection)) {
                            let accent = Color(hex: collection.colorHex)
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(accent.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(accent.opacity(0.3), lineWidth: 0.5)
                                    )
                                VStack(spacing: 5) {
                                    Image(systemName: collection.icon)
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundStyle(accent)
                                    Text(collection.name)
                                        .font(style.typeCaption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(style.primaryText)
                                        .lineLimit(1)
                                    Text("\(allEntries.filter { collectionMatches(entry: $0, collection: collection) }.count)")
                                        .font(style.typeCaption)
                                        .foregroundStyle(style.tertiaryText)
                                }
                                .padding(8)
                            }
                            .frame(width: 80, height: 80)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 4)
    }
    
    // MARK: - Entries Results
    
    var entriesResultsSection: some View {
        let maxEntries = 10
        let totalCount = matchingEntries.count
        let displayTagged = Array(taggedEntries.prefix(maxEntries))
        let remainingSlots = maxEntries - displayTagged.count
        let displayMentioned = Array(mentionedEntries.prefix(max(0, remainingSlots)))
        
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Entries", icon: "doc.text.fill")
            
            VStack(spacing: 0) {
                if !displayTagged.isEmpty {
                    groupLabel("Tagged")
                    VStack(spacing: 8) {
                        ForEach(displayTagged) { entry in
                            NavigationLink(destination: destinationView(for: entry)) {
                                EntryRowView(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 8)
                }
                
                if !displayMentioned.isEmpty {
                    groupLabel("Mentioned in entries")
                    VStack(spacing: 8) {
                        ForEach(displayMentioned) { entry in
                            NavigationLink(destination: destinationView(for: entry)) {
                                EntryRowView(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 8)
                }
                
                if totalCount > maxEntries {
                    NavigationLink(destination: SearchResultsView(query: query, allEntries: allEntries)) {
                        HStack {
                            Text("See all \(totalCount) results")
                                .font(style.typeBodySecondary)
                                .foregroundStyle(style.accent)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(style.tertiaryText)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    // MARK: - Section Header
    
    func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(style.accent)
            Text(title)
                .font(style.typeBodySecondary)
                .fontWeight(.semibold)
                .foregroundStyle(style.secondaryText)
        }
        .padding(.horizontal, 20)
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
                    .fill(style.accent.opacity(0.15))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(person.name.prefix(1)).uppercased())
                            .font(.system(size: size * 0.38, weight: .light))
                            .foregroundStyle(style.accent)
                    )
            }
        }
    }
    
    // MARK: - Search Logic
    
    func scheduleSearch(_ newQuery: String) {
        searchTask?.cancel()
        guard !newQuery.isEmpty else {
            matchingEntries = []
            matchingPersons = []
            matchingTags = []
            matchingCollections = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms debounce
            guard !Task.isCancelled else { return }
            await runSearch(newQuery)
        }
    }
    
    @MainActor
    func runSearch(_ q: String) {
        let lower = q.lowercased()
        
        // Entries — via FTS index, split into tagged vs mentioned
        let matchedIDs = SearchIndex.shared.search(query: q)
        let allMatched = allEntries
            .filter { matchedIDs.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
        
        // Tagged — entry has the query as a tag or person tag
        let tagString = "@\(q.lowercased())"
        taggedEntries = allMatched.filter { entry in
            entry.tagNames.contains { $0.lowercased() == lower || $0.lowercased() == tagString }
        }
        let taggedIDs = Set(taggedEntries.map { $0.id })
        mentionedEntries = allMatched.filter { !taggedIDs.contains($0.id) }
        matchingEntries = allMatched
        
        // People — in memory name match
        matchingPersons = allPersons.filter {
            $0.name.lowercased().contains(lower)
        }
        
        // Tags — in memory name match (exclude @ person tags)
        matchingTags = allTags.filter {
            !$0.isPerson &&
            $0.name.lowercased().contains(lower)
        }
        
        // Collections — in memory name match
        matchingCollections = allCollections.filter {
            $0.name.lowercased().contains(lower)
        }
    }
    
    // MARK: - Recent Searches
    
    func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }
    
    func saveRecentSearch(_ search: String) {
        let trimmed = search.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        recentSearches.removeAll { $0 == trimmed }
        recentSearches.append(trimmed)
        if recentSearches.count > maxRecentSearches {
            recentSearches.removeFirst(recentSearches.count - maxRecentSearches)
        }
        saveRecentSearches()
    }
    
    func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: recentSearchesKey)
    }
    
    
    // MARK: - Helpers
    
    func groupLabel(_ title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: title.contains("Tagged") ? "person.fill" : "quote.opening")
                .font(.system(size: 11))
            Text(title)
                .font(style.typeBodySecondary)
                .fontWeight(.medium)
        }
        .foregroundStyle(style.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}
