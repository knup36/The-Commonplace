import SwiftUI
import SwiftData

// MARK: - TagFeedView
// Shows all entries that have a specific tag applied.
// Supports search within the tagged entries.
// Screen: Tags tab → tap any tag

struct TagFeedView: View {
    let tag: String
    @Query var entries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager
    @State private var searchText = ""

    var style: any AppThemeStyle { themeManager.style }

    var filteredEntries: [Entry] {
        let tagged = entries
            .filter { $0.tagNames.contains(tag) }
            .sorted { $0.createdAt > $1.createdAt }
        if searchText.isEmpty { return tagged }
        return tagged.filter { entryMatchesSearch($0, searchText: searchText) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredEntries) { entry in
                    NavigationLink(destination: destinationView(for: entry)) {
                        EntryRowView(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
        }
        .background(style.background)
        .navigationTitle(style.usesSerifFonts ? "" : tag)
        .navigationBarTitleDisplayMode(style.usesSerifFonts ? .inline : .large)
        .toolbar {
            if style.usesSerifFonts {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "number")
                            .font(.caption)
                            .foregroundStyle(style.accent)
                        Text(tag)
                            .font(.system(.headline, design: .serif))
                            .foregroundStyle(style.primaryText)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search entries...")
    }
}
