// MediaDetailView.swift
// Commonplace
//
// Detail view for .media entries (movies and TV shows).
// Operates in two modes depending on whether TMDB metadata has been selected:
//
//   Empty state — shows a segmented Movie/TV picker and TMDB search.
//   The user searches, picks a result, and metadata is fetched and locked in.
//
//   Populated state — shows cover art, locked metadata (title, year, genre),
//   a status picker (Want to Watch / In Progress / Finished), 5-star rating,
//   a general notes field, and a timestamped media log for diary-style entries.
//
// TMDB metadata (title, year, genre, overview, cover art) is locked once selected.
// Status, rating, notes, and log entries are always editable.
//
// Media log entries are stored in entry.mediaLog as "ISO8601date::note text" strings,
// consistent with the stickyItems pattern used elsewhere in the app.

import SwiftUI
import SwiftData

struct MediaDetailView: View {
    @Bindable var entry: Entry
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    var style: any AppThemeStyle { themeManager.style }
    
    @StateObject private var editMode = EditModeManager()
    
    // MARK: - Search State
    @State private var selectedMediaType: TMDBMediaType = .movie
    @State private var searchQuery: String = ""
    @State private var searchResults: [TMDBSearchResult] = []
    @State private var isSearching: Bool = false
    @State private var searchError: String? = nil
    @State private var saveTask: Task<Void, Never>? = nil
    @State private var localRating: Int = 0
    @State private var localStatus: String = "wantTo"
    @State private var showingDeleteConfirmation = false
    
    // MARK: - Log State
    @State private var newLogText: String = ""
    @State private var showingLogInput: Bool = false
    
    // MARK: - Cover Art
    @State private var coverImage: UIImage? = nil
    
    // Whether metadata has been selected from TMDB
    var isPopulated: Bool { entry.mediaTitle != nil }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isPopulated {
                    populatedView
                } else {
                    emptySearchView
                }
            }
        }
        .environmentObject(editMode)
        .background(entry.type.cardColor(for: themeManager.current).ignoresSafeArea())
        .keyboardAvoiding()
        .navigationTitle(isPopulated ? "" : "New Media Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
                    if editMode.isEditing {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                editMode.exit()
                            }
                            .bold()
                            .foregroundStyle(entry.type.detailAccentColor(for: themeManager.current))
                        }
                    } else {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Menu {
                                Button {
                                    editMode.enter()
                                } label: {
                                    Label("Edit", systemImage: "rectangle.and.pencil.and.ellipsis")
                                }
                                Divider()
                                Button {
                                    withAnimation { entry.isPinned.toggle() }
                                } label: {
                                    Label(entry.isPinned ? "Remove Bookmark" : "Bookmark",
                                          systemImage: entry.isPinned ? "bookmark.fill" : "bookmark")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(entry.type.detailAccentColor(for: themeManager.current))
                            }
                        }
                    }
                }
        
        .onAppear {
            loadCoverImage()
            localRating = entry.mediaRating ?? 0
            localStatus = entry.mediaStatus ?? "wantTo"
        }
        .confirmationDialog("Delete this entry?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(entry)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    // MARK: - Empty / Search State
    
    var emptySearchView: some View {
        VStack(spacing: 24) {
            // Hero prompt
            VStack(spacing: 12) {
                Image(systemName: "film.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(entry.type.detailAccentColor(for: themeManager.current))
                Text("What are you watching?")
                    .font(style.typeTitle2)
                    .fontWeight(.bold)
                    .foregroundStyle(style.cardPrimaryText)
                Text("Search for a movie or TV show to get started.")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(style.cardSecondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.horizontal, 24)
            
            // Movie / TV picker
            Picker("Type", selection: $selectedMediaType) {
                Text("Movie").tag(TMDBMediaType.movie)
                Text("TV Show").tag(TMDBMediaType.tv)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .onChange(of: selectedMediaType) { _, _ in
                searchResults = []
                if !searchQuery.isEmpty { performSearch() }
            }
            
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(style.secondaryText)
                TextField("Search title...", text: $searchQuery)
                    .foregroundStyle(style.primaryText)
                    .autocorrectionDisabled()
                    .onSubmit { performSearch() }
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(style.secondaryText)
                    }
                }
            }
            .padding(12)
            .background(style.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)
            .onChange(of: searchQuery) { _, newValue in
                if newValue.isEmpty { searchResults = [] }
            }
            
            // Search button
            Button {
                performSearch()
            } label: {
                HStack {
                    if isSearching {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Search")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(entry.type.detailAccentColor(for: themeManager.current))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .disabled(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
            
            // Error
            if let error = searchError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
            }
            
            // Results
            if !searchResults.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Results")
                        .font(style.typeSectionHeader)
                        .foregroundStyle(style.cardSecondaryText)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                    
                    ForEach(searchResults) { result in
                        Button {
                            selectResult(result)
                        } label: {
                            searchResultRow(result)
                        }
                        .buttonStyle(.plain)
                        
                        if result.id != searchResults.last?.id {
                            Divider()
                                .padding(.leading, 24 + 56 + 12)
                        }
                    }
                }
            }
            
            Spacer(minLength: 40)
        }
    }
    
    // MARK: - Search Result Row
    
    func searchResultRow(_ result: TMDBSearchResult) -> some View {
        HStack(spacing: 12) {
            // Poster thumbnail
            AsyncImage(url: result.thumbnailURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(style.surface)
                    .overlay(
                        Image(systemName: "film")
                            .foregroundStyle(style.secondaryText)
                    )
            }
            .frame(width: 44, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(style.typeTitle3)
                    .fontWeight(.medium)
                    .foregroundStyle(style.cardPrimaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    if !result.year.isEmpty {
                        Text(result.year)
                            .font(style.typeCaption)
                            .foregroundStyle(style.cardSecondaryText)
                    }
                    Text(result.mediaType.displayName)
                        .font(style.typeCaption)
                        .foregroundStyle(style.cardSecondaryText)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(style.tertiaryText)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
    
    // MARK: - Populated View
    
    var populatedView: some View {
        VStack(spacing: 0) {
            // Cover art header
            coverArtHeader
            
            VStack(spacing: 20) {
                statusSection
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Notes
                notesSection
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Media log
                logSection
                
                // Tags + People
                                let mediaAccent = entry.type.detailAccentColor(for: themeManager.current)
                                if editMode.isEditing {
                                    PersonInputView(tags: $entry.tagNames, accentColor: mediaAccent, style: style)
                                        .padding(.horizontal, 20)
                                    TagInputView(tags: $entry.tagNames, accentColor: mediaAccent, style: style)
                                        .padding(.horizontal, 20)
                                        .padding(.top, 4)
                                } else {
                                    let hasPeople = entry.tagNames.contains { $0.hasPrefix("@") }
                                    let hasTags = entry.tagNames.contains { !$0.hasPrefix("@") }
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            if entry.isPinned {
                                                Image(systemName: "bookmark.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(mediaAccent)
                                                if hasPeople || hasTags {
                                                    pipe
                                                }
                                            }
                                            if hasPeople {
                                                PersonInputView(tags: $entry.tagNames, accentColor: mediaAccent, style: style)
                                                if hasTags {
                                                    pipe
                                                }
                                            }
                                            if hasTags {
                                                TagInputView(tags: $entry.tagNames, accentColor: mediaAccent, style: style)
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Metadata footer
                EntryMetadataFooter(entry: entry, style: style, accentColor: entry.type.detailAccentColor(for: themeManager.current))                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Cover Art Header
    
    var coverArtHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            
            // Poster — rectangular 2:3
            Group {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 125, height: 188)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(style.cardDivider)
                        .frame(width: 125, height: 188)
                        .overlay(
                            Image(systemName: "film.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(style.cardSecondaryText)
                        )
                }
            }
            
            // Metadata column
            VStack(alignment: .leading, spacing: 5) {
                if let title = entry.mediaTitle {
                    Text(title)
                        .font(style.typeTitle3)
                        .fontWeight(.bold)
                        .foregroundStyle(style.cardPrimaryText)
                        .lineLimit(3)
                }
                
                Spacer().frame(height: 4)
                
                if let year = entry.mediaYear, !year.isEmpty {
                    Text(year)
                        .font(style.typeBodySecondary)
                        .foregroundStyle(style.cardSecondaryText)
                }
                
                if let type = entry.mediaType {
                    Text(type == "tv" ? "Television Series" : "Movie")
                        .font(style.typeBodySecondary)
                        .foregroundStyle(style.cardSecondaryText)
                }
                
                if let genre = entry.mediaGenre, !genre.isEmpty {
                    Text(genre)
                        .font(style.typeBodySecondary)
                        .foregroundStyle(style.cardSecondaryText)
                }
                
                if let runtime = entry.mediaRuntime, entry.mediaType == "movie" {
                    let hours = runtime / 60
                    let mins = runtime % 60
                    Text(hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m")
                        .font(style.typeBodySecondary)
                        .foregroundStyle(style.cardSecondaryText)
                }
                
                if let seasons = entry.mediaSeasons, entry.mediaType == "tv" {
                    Text("\(seasons) \(seasons == 1 ? "Season" : "Seasons")")
                        .font(style.typeBodySecondary)
                        .foregroundStyle(style.cardSecondaryText)
                }
                
                // Star rating inline
                Spacer().frame(height: 4)
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: localRating >= star ? "star.fill" : "star")
                            .font(.system(size: 16))
                            .foregroundStyle(localRating >= star ? .yellow : style.cardMetadataText)
                            .onTapGesture {
                                                            guard editMode.isEditing else { return }
                                                            localRating = localRating == star ? 0 : star
                                                            scheduleSave()
                                                        }
                    }
                }
                .transaction { $0.animation = nil }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
    
    // MARK: - Status Section
    
    var statusSection: some View {
        let statuses: [(label: String, value: String, icon: String)] = [
            ("Watchlist", "wantTo", "bookmark"),
            ("In Progress", "inProgress", "play.circle"),
            ("Finished", "finished", "checkmark.circle")
        ]
        return HStack(spacing: 0) {
                    ForEach(statuses, id: \.value) { item in
                        let isSelected = localStatus == item.value
                        let color = statusColor(for: item.value)
                        let inactiveColor = entry.type.detailAccentColor(for: themeManager.current)
                        Button {
                            guard editMode.isEditing else { return }
                            localStatus = item.value
                            scheduleSave()
                        } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isSelected ? "\(item.icon).fill" : item.icon)
                            .font(style.typeCaption)
                        Text(item.label)
                            .font(style.typeLabel)
                    }
                    .foregroundStyle(isSelected ? color : inactiveColor.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(isSelected ? color.opacity(0.15) : Color.clear)
                }
                .buttonStyle(.plain)
                if item.value != "finished" {
                    Divider()
                        .frame(height: 16)
                        .overlay(style.tertiaryText.opacity(0.3))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(entry.type.detailAccentColor(for: themeManager.current).opacity(0.3), lineWidth: 0.5)
        )
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    func statusColor(for value: String) -> Color {
        return mediaStatusColor(for: value, theme: themeManager.current)
    }
    
    // MARK: - Notes Section
    
    var notesSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("NOTES")
                    .font(style.typeSectionHeader)
                    .foregroundStyle(style.cardSecondaryText)
                    .padding(.horizontal, 20)
                
                if editMode.isEditing {
                    CommonplaceTextEditor(
                        text: Binding(
                            get: { entry.text },
                            set: { entry.text = $0; try? modelContext.save() }
                        ),
                        placeholder: "Add notes about this title...",
                        usesSerifFont: false
                    )
                    .padding(.horizontal, 20)
                } else if !entry.text.isEmpty {
                    Text(entry.text)
                        .font(style.typeBody)
                        .foregroundStyle(style.cardPrimaryText)
                        .padding(.horizontal, 20)
                }
            }
        }
    
    // MARK: - Log Section
    
    var logSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                            Text("LOG")
                                .font(style.typeSectionHeader)
                                .foregroundStyle(style.cardSecondaryText)
                            Spacer()
                            if editMode.isEditing {
                                Button {
                                    showingLogInput.toggle()
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(entry.type.detailAccentColor(for: themeManager.current))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
            
            // New log entry input
            if showingLogInput {
                VStack(spacing: 8) {
                    CommonplaceTextEditor(
                        text: $newLogText,
                        placeholder: "What are you thinking?",
                        usesSerifFont: false
                    )
                    .padding(.horizontal, 20)
                    
                    HStack {
                        Spacer()
                        Button("Cancel") {
                            newLogText = ""
                            showingLogInput = false
                        }
                        .foregroundStyle(style.secondaryText)
                        .padding(.trailing, 8)
                        
                        Button("Add") {
                            appendLogEntry()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(entry.type.detailAccentColor(for: themeManager.current))
                        .disabled(newLogText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 8)
                .background(style.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
            }
            
            // Existing log entries
            if entry.mediaLog.isEmpty && !showingLogInput && editMode.isEditing {
                            Text("No log entries yet. Tap + to add one.")
                                .font(style.typeBodySecondary)
                                .foregroundStyle(style.cardMetadataText)
                                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(entry.mediaLog.reversed(), id: \.self) { logEntry in
                        let parts = logEntry.components(separatedBy: "::")
                        if parts.count == 2 {
                            logEntryRow(dateString: parts[0], text: parts[1])
                        }
                    }
                }
            }
        }
    }
    
    func logEntryRow(dateString: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let date = ISO8601DateFormatter().date(from: dateString) {
                Text(date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))
                    .font(style.typeCaption)
                    .foregroundStyle(style.cardMetadataText)
            }
            Text(text)
                .font(style.typeBody)
                .foregroundStyle(style.cardPrimaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Actions
    
    func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSearching = true
        searchError = nil
        searchResults = []
        
        Task {
            do {
                let results = try await TMDBService.search(query: searchQuery, type: selectedMediaType)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                    if results.isEmpty {
                        searchError = "No results found. Try a different title."
                    }
                }
            } catch {
                await MainActor.run {
                    searchError = "Search failed. Check your connection and try again."
                    isSearching = false
                }
            }
        }
    }
    
    func selectResult(_ result: TMDBSearchResult) {
        Task {
            // Fetch full detail for genres
            var detail: TMDBDetail? = nil
            do {
                detail = try await TMDBService.fetchDetail(id: result.id, type: result.mediaType)
            } catch {
                AppLogger.error("TMDB detail fetch failed for \(result.title)", domain: .api, error: error)
            }
            
            // Download poster
            var posterData: Data? = nil
            if let url = result.posterURL {
                posterData = await TMDBService.downloadPoster(from: url)
            }
            
            await MainActor.run {
                // Populate entry fields
                entry.mediaTitle    = detail?.title ?? result.title
                entry.mediaType     = result.mediaType.rawValue
                entry.mediaYear     = detail?.year ?? result.year
                entry.mediaOverview = detail?.overview ?? result.overview
                entry.mediaGenre    = detail?.genres.first
                entry.tmdbID        = result.id
                entry.mediaRuntime  = detail?.runtime
                entry.mediaSeasons  = detail?.seasons
                entry.mediaStatus   = "wantTo"
                
                // Save poster image
                if let data = posterData {
                    entry.mediaCoverPath = try? MediaFileManager.save(
                        data,
                        type: .image,
                        id: "\(entry.id.uuidString)_cover"
                    )
                    coverImage = UIImage(data: data)
                }
                
                // Index in search
                SearchIndex.shared.index(entry: entry)
                
                try? modelContext.save()
            }
        }
    }
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            guard !Task.isCancelled else { return }
            await MainActor.run {
                entry.mediaRating = localRating == 0 ? nil : localRating
                entry.mediaStatus = localStatus
                entry.touch()
                try? modelContext.save()
            }
        }
    }
    func appendLogEntry() {
        let trimmed = newLogText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let dateString = ISO8601DateFormatter().string(from: Date())
        entry.mediaLog.append("\(dateString)::\(trimmed)")
        newLogText = ""
        showingLogInput = false
        try? modelContext.save()
    }
    
    func loadCoverImage() {
        guard let path = entry.mediaCoverPath,
              let data = MediaFileManager.load(path: path) else { return }
        coverImage = UIImage(data: data)
    }
    // MARK: - Pipe Separator

    var pipe: some View {
        Text("|")
            .font(.system(size: 18))
            .foregroundStyle(entry.type.detailAccentColor(for: themeManager.current).opacity(0.3))
    }
}
