// ScrapbookStickyCard.swift
// Commonplace
//
// Scrapbook feed card for .sticky (List) entries.
// Renders as a physical sticky note — yellow, slightly rotated,
// with a tape strip at the top holding it to the page.
//
// Layout:
//   - Tape strip centered at top
//   - Title in warm ink, slightly bold
//   - Checklist items with circle checkmarks
//   - Progress shown as X/Y in bottom right
//   - Date in bottom left
//
// Rotation is seeded from entry UUID so the same note always
// tilts the same direction and amount — deterministic, not random.
// Rotation range: -3 to +3 degrees.

import SwiftUI

struct ScrapbookStickyCard: View {
    let entry: Entry

    struct StickyItem: Identifiable {
        let id: String
        let text: String
        let isChecked: Bool
    }

    var items: [StickyItem] {
        entry.stickyItems.compactMap { raw in
            let parts = raw.components(separatedBy: "::")
            guard parts.count == 2 else { return nil }
            return StickyItem(
                id: parts[0],
                text: parts[1],
                isChecked: entry.stickyChecked.contains(parts[0])
            )
        }
    }

    var checkedCount: Int { items.filter { $0.isChecked }.count }
    var totalCount: Int { items.count }

    /// Deterministic rotation seeded from entry UUID
    var rotation: Double {
            let hash = abs(entry.id.uuidString.hashValue)
            let normalized = Double(hash % 1200) / 100.0  // 0.0 to 12.0
            return normalized - 6.0  // -6.0 to +6.0 degrees
        }

    var body: some View {
        ZStack(alignment: .top) {
            // Sticky note body
            VStack(alignment: .leading, spacing: 10) {
                // Title
                if let title = entry.stickyTitle, !title.isEmpty {
                    Text(title)
                        .font(ScrapbookTheme.bodyFont(size: 15))
                        .fontWeight(.semibold)
                        .foregroundStyle(ScrapbookTheme.inkPrimary)
                        .lineLimit(2)
                }

                // Items
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(items.prefix(4)) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .stroke(item.isChecked ? ScrapbookTheme.inkTertiary : ScrapbookTheme.inkSecondary, lineWidth: 1)
                                    .background(
                                        Circle().fill(item.isChecked ? ScrapbookTheme.inkTertiary.opacity(0.3) : Color.clear)
                                    )
                                    .frame(width: 12, height: 12)
                                Text(item.text)
                                    .font(ScrapbookTheme.bodyFont(size: 13))
                                    .foregroundStyle(item.isChecked ? ScrapbookTheme.inkTertiary : ScrapbookTheme.inkSecondary)
                                    .strikethrough(item.isChecked, color: ScrapbookTheme.inkTertiary)
                                    .lineLimit(1)
                            }
                        }
                        if items.count > 4 {
                                                    Text("+\(items.count - 4) more")
                                .font(ScrapbookTheme.captionFont(size: 11))
                                .foregroundStyle(ScrapbookTheme.inkTertiary)
                                .padding(.leading, 20)
                        }
                    }
                }

                Spacer(minLength: 8)

                // Footer
                HStack {
                    Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(ScrapbookTheme.captionFont(size: 10))
                        .kerning(0.8)
                        .foregroundStyle(ScrapbookTheme.inkTertiary)
                    Spacer()
                    if totalCount > 0 {
                        Text("\(checkedCount)/\(totalCount)")
                            .font(ScrapbookTheme.captionFont(size: 10))
                            .foregroundStyle(ScrapbookTheme.inkTertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 16)
            .frame(width: 260, height: 260)
            .background(ScrapbookTheme.stickyYellow)
            .clipShape(RoundedRectangle(cornerRadius: ScrapbookTheme.cardCornerRadius))
            .shadow(color: ScrapbookTheme.stickyShadow, radius: 4, x: 1, y: 3)

            // Tape strip
            RoundedRectangle(cornerRadius: 2)
                .fill(ScrapbookTheme.tapeColor)
                .frame(width: 48, height: 16)
                .offset(y: -8)
        }
        .rotationEffect(.degrees(rotation))
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
    }
}
