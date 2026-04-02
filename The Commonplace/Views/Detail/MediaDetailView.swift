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
        .background(entry.type.cardColor.ignoresSafeArea())
        .keyboardAvoiding()
        .navigationTitle(isPopulated ? (entry.mediaTitle ?? "Media") : "New Media Entry")        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 20) {
                    Menu {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(entry.type.accentColor)
                    }
                    Button {
                        withAnimation { entry.isPinned.toggle() }
                    } label: {
                        Image(systemName: entry.isPinned ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(entry.type.accentColor)
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
                    .foregroundStyle(entry.type.accentColor)
                Text("What are you watching?")
                    .font(style.usesSerifFonts
                          ? .system(.title2, design: .serif)
                          : .title2)
                    .fontWeight(.bold)
                    .foregroundStyle(style.primaryText)
                Text("Search for a movie or TV show to get started.")
                    .font(style.usesSerifFonts
                          ? .system(.subheadline, design: .serif)
                          : .subheadline)
                    .foregroundStyle(style.secondaryText)
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
                .background(entry.type.accentColor)
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
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(style.secondaryText)
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
                    .font(style.usesSerifFonts
                          ? .system(.body, design: .serif)
                          : .body)
                    .fontWeight(.medium)
                    .foregroundStyle(style.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    if !result.year.isEmpty {
                        Text(result.year)
                            .font(.caption)
                            .foregroundStyle(style.secondaryText)
                    }
                    Text(result.mediaType.displayName)
                        .font(.caption)
                        .foregroundStyle(style.secondaryText)
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
                // Status picker
                statusSection
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Rating
                ratingSection
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Notes
                notesSection
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Media log
                logSection
                
                // Tags
                TagInputView(tags: $entry.tagNames, accentColor: entry.type.accentColor, style: style)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                
                // People
                PersonInputView(tags: $entry.tagNames, accentColor: entry.type.accentColor, style: style)
                    .padding(.horizontal, 20)
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Metadata footer
                EntryMetadataFooter(entry: entry, style: style, accentColor: entry.type.accentColor)
                    .padding(.horizontal, 20)
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
                        .fill(entry.type.cardColor)
                        .frame(width: 125, height: 188)
                        .overlay(
                            Image(systemName: "film.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(entry.type.accentColor.opacity(0.5))
                        )
                }
            }
            
            // Metadata column
            VStack(alignment: .leading, spacing: 5) {
                if let title = entry.mediaTitle {
                    Text(title)
                        .font(style.usesSerifFonts
                              ? .system(.headline, design: .serif)
                              : .headline)
                        .fontWeight(.bold)
                        .foregroundStyle(style.primaryText)
                        .lineLimit(3)
                }
                
                Spacer().frame(height: 4)
                
                if let year = entry.mediaYear, !year.isEmpty {
                    Text(year)
                        .font(.subheadline)
                        .foregroundStyle(style.secondaryText)
                }
                
                if let type = entry.mediaType {
                    Text(type == "tv" ? "Television Series" : "Movie")
                        .font(.subheadline)
                        .foregroundStyle(style.secondaryText)
                }
                
                if let genre = entry.mediaGenre, !genre.isEmpty {
                    Text(genre)
                        .font(.subheadline)
                        .foregroundStyle(style.secondaryText)
                }
                
                if let runtime = entry.mediaRuntime, entry.mediaType == "movie" {
                    let hours = runtime / 60
                    let mins = runtime % 60
                    Text(hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m")
                        .font(.subheadline)
                        .foregroundStyle(style.secondaryText)
                }
                
                if let seasons = entry.mediaSeasons, entry.mediaType == "tv" {
                    Text("\(seasons) \(seasons == 1 ? "Season" : "Seasons")")
                        .font(.subheadline)
                        .foregroundStyle(style.secondaryText)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
    
    // MARK: - Status Section
    
    var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STATUS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(style.secondaryText)
                .padding(.horizontal, 20)
            
            HStack(spacing: 10) {
                statusButton(label: "Want to Watch", value: "wantTo",   icon: "bookmark")
                statusButton(label: "In Progress",   value: "inProgress", icon: "play.circle")
                statusButton(label: "Finished",      value: "finished", icon: "checkmark.circle")
            }
            .padding(.horizontal, 20)
        }
    }
    
    func statusColor(for value: String) -> Color {
        switch value {
        case "wantTo":     return InkwellTheme.mediaAccent   // red
        case "inProgress": return InkwellTheme.stickyAccent  // amber/yellow
        case "finished":   return InkwellTheme.locationAccent // green
        default:           return entry.type.accentColor
        }
    }
    
    func statusButton(label: String, value: String, icon: String) -> some View {
        let isSelected = localStatus == value
        let color = statusColor(for: value)
        return Button {
            localStatus = value
            scheduleSave()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: isSelected ? "\(icon).fill" : icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? color : style.secondaryText)
                Text(label)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? color : style.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? color.opacity(0.15) : style.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? color.opacity(0.4) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Rating Section
    
    var ratingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR RATING")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(style.secondaryText)
                .padding(.horizontal, 20)
            
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: localRating >= star ? "star.fill" : "star")
                        .font(.system(size: 28))
                        .foregroundStyle(localRating >= star ? .yellow : style.secondaryText)
                        .onTapGesture {
                            localRating = localRating == star ? 0 : star
                            scheduleSave()
                        }
                }
                Spacer()
                if localRating > 0 {
                    Text("\(localRating)/5")
                        .font(.subheadline)
                        .foregroundStyle(style.secondaryText)
                }
            }
            .padding(.horizontal, 20)
            .transaction { $0.animation = nil }
        }
    }
    
    // MARK: - Notes Section
    
    var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NOTES")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(style.secondaryText)
                .padding(.horizontal, 20)
            
            CommonplaceTextEditor(
                text: Binding(
                    get: { entry.text },
                    set: { entry.text = $0; try? modelContext.save() }
                ),
                placeholder: "Add notes about this title...",
                usesSerifFont: style.usesSerifFonts
            )
            .padding(.horizontal, 20)        }
    }
    
    // MARK: - Log Section
    
    var logSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LOG")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(style.secondaryText)
                Spacer()
                Button {
                    showingLogInput.toggle()
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(entry.type.accentColor)
                }
            }
            .padding(.horizontal, 20)
            
            // New log entry input
            if showingLogInput {
                VStack(spacing: 8) {
                    CommonplaceTextEditor(
                        text: $newLogText,
                        placeholder: "What are you thinking?",
                        usesSerifFont: style.usesSerifFonts
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
                        .foregroundStyle(entry.type.accentColor)
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
            if entry.mediaLog.isEmpty && !showingLogInput {
                Text("No log entries yet. Tap + to add one.")
                    .font(.subheadline)
                    .foregroundStyle(style.tertiaryText)
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
                    .font(.caption)
                    .foregroundStyle(style.tertiaryText)
            }
            Text(text)
                .font(style.usesSerifFonts ? .system(.body, design: .serif) : .body)
                .foregroundStyle(style.primaryText)
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
            let detail = try? await TMDBService.fetchDetail(id: result.id, type: result.mediaType)
            
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
    
}
