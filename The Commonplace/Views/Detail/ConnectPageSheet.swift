// ConnectPageSheet.swift
// Commonplace
//
// Half-sheet presented when the user taps "+ Add linked entry" in edit mode.
// Allows the user to search their archive and connect a page to the current entry.
//
// Presentation:
//   - .sheet with .presentationDetents([.medium, .large])
//   - Opens at .medium — entry card visible and dimmed behind
//   - Snaps to .large automatically when keyboard appears
//   - No auto-focus on appear — keyboard only raises when user taps search field
//   - Suggested entries shown immediately at .medium detent
//
// Search:
//   - Runs against SearchIndex (GRDB FTS5), same pattern as SearchView
//   - 150ms debounce, matching SearchView exactly
//   - Filters against full archive fetched once on sheet appear
//   - Excludes the current entry and already-linked entries from all results
//
// Suggestions:
//   - Computed once when sheet appears via LinkedEntryService.suggestions()
//   - Shown when query is empty
//   - Replaced by search results when user types
//
// On selection:
//   - Calls LinkedEntryService.link(_:to:context:)
//   - Dismisses sheet immediately
//   - No multi-select — one link per sheet presentation
//
// Architecture:
//   - Full archive @Query lives here — scoped to this sheet's lifetime
//   - Never passes allEntries to a parent view
//   - ModelContext injected via @Environment

import SwiftUI
import SwiftData

struct ConnectPageSheet: View {
    let entry: Entry
    var onDismiss: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    var style: any AppThemeStyle { themeManager.style }

    // Full archive — scoped to this sheet's lifetime only
    @Query(sort: \Entry.createdAt, order: .reverse) private var allEntries: [Entry]

    @State private var query = ""
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var searchResults: [Entry] = []
    @State private var suggestions: [Entry] = []

    private var isSearching: Bool { !query.isEmpty }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(style.tertiaryText.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)

            // Title
            Text("Connect a page")
                .font(style.typeBody)
                .fontWeight(.semibold)
                .foregroundStyle(style.primaryText)
                .padding(.bottom, 14)

            // Search field
            searchField
                .padding(.horizontal, 14)
                .padding(.bottom, 14)

            // Section label
            HStack {
                Text(isSearching ? "Results" : "Suggested")
                    .font(style.typeSectionHeader)
                    .foregroundStyle(style.tertiaryText)
                    .padding(.horizontal, 14)
                Spacer()
            }
            .padding(.bottom, 6)

            Divider()
                .overlay(style.tertiaryText.opacity(0.2))

            // Entry rows
            ScrollView {
                LazyVStack(spacing: 0) {
                    let rows = isSearching ? searchResults : suggestions

                    if rows.isEmpty && isSearching {
                        noResultsState
                    } else {
                        ForEach(rows) { candidate in
                            connectRow(candidate: candidate)
                            Divider()
                                .overlay(style.tertiaryText.opacity(0.15))
                                .padding(.leading, 14)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(style.background)
        .onChange(of: query) { _, newValue in
            scheduleSearch(newValue)
        }
        .onAppear {
            computeSuggestions()
        }
    }

    // MARK: - Search Field

    var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(style.tertiaryText)

            TextField("Search your pages...", text: $query)
                .font(style.typeBody)
                .foregroundStyle(style.primaryText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(style.secondaryText.opacity(0.08))
        )
    }

    // MARK: - Connect Row

    func connectRow(candidate: Entry) -> some View {
        let accent = candidate.type.detailAccentColor(for: themeManager.current)
        let sharedTag = LinkedEntryService.topSharedTag(between: entry, and: candidate)

        return HStack(spacing: 12) {
            // Type dot
            Circle()
                .fill(accent)
                .frame(width: 8, height: 8)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(rowTitle(for: candidate))
                    .font(style.typeBody)
                    .fontWeight(.medium)
                    .foregroundStyle(style.primaryText)
                    .lineLimit(1)

                // Subtitle: shared tag (suggestions) or type · date (search)
                if isSearching {
                    Text("\(candidate.type.displayName) · \(candidate.createdAt.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(style.typeCaption)
                        .foregroundStyle(style.tertiaryText)
                } else if let tag = sharedTag {
                    Text("#\(tag) · \(candidate.createdAt.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(style.typeCaption)
                        .foregroundStyle(style.tertiaryText)
                } else {
                    Text("\(candidate.type.displayName) · \(candidate.createdAt.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(style.typeCaption)
                        .foregroundStyle(style.tertiaryText)
                }
            }

            Spacer()

            // Add button
            Button {
                linkAndDismiss(candidate)
            } label: {
                ZStack {
                    Circle()
                        .fill(style.accent.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(style.accent)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture {
            linkAndDismiss(candidate)
        }
    }

    // MARK: - No Results

    var noResultsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(style.tertiaryText)
            Text("No pages found")
                .font(style.typeBodySecondary)
                .foregroundStyle(style.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Actions

    func linkAndDismiss(_ candidate: Entry) {
        LinkedEntryService.link(entry, to: candidate, context: context)
        dismiss()
        onDismiss()
    }

    // MARK: - Suggestions

    func computeSuggestions() {
        suggestions = LinkedEntryService.suggestions(for: entry, allEntries: allEntries)
    }

    // MARK: - Search

    func scheduleSearch(_ newQuery: String) {
        searchTask?.cancel()
        guard !newQuery.isEmpty else {
            searchResults = []
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
        let currentID = entry.id.uuidString
        let linkedIDSet = Set(entry.linkedEntryIDs)

        // FTS5 search against the index
        let matchedIDs = SearchIndex.shared.search(query: q)

        searchResults = allEntries
            .filter {
                matchedIDs.contains($0.id) &&
                $0.id.uuidString != currentID &&
                !linkedIDSet.contains($0.id.uuidString)
            }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Title Derivation

    func rowTitle(for entry: Entry) -> String {
        switch entry.type {
        case .text:
            let first = entry.text.components(separatedBy: "\n").first ?? ""
            return first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Note" : first
        case .link:
            return entry.linkTitle ?? entry.url ?? "Link"
        case .location:
            return entry.locationName ?? "Place"
        case .music:
            return entry.linkTitle ?? entry.musicArtist ?? "Music"
        case .media:
            return entry.mediaTitle ?? "Media"
        case .journal:
            return entry.createdAt.formatted(.dateTime.weekday(.wide).month(.wide).day())
        case .audio:
            return entry.transcript.flatMap {
                $0.isEmpty ? nil : String($0.prefix(60))
            } ?? "Sound"
        case .photo:
            let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? "Shot" : String(text.prefix(60))
        case .sticky:
            return entry.stickyTitle ?? "List"
        case .attachment:
            return entry.attachmentFilename ?? "Attachment"
        }
    }
}
