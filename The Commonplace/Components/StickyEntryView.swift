import SwiftUI

struct StickyEntryView: View {
    @Bindable var entry: Entry
    @EnvironmentObject var themeManager: ThemeManager
    var isPreview: Bool = false
    let previewLimit = 4

    var isInkwell: Bool { themeManager.current == .inkwell }
    var accentColor: Color { isInkwell ? InkwellTheme.stickyAccent : Color(hex: "#FFD60A") }

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
                    .font(isInkwell ? .system(.subheadline, design: .serif) : .subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(accentColor)
            }

            let visibleItems = isPreview ? Array(items.prefix(previewLimit)) : items
            ForEach(visibleItems) { item in
                HStack(spacing: 8) {
                    Button {
                        toggleItem(item.id)
                    } label: {
                        Image(systemName: entry.stickyChecked.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(entry.stickyChecked.contains(item.id)
                                ? accentColor
                                : (isInkwell ? InkwellTheme.inkTertiary : Color.secondary))
                    }
                    .buttonStyle(.plain)
                    Text(item.text)
                        .font(isInkwell ? .system(.subheadline, design: .serif) : .subheadline)
                        .foregroundStyle(entry.stickyChecked.contains(item.id)
                            ? (isInkwell ? InkwellTheme.inkTertiary : Color.secondary)
                            : (isInkwell ? InkwellTheme.inkPrimary : Color.primary))
                        .strikethrough(entry.stickyChecked.contains(item.id),
                                       color: isInkwell ? InkwellTheme.inkTertiary : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if isPreview && items.count > previewLimit {
                Text("\(items.count - previewLimit) more...")
                    .font(.caption)
                    .foregroundStyle(isInkwell ? InkwellTheme.inkTertiary : Color.secondary)
                    .padding(.top, 2)
            }

            if !items.isEmpty {
                HStack(spacing: 6) {
                    ProgressView(value: Double(entry.stickyChecked.count), total: Double(items.count))
                        .tint(accentColor)
                    Text("\(entry.stickyChecked.count)/\(items.count)")
                        .font(.caption2)
                        .foregroundStyle(isInkwell ? InkwellTheme.inkTertiary : Color.secondary)
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
