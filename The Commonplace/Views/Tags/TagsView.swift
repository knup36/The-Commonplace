import SwiftUI
import SwiftData

struct TagsView: View {
    @Query var entries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager
    @State private var searchText = ""

    var isInkwell: Bool { themeManager.current == .inkwell }

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
                // Inkwell title
                if isInkwell {
                                    Text("Tags")
                                        .font(.system(size: 34, weight: .bold, design: .serif))
                                        .foregroundStyle(InkwellTheme.inkPrimary)
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
                            .foregroundStyle(isInkwell ? InkwellTheme.inkTertiary : .secondary)
                        Text("No Tags Yet")
                            .font(.headline)
                            .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
                        Text("Add tags to your entries to see them here")
                            .font(.caption)
                            .foregroundStyle(isInkwell ? InkwellTheme.inkTertiary : .secondary)
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
                                        .foregroundStyle(isInkwell ? InkwellTheme.amber : .accentColor)
                                    Text(item.tag)
                                        .font(isInkwell ? .system(.body, design: .serif) : .body)
                                        .foregroundStyle(isInkwell ? InkwellTheme.inkPrimary : .primary)
                                }
                                Spacer()
                                Text("\(item.count)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(isInkwell ? InkwellTheme.amber : .secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(
                            isInkwell
                            ? InkwellTheme.surface
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.vertical, 2)
                            : nil
                        )
                        .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                        .listRowSeparator(isInkwell ? .hidden : .visible)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(isInkwell ? InkwellTheme.background : Color(uiColor: .systemBackground))
            .navigationTitle(isInkwell ? "" : "Tags")
            .navigationBarTitleDisplayMode(isInkwell ? .inline : .large)
            .searchable(text: $searchText, prompt: "Search tags...")
        }
        .overlay(
            Text("TagsView")
                .font(.caption)
                .padding(4)
                .background(Color.red),
            alignment: .topLeading
        )
    }
}
