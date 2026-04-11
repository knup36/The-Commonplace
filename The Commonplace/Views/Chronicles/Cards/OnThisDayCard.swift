// OnThisDayCard.swift
// Commonplace
//
// Chronicles card showing entries captured on this date in previous years.
// Surfaces memories from the archive without any user action required.
// Empty state shown when no entries exist for this date in past years.

import SwiftUI
import SwiftData

struct OnThisDayCard: View {
    let entries: [Entry]
    var style: any AppThemeStyle
    let themeManager: ThemeManager

    var onThisDayEntries: [Entry] {
        let calendar = Calendar.current
        let today = Date()
        let currentMonth = calendar.component(.month, from: today)
        let currentDay = calendar.component(.day, from: today)
        let currentYear = calendar.component(.year, from: today)

        return entries.filter { entry in
            let month = calendar.component(.month, from: entry.createdAt)
            let day = calendar.component(.day, from: entry.createdAt)
            let year = calendar.component(.year, from: entry.createdAt)
            return month == currentMonth && day == currentDay && year != currentYear
        }
    }

    var body: some View {
        ChroniclesCardContainer(title: "On This Day", icon: "calendar") {
            if onThisDayEntries.isEmpty {
                Text("No entries from this date in previous years yet. Keep capturing — your archive grows with time.")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.tertiaryText)
            } else {
                VStack(spacing: 10) {
                    ForEach(onThisDayEntries.prefix(3)) { entry in
                        NavigationLink(destination: NavigationRouter.destination(for: entry)) {
                            onThisDayRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        if entry.id != onThisDayEntries.prefix(3).last?.id {
                            Divider()
                                .overlay(ChroniclesTheme.sectionDivider)
                        }
                    }
                    if onThisDayEntries.count > 3 {
                        Text("\(onThisDayEntries.count - 3) more from this date")
                            .font(style.typeCaption)
                            .foregroundStyle(ChroniclesTheme.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
    }

    func onThisDayRow(entry: Entry) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(yearsAgoText(for: entry.createdAt))
                    .font(style.typeCaption)
                    .foregroundStyle(ChroniclesTheme.accentAmber)
                Text(entryPreviewText(for: entry))
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.primaryText)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: entry.type.icon)
                .font(.system(size: 12))
                .foregroundStyle(ChroniclesTheme.tertiaryText)
        }
    }

    func yearsAgoText(for date: Date) -> String {
        let years = Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
        return years == 1 ? "1 year ago" : "\(years) years ago"
    }

    func entryPreviewText(for entry: Entry) -> String {
        switch entry.type {
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
