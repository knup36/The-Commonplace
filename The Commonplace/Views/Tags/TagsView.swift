import SwiftUI
import SwiftData

// MARK: - TagsView
// Content view for the Tags section of the Library tab.
// NavigationStack is owned by LibraryView — this view is content only.
// Screen: Library tab → Tags segment

struct TagsView: View {
    @Query var entries: [Entry]
    @Query var allTagObjects: [Tag]
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var navigationPath: NavigationPath
    @Binding var selectedTab: Int
    
    
    var style: any AppThemeStyle { themeManager.style }
    
    var allTags: [(tag: String, count: Int)] {
        var tagCounts: [String: Int] = [:]
        for entry in entries {
            for tag in entry.tagNames {
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
                    .font(style.typeLargeTitle)
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
            
            if allTagObjects.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tag.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(style.tertiaryText)
                    Text("No Tags Yet")
                        .font(style.typeTitle3)
                        .foregroundStyle(style.secondaryText)
                    Text("Add tags to your entries to see them here")
                        .font(style.typeCaption)
                        .foregroundStyle(style.tertiaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            
            ForEach(allTagObjects.sorted { $0.name < $1.name }) { tag in
                let count = entries.filter { $0.tagNames.contains(tag.name) }.count
                ZStack {
                    NavigationLink(destination: TagFeedView(tag: tag.name)) {
                        EmptyView()
                    }
                    .opacity(0)
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "number")
                                .font(.caption)
                                .foregroundStyle(style.accent)
                            Text(tag.name)
                                .font(style.typeBody)
                                .foregroundStyle(style.primaryText)
                        }
                        Spacer()
                        Text("\(count)")
                            .font(style.typeBodySecondary)
                            .fontWeight(.semibold)
                            .foregroundStyle(style.accent)
                            .padding(.trailing, -12)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                }
                .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 24))
                .listRowBackground(Color.clear)
                .listRowSeparator(.visible)
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Test") { }
                        .tint(.orange)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(style.background)
    }
    
    func tagObject(for name: String) -> Tag? {
        allTagObjects.first(where: { $0.name == name })
    }
}
