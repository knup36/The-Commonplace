import SwiftUI
import SwiftData

// MARK: - TagsView
// Main view for the Tags tab.
// Shows all tags used across entries with entry counts.
// Tapping a tag navigates to TagFeedView.
// Screen: Tags tab (bottom navigation)

struct TagsView: View {
    @Query var entries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager
    @State private var searchText = ""

    var style: any AppThemeStyle { themeManager.style }

    var allTags: [(tag: String, count: Int)] {
        var tagCounts: [String: Int] = [:]
        for entry in entries {
            for tag in entry.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        let filtered = tagCounts.filter { tag, _ in
            searchText.isEmpty || tag.localizedCaseInsensitiveContains(searchText)
        }
        return filtered
            .map { (tag: $0.key, count: $0.value) }
            .sorted { $0.tag < $1.tag }
    }

    var body: some View {
        NavigationStack {
            List {
                if style.usesSerifFonts {
                    Text("Tags")
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .foregroundStyle(style.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 32, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                if allTags.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tag.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(style.tertiaryText)
                        Text("No Tags Yet")
                            .font(.headline)
                            .foregroundStyle(style.secondaryText)
                        Text("Add tags to your entries to see them here")
                            .font(.caption)
                            .foregroundStyle(style.tertiaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(allTags, id: \.tag) { item in
                        NavigationLink(destination: TagFeedView(tag: item.tag)) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "number")
                                        .font(.caption)
                                        .foregroundStyle(style.accent)
                                    Text(item.tag)
                                        .font(style.body)
                                        .foregroundStyle(style.primaryText)
                                }
                                Spacer()
                                Text("\(item.count)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(style.accent)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(
                            style.usesSerifFonts
                            ? style.surface
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.vertical, 2)
                            : nil
                        )
                        .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                        .listRowSeparator(style.usesSerifFonts ? .hidden : .visible)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(style.background)
            .navigationTitle(style.usesSerifFonts ? "" : "Tags")
            .navigationBarTitleDisplayMode(style.usesSerifFonts ? .inline : .large)
            .searchable(text: $searchText, prompt: "Search tags...")
        }
    }
}
