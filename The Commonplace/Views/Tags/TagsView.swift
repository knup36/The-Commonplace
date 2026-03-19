import SwiftUI
import SwiftData

// MARK: - TagsView
// Content view for the Tags section of the Library tab.
// NavigationStack is owned by LibraryView — this view is content only.
// Screen: Library tab → Tags segment

struct TagsView: View {
    @Query var entries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var navigationPath: NavigationPath
    @Binding var selectedTab: Int

    var style: any AppThemeStyle { themeManager.style }

    var allTags: [(tag: String, count: Int)] {
        var tagCounts: [String: Int] = [:]
        for entry in entries {
            for tag in entry.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        return tagCounts
            .map { (tag: $0.key, count: $0.value) }
            .sorted { $0.tag < $1.tag }
    }

    var body: some View {
        List {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Text("Tags")
                    .font(style.usesSerifFonts
                          ? .system(size: 34, weight: .bold, design: .serif)
                          : .largeTitle.bold())
                    .foregroundStyle(style.primaryText)
                    .padding(.leading, 8)
                Picker("", selection: $selectedTab) {
                    Text("Collections").tag(0)
                    Text("Tags").tag(1)
                }
                .pickerStyle(.segmented)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
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
                                .padding(.trailing, -12)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                    }
                    .listRowBackground(
                        style.usesSerifFonts
                        ? style.surface
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 16)
                        : nil
                    )
                    .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 24))
                    .listRowSeparator(style.usesSerifFonts ? .hidden : .visible)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(style.background)
    }
}
