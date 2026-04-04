import SwiftUI

// MARK: - StickyEntryView
// Feed card preview for sticky/checklist entries.
// Shows title, sorted items (incomplete first), progress bar.
// Used in EntryRowView for the feed card preview.
// Screen: Feed, Collections, Today tab — sticky entry cards

struct StickyEntryView: View {
    @Bindable var entry: Entry
    @EnvironmentObject var themeManager: ThemeManager
    var isPreview: Bool = false
    let previewLimit = 4
    
    var style: any AppThemeStyle { themeManager.style }
    var accentColor: Color { entry.type.detailAccentColor(for: themeManager.current) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = entry.stickyTitle, !title.isEmpty {
                Text(title)
                    .font(style.typeBodySecondary)
                    .fontWeight(.semibold)
                    .foregroundStyle(accentColor)
            }
            
            let sortedItems = entry.parsedStickyItems.sorted {
                !entry.stickyChecked.contains($0.id) && entry.stickyChecked.contains($1.id)
            }
            let visibleItems = isPreview ? Array(sortedItems.prefix(previewLimit)) : sortedItems
            
            ForEach(visibleItems) { item in
                HStack(spacing: 8) {
                    Button {
                        entry.toggleStickyItem(item.id)
                    } label: {
                        Image(systemName: entry.stickyChecked.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(entry.stickyChecked.contains(item.id)
                                             ? accentColor
                                             : style.tertiaryText)
                    }
                    .buttonStyle(.plain)
                    Text(item.text)
                        .font(style.typeBodySecondary)
                        .foregroundStyle(entry.stickyChecked.contains(item.id)
                                         ? style.cardMetadataText
                                         : style.cardPrimaryText)
                        .strikethrough(entry.stickyChecked.contains(item.id),
                                       color: style.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            if isPreview && entry.parsedStickyItems.count > previewLimit {
                Text("\(entry.parsedStickyItems.count - previewLimit) more...")
                    .font(style.typeCaption)
                    .foregroundStyle(style.cardMetadataText)
                    .padding(.top, 2)
            }
            
            if !entry.parsedStickyItems.isEmpty {
                HStack(spacing: 6) {
                    ProgressView(value: Double(entry.stickyChecked.count), total: Double(entry.parsedStickyItems.count))
                        .tint(accentColor)
                    Text("\(entry.stickyChecked.count)/\(entry.parsedStickyItems.count)")
                        .font(style.typeCaption)
                        .foregroundStyle(style.cardMetadataText)
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
