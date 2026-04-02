// SearchResultsView.swift
// Commonplace
//
// Full search results view — shown when tapping "See all X results" in SearchView.
// Displays all matching entries split into two groups:
//   1. Tagged — entries where the query matches a tag or person tag exactly
//   2. Mentioned — entries where the query appears in text or other fields
//
// Works for both person searches and tag searches.
// Future: add Folio matches as a third priority tier above Tagged.

import SwiftUI
import SwiftData

struct SearchResultsView: View {
    let query: String
    let allEntries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager

    var style: any AppThemeStyle { themeManager.style }

    var lower: String { query.lowercased() }
    var tagString: String { "@\(lower)" }

    var matchedEntries: [Entry] {
        let matchedIDs = SearchIndex.shared.search(query: query)
        return allEntries
            .filter { matchedIDs.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var taggedEntries: [Entry] {
        matchedEntries.filter { entry in
            entry.tagNames.contains { $0.lowercased() == lower || $0.lowercased() == tagString }
        }
    }

    var mentionedEntries: [Entry] {
        let taggedIDs = Set(taggedEntries.map { $0.id })
        return matchedEntries.filter { !taggedIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !taggedEntries.isEmpty {
                    groupHeader("Tagged")
                    ForEach(taggedEntries) { entry in
                        NavigationLink(destination: destinationView(for: entry)) {
                            EntryRowView(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }

                if !mentionedEntries.isEmpty {
                    groupHeader("Mentioned in entries")
                    ForEach(mentionedEntries) { entry in
                        NavigationLink(destination: destinationView(for: entry)) {
                            EntryRowView(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }

                Color.clear.frame(height: 40)
            }
        }
        .background(style.background)
        .navigationTitle("Results for \"\(query)\"")
        .navigationBarTitleDisplayMode(.inline)
    }

    func groupHeader(_ title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: title.contains("Tagged") ? "person.fill" : "quote.opening")
                .font(.system(size: 11))
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundStyle(style.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}
