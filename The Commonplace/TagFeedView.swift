import SwiftUI
import SwiftData

struct TagFeedView: View {
    let tag: String
    @Query var entries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager
    @State private var searchText = ""

    var isInkwell: Bool { themeManager.current == .inkwell }

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
        .background(isInkwell ? InkwellTheme.background : Color(uiColor: .systemBackground))
        .navigationTitle(isInkwell ? "" : tag)
        .navigationBarTitleDisplayMode(isInkwell ? .inline : .large)
        .toolbar {
            if isInkwell {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "number")
                            .font(.caption)
                            .foregroundStyle(InkwellTheme.amber)
                        Text(tag)
                            .font(.system(.headline, design: .serif))
                            .foregroundStyle(InkwellTheme.inkPrimary)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search entries...")
    }

    @ViewBuilder
    func destinationView(for entry: Entry) -> some View {
        switch entry.type {
        case .location:
            LocationDetailView(entry: entry)
        case .sticky:
            StickyDetailView(entry: entry)
        default:
            EntryDetailView(entry: entry)
        }
    }
}
