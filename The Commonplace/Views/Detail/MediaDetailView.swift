// MediaDetailView.swift
// Commonplace
//
// Detail view for .media entries (movies, TV shows, and podcasts).
// Operates in two modes:
//
//   Empty state — shows a segmented Movie/TV/Podcast picker and search.
//   Movie and TV search via TMDBService. Podcast search via PodcastService.
//
//   Populated state — routes to type-specific detail section:
//     MovieDetailSection, TVDetailSection, or PodcastDetailSection.
//   All types share notes, log, tags/people, and metadata footer.
//
// TMDB/iTunes metadata is locked once selected.
// Status, rating, notes, and log entries are always editable.
//
// Media log entries stored as "ISO8601date::note text" strings.

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
    @State private var selectedMediaType: MediaSearchType = .movie
    @State private var searchQuery: String = ""
    @State private var tmdbResults: [TMDBSearchResult] = []
    @State private var podcastResults: [PodcastSearchResult] = []
    @State private var gameResults: [RAWGSearchResult] = []
    @State private var isSearching: Bool = false
    @State private var searchError: String? = nil
    
    // MARK: - Entry State
    @State private var saveTask: Task<Void, Never>? = nil
    @State private var localRating: Int = 0
    @State private var localStatus: String = "wantTo"
    @State private var showingDeleteConfirmation = false
    
    // MARK: - Log State
    @State private var newLogText: String = ""
    @State private var showingLogInput: Bool = false
    
    // MARK: - Cover Art
    @State private var coverImage: UIImage? = nil
    
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
                    Button("Done") { editMode.exit() }
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
                Image(systemName: selectedMediaType.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(entry.type.detailAccentColor(for: themeManager.current))
                Text(selectedMediaType.prompt)
                    .font(style.typeTitle2)
                    .fontWeight(.bold)
                    .foregroundStyle(style.cardPrimaryText)
                Text(selectedMediaType.subtitle)
                    .font(style.typeBodySecondary)
                    .foregroundStyle(style.cardSecondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.horizontal, 24)
            
            // Movie / TV / Podcast / Game picker
            Picker("Type", selection: $selectedMediaType) {
                Text("Movie").tag(MediaSearchType.movie)
                Text("TV Show").tag(MediaSearchType.tv)
                Text("Podcast").tag(MediaSearchType.podcast)
                Text("Game").tag(MediaSearchType.game)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .onChange(of: selectedMediaType) { _, _ in
                tmdbResults = []
                podcastResults = []
                searchError = nil
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
                        tmdbResults = []
                        podcastResults = []
                        gameResults = []
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
                if newValue.isEmpty {
                    tmdbResults = []
                    podcastResults = []
                    gameResults = []
                }
            }
            
            // Search button
            Button {
                performSearch()
            } label: {
                HStack {
                    if isSearching {
                        ProgressView().tint(.white)
                    } else {
                        Text("Search").fontWeight(.semibold)
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
            let hasResults = !tmdbResults.isEmpty || !podcastResults.isEmpty || !gameResults.isEmpty
            if hasResults {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Results")
                        .font(style.typeSectionHeader)
                        .foregroundStyle(style.cardSecondaryText)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                    
                    if selectedMediaType == .podcast {
                        ForEach(podcastResults) { result in
                            Button {
                                selectPodcastResult(result)
                            } label: {
                                podcastResultRow(result)
                            }
                            .buttonStyle(.plain)
                            if result.id != podcastResults.last?.id {
                                Divider().padding(.leading, 24 + 56 + 12)
                            }
                        }
                    } else if selectedMediaType == .game {
                        ForEach(gameResults) { result in
                            Button {
                                selectGameResult(result)
                            } label: {
                                gameResultRow(result)
                            }
                            .buttonStyle(.plain)
                            if result.id != gameResults.last?.id {
                                Divider().padding(.leading, 24 + 56 + 12)
                            }
                        }
                    } else {
                        ForEach(tmdbResults) { result in
                            Button {
                                selectTMDBResult(result)
                            } label: {
                                tmdbResultRow(result)
                            }
                            .buttonStyle(.plain)
                            if result.id != tmdbResults.last?.id {
                                Divider().padding(.leading, 24 + 56 + 12)
                            }
                        }
                    }
                }
            }
            
            Spacer(minLength: 40)
        }
    }
    
    // MARK: - TMDB Result Row
    
    func tmdbResultRow(_ result: TMDBSearchResult) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: result.thumbnailURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(style.surface)
                    .overlay(Image(systemName: "film").foregroundStyle(style.secondaryText))
            }
            .frame(width: 44, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(style.typeTitle3)
                    .fontWeight(.medium)
                    .foregroundStyle(style.cardPrimaryText)
                    .lineLimit(2)
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
    
    // MARK: - Podcast Result Row
    
    func podcastResultRow(_ result: PodcastSearchResult) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: result.thumbnailURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(style.surface)
                    .overlay(Image(systemName: "mic").foregroundStyle(style.secondaryText))
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(style.typeTitle3)
                    .fontWeight(.medium)
                    .foregroundStyle(style.cardPrimaryText)
                    .lineLimit(2)
                if !result.publisher.isEmpty {
                    Text(result.publisher)
                        .font(style.typeCaption)
                        .foregroundStyle(style.cardSecondaryText)
                }
                if !result.genre.isEmpty {
                    Text(result.genre)
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
    
    // MARK: - Game Result Row
    
    func gameResultRow(_ result: RAWGSearchResult) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: result.thumbnailURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(style.surface)
                    .overlay(Image(systemName: "gamecontroller").foregroundStyle(style.secondaryText))
            }
            .frame(width: 44, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(style.typeTitle3)
                    .fontWeight(.medium)
                    .foregroundStyle(style.cardPrimaryText)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if !result.year.isEmpty {
                        Text(result.year)
                            .font(style.typeCaption)
                            .foregroundStyle(style.cardSecondaryText)
                    }
                    if !result.genre.isEmpty {
                        Text("· \(result.genre)")
                            .font(style.typeCaption)
                            .foregroundStyle(style.cardSecondaryText)
                    }
                }
                if !result.platforms.isEmpty {
                    Text(result.platforms)
                        .font(style.typeCaption)
                        .foregroundStyle(style.cardSecondaryText)
                        .lineLimit(1)
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
    
    func selectGameResult(_ result: RAWGSearchResult) {
        Task {
            // Fetch full detail for developer/publisher
            var detail: RAWGSearchResult? = nil
            do {
                detail = try await RAWGService.fetchDetail(id: result.id)
            } catch {
                AppLogger.error("RAWG detail fetch failed for \(result.title)", domain: .api, error: error)
            }
            
            var artworkData: Data? = nil
            if let url = result.fullImageURL {
                artworkData = await RAWGService.downloadArtwork(from: url)
            }
            
            await MainActor.run {
                entry.mediaTitle    = detail?.title ?? result.title
                entry.mediaType     = "game"
                entry.mediaYear     = detail?.year ?? result.year
                entry.mediaGenre    = detail?.genre ?? result.genre
                entry.mediaPlatform = detail?.platforms ?? result.platforms
                entry.mediaOverview = detail?.developer ?? result.developer
                entry.mediaStatus   = "wantTo"
                
                if let data = artworkData {
                    entry.mediaCoverPath = try? MediaFileManager.save(
                        data, type: .image, id: "\(entry.id.uuidString)_cover"
                    )
                    coverImage = UIImage(data: data)
                }
                
                SearchIndex.shared.index(entry: entry)
                try? modelContext.save()
            }
        }
    }
    
    // MARK: - Populated View
    
    var populatedView: some View {
        VStack(spacing: 0) {
            // Route to type-specific header + status section
            switch entry.mediaType {
            case "tv":
                TVDetailSection(
                    entry: entry,
                    coverImage: coverImage,
                    localRating: $localRating,
                    localStatus: $localStatus,
                    onStatusChange: scheduleSave
                )
            case "podcast":
                PodcastDetailSection(
                    entry: entry,
                    coverImage: coverImage,
                    localRating: $localRating,
                    localStatus: $localStatus,
                    onStatusChange: scheduleSave
                )
            case "game":
                GameDetailSection(
                    entry: entry,
                    coverImage: coverImage,
                    localRating: $localRating,
                    localStatus: $localStatus,
                    onStatusChange: scheduleSave
                )
            default:
                MovieDetailSection(
                    entry: entry,
                    coverImage: coverImage,
                    localRating: $localRating,
                    localStatus: $localStatus,
                    onStatusChange: scheduleSave
                )
            }
            
            // Shared sections — identical across all media types
            VStack(spacing: 20) {
                Divider().padding(.horizontal, 20)
                notesSection
                Divider().padding(.horizontal, 20)
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
                                if hasPeople || hasTags { pipe }
                            }
                            if hasPeople {
                                PersonInputView(tags: $entry.tagNames, accentColor: mediaAccent, style: style)
                                if hasTags { pipe }
                            }
                            if hasTags {
                                TagInputView(tags: $entry.tagNames, accentColor: mediaAccent, style: style)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                Divider().padding(.horizontal, 20)
                EntryMetadataFooter(entry: entry, style: style, accentColor: mediaAccent)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
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
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                    HStack(spacing: 12) {
                        Button {
                            appendWatchedEntry()
                        } label: {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(entry.type.detailAccentColor(for: themeManager.current))
                        }
                        Button {
                            showingLogInput.toggle()
                        } label: {
                            Image(systemName: "bubble.left")
                                .foregroundStyle(entry.type.detailAccentColor(for: themeManager.current))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            
            if showingLogInput {
                VStack(spacing: 8) {
                    CommonplaceTextEditor(
                        text: $newLogText,
                        placeholder: "What are you thinking?",
                        usesSerifFont: false,
                        focusOnAppear: true
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
    
    // MARK: - Search Actions
    
    func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSearching = true
        searchError = nil
        tmdbResults = []
        podcastResults = []
        
        Task {
            do {
                switch selectedMediaType {
                case .podcast:
                    let results = try await PodcastService.search(query: searchQuery)
                    await MainActor.run {
                        podcastResults = results
                        isSearching = false
                        if results.isEmpty { searchError = "No podcasts found. Try a different title." }
                    }
                case .game:
                    let results = try await RAWGService.search(query: searchQuery)
                    await MainActor.run {
                        gameResults = results
                        isSearching = false
                        if results.isEmpty { searchError = "No games found. Try a different title." }
                    }
                case .movie, .tv:
                    let tmdbType: TMDBMediaType = selectedMediaType == .movie ? .movie : .tv
                    let results = try await TMDBService.search(query: searchQuery, type: tmdbType)
                    await MainActor.run {
                        tmdbResults = results
                        isSearching = false
                        if results.isEmpty { searchError = "No results found. Try a different title." }
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
    
    func selectTMDBResult(_ result: TMDBSearchResult) {
        Task {
            var detail: TMDBDetail? = nil
            do {
                detail = try await TMDBService.fetchDetail(id: result.id, type: result.mediaType)
            } catch {
                AppLogger.error("TMDB detail fetch failed for \(result.title)", domain: .api, error: error)
            }
            
            var posterData: Data? = nil
            if let url = result.posterURL {
                posterData = await TMDBService.downloadPoster(from: url)
            }
            
            await MainActor.run {
                entry.mediaTitle   = detail?.title ?? result.title
                entry.mediaType    = result.mediaType.rawValue
                entry.mediaYear    = detail?.year ?? result.year
                entry.mediaOverview = detail?.overview ?? result.overview
                entry.mediaGenre   = detail?.genres.first
                entry.tmdbID       = result.id
                entry.mediaRuntime = detail?.runtime
                entry.mediaSeasons = detail?.seasons
                entry.mediaStatus  = "wantTo"
                
                if let data = posterData {
                    entry.mediaCoverPath = try? MediaFileManager.save(
                        data, type: .image, id: "\(entry.id.uuidString)_cover"
                    )
                    coverImage = UIImage(data: data)
                }
                
                SearchIndex.shared.index(entry: entry)
                try? modelContext.save()
            }
        }
    }
    
    func selectPodcastResult(_ result: PodcastSearchResult) {
        Task {
            var artworkData: Data? = nil
            if let url = result.fullArtworkURL {
                artworkData = await PodcastService.downloadArtwork(from: url)
            }
            
            await MainActor.run {
                entry.mediaTitle    = result.title
                entry.mediaType     = "podcast"
                entry.mediaOverview = result.publisher
                entry.mediaGenre    = result.genre
                entry.mediaStatus   = "wantTo"
                entry.url           = result.websiteURL
                
                if let data = artworkData {
                    entry.mediaCoverPath = try? MediaFileManager.save(
                        data, type: .image, id: "\(entry.id.uuidString)_cover"
                    )
                    coverImage = UIImage(data: data)
                }
                
                SearchIndex.shared.index(entry: entry)
                try? modelContext.save()
            }
        }
    }
    
    // MARK: - Entry Actions
    
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
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
    
    func appendWatchedEntry() {
        let today = Calendar.current.startOfDay(for: Date())
        let alreadyLogged = entry.mediaLog.contains { log in
            let parts = log.components(separatedBy: "::")
            guard parts.count == 2,
                  let date = ISO8601DateFormatter().date(from: parts[0]) else { return false }
            return Calendar.current.startOfDay(for: date) == today && parts[1] == "Watched"
        }
        guard !alreadyLogged else { return }
        let dateString = ISO8601DateFormatter().string(from: Date())
        entry.mediaLog.append("\(dateString)::Watched")
        entry.touch()
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

// MARK: - Media Search Type

enum MediaSearchType: String {
    case movie   = "movie"
    case tv      = "tv"
    case podcast = "podcast"
    case game    = "game"
    
    var icon: String {
        switch self {
        case .movie:   return "film.fill"
        case .tv:      return "tv.fill"
        case .podcast: return "mic.fill"
        case .game:    return "gamecontroller.fill"
        }
    }
    
    var prompt: String {
        switch self {
        case .movie:   return "What are you watching?"
        case .tv:      return "What are you watching?"
        case .podcast: return "What are you listening to?"
        case .game:    return "What are you playing?"
        }
    }
    
    var subtitle: String {
        switch self {
        case .movie:   return "Search for a movie to get started."
        case .tv:      return "Search for a TV show to get started."
        case .podcast: return "Search for a podcast to get started."
        case .game:    return "Search for a game to get started."
        }
    }
}
