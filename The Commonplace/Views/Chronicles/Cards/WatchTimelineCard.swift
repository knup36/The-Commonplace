// WatchTimelineCard.swift
// Commonplace
//
// Chronicles card showing a chronological timeline of watched movies and TV shows.
// Pulls from mediaLog entries across all .media entries.
// Each log entry is stored as "ISO8601date::note text" in entry.mediaLog.
// Empty state shown when no media entries have been logged yet.

import SwiftUI

struct WatchTimelineCard: View {
    let entries: [Entry]
    var style: any AppThemeStyle

    struct WatchLogItem: Identifiable {
        let id = UUID()
        let title: String
        let date: Date
        let note: String
        let status: String?
    }

    var mediaEntries: [Entry] {
        entries.filter { $0.type == .media && !$0.mediaLog.isEmpty }
    }

    var watchLogItems: [WatchLogItem] {
        var items: [WatchLogItem] = []
        for entry in mediaEntries {
            for logString in entry.mediaLog {
                let parts = logString.components(separatedBy: "::")
                guard parts.count == 2,
                      let date = ISO8601DateFormatter().date(from: parts[0]) else { continue }
                items.append(WatchLogItem(
                    title: entry.mediaTitle ?? "Unknown",
                    date: date,
                    note: parts[1],
                    status: entry.mediaStatus
                ))
            }
        }
        return items.sorted { $0.date > $1.date }
    }

    var body: some View {
        ChroniclesCardContainer(title: "Watch Timeline", icon: "film.stack") {
            if watchLogItems.isEmpty {
                Text("Your watched movies and shows will appear here as you log them.")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.tertiaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(watchLogItems.prefix(5)) { item in
                        watchLogRow(item: item)
                        if item.id != watchLogItems.prefix(5).last?.id {
                            Divider()
                                .overlay(ChroniclesTheme.sectionDivider)
                                .padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    func watchLogRow(item: WatchLogItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "film")
                .font(.system(size: 14))
                .foregroundStyle(ChroniclesTheme.accentAmber)
                .frame(width: 28, height: 28)
                .background(ChroniclesTheme.statBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(style.typeBodySecondary)
                    .fontWeight(.medium)
                    .foregroundStyle(ChroniclesTheme.primaryText)
                    .lineLimit(1)
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(style.typeCaption)
                        .foregroundStyle(ChroniclesTheme.secondaryText)
                        .lineLimit(2)
                }
                Text(item.date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(style.typeCaption)
                    .foregroundStyle(ChroniclesTheme.tertiaryText)
            }
        }
        .padding(.vertical, 8)
    }
}
