// DogEarsCard.swift
// Commonplace
//
// Chronicles card surfacing entries that need attention —
// stickies with unchecked items older than 3 days, and entries tagged "later".
//
// Card hides entirely when there is nothing to show.
// Stickies show unchecked item count. "Later" entries show preview text.
// All rows are tappable — navigate directly to the entry.
//
// No schema changes required. Reads from existing entry fields.

import SwiftUI

struct DogEarsCard: View {
    let entries: [Entry]
    var style: any AppThemeStyle

    // Stickies with at least one unchecked item, older than 3 days
    var overdueStickies: [Entry] {
        let cutoff = Date().addingTimeInterval(-3 * 24 * 60 * 60)
        return entries.filter { entry in
            guard entry.type == .sticky else { return false }
            guard entry.createdAt < cutoff else { return false }
            let unchecked = entry.stickyItems.filter { !entry.stickyChecked.contains($0) }
            return !unchecked.isEmpty
        }
    }

    // Entries tagged "later"
    var laterEntries: [Entry] {
        entries.filter { $0.tagNames.contains("later") && $0.type != .sticky }
    }

    var dogEarEntries: [Entry] {
        let combined = overdueStickies + laterEntries
        return Array(combined.prefix(6))
    }

    var body: some View {
        if dogEarEntries.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            ChroniclesCardContainer(title: "Dog-Ears", icon: "bookmark.fill") {
                VStack(spacing: 10) {
                    ForEach(dogEarEntries) { entry in
                        NavigationLink(destination: NavigationRouter.destination(for: entry)) {
                            dogEarRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        if entry.id != dogEarEntries.last?.id {
                            Divider()
                                .overlay(ChroniclesTheme.sectionDivider)
                        }
                    }
                    if (overdueStickies.count + laterEntries.count) > 6 {
                        let remaining = (overdueStickies.count + laterEntries.count) - 6
                        Text("\(remaining) more waiting")
                            .font(style.typeCaption)
                            .foregroundStyle(ChroniclesTheme.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        )
    }

    func dogEarRow(entry: Entry) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(ageText(for: entry.createdAt))
                    .font(style.typeCaption)
                    .foregroundStyle(ChroniclesTheme.accentAmber)
                Text(previewText(for: entry))
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.primaryText)
                    .lineLimit(2)
                if entry.type == .sticky {
                    let uncheckedCount = entry.stickyItems.filter { !entry.stickyChecked.contains($0) }.count
                    Text("\(uncheckedCount) \(uncheckedCount == 1 ? "item" : "items") remaining")
                        .font(style.typeCaption)
                        .foregroundStyle(ChroniclesTheme.tertiaryText)
                }
            }
            Spacer()
            Image(systemName: entry.type.icon)
                .font(.system(size: 12))
                .foregroundStyle(ChroniclesTheme.tertiaryText)
        }
    }

    func ageText(for date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 7  { return "\(days) days ago" }
        let weeks = days / 7
        return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
    }

    func previewText(for entry: Entry) -> String {
        switch entry.type {
        case .sticky:   return entry.stickyTitle?.isEmpty == false ? entry.stickyTitle! : "Untitled list"
        case .location: return entry.locationName ?? "A place"
        case .link:     return entry.linkTitle ?? entry.url ?? "A link"
        case .media:    return entry.mediaTitle ?? "A media entry"
        case .music:    return entry.linkTitle ?? "A track"
        default:
            let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? entry.type.displayName : text
        }
    }
}
