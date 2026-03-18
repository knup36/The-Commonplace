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
            .filter { $0.tags.contains(tag) }
            .sorted { $0.createdAt > $1.createdAt }
        if searchText.isEmpty { return tagged }
        return tagged.filter { entryMatchesSearch($0, searchText: searchText) }
    }

    var body: some View {
        List {
            ForEach(filteredEntries) { entry in
                ZStack {
                    NavigationLink(destination: destinationView(for: entry)) {
                        EmptyView()
                    }
                    .opacity(0)
                    EntryRowView(entry: entry)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
