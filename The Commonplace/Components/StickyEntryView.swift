import SwiftUI

struct StickyEntryView: View {
    @Bindable var entry: Entry
    @EnvironmentObject var themeManager: ThemeManager
    var isPreview: Bool = false
    let previewLimit = 4

    var style: any AppThemeStyle { themeManager.style }
    var accentColor: Color { InkwellTheme.stickyAccent }

    struct StickyItem: Identifiable {
        let id: String
        let text: String
    }

    var items: [StickyItem] {
        entry.stickyItems.compactMap { raw in
            let parts = raw.components(separatedBy: "::")
            guard parts.count == 2 else { return nil }
            return StickyItem(id: parts[0], text: parts[1])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = entry.stickyTitle, !title.isEmpty {
                Text(title)
                    .font(style.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(accentColor)
            }

            let sortedItems = items.sorted { !entry.stickyChecked.contains($0.id) && entry.stickyChecked.contains($1.id) }
            let visibleItems = isPreview ? Array(sortedItems.prefix(previewLimit)) : sortedItems
            ForEach(visibleItems) { item in
                HStack(spacing: 8) {
                    Button {
                        toggleItem(item.id)
                    } label: {
                        Image(systemName: entry.stickyChecked.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(entry.stickyChecked.contains(item.id)
                                ? accentColor
                                : style.tertiaryText)
                    }
                    .buttonStyle(.plain)
                    Text(item.text)
                        .font(style.subheadline)
                        .foregroundStyle(entry.stickyChecked.contains(item.id)
                            ? style.tertiaryText
                            : style.primaryText)
                        .strikethrough(entry.stickyChecked.contains(item.id),
                                       color: style.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if isPreview && items.count > previewLimit {
                Text("\(items.count - previewLimit) more...")
                    .font(style.caption)
                    .foregroundStyle(style.tertiaryText)
                    .padding(.top, 2)
            }

            if !items.isEmpty {
                HStack(spacing: 6) {
                    ProgressView(value: Double(entry.stickyChecked.count), total: Double(items.count))
                        .tint(accentColor)
                    Text("\(entry.stickyChecked.count)/\(items.count)")
                        .font(.caption2)
                        .foregroundStyle(style.tertiaryText)
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func toggleItem(_ id: String) {
        if entry.stickyChecked.contains(id) {
            entry.stickyChecked.removeAll { $0 == id }
        } else {
            entry.stickyChecked.append(id)
        }
    }
}
