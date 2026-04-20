// WatchTimelineCard.swift
// Commonplace
//
// Chronicles card showing a chronological timeline of watched movies and TV shows.
// Receives pre-filtered mediaEntries from ChroniclesView.
// Uses a single static ISO8601DateFormatter rather than creating one per log item.
//
// Updated v2.4 — pre-filtered data, cached date formatter,
//               charcoal card background.

import SwiftUI

struct WatchTimelineCard: View {
    let mediaEntries: [Entry]
    var style: any AppThemeStyle

    // Single formatter instance — not recreated on every render
    private static let isoFormatter = ISO8601DateFormatter()

    struct WatchLogItem: Identifiable {
        let id = UUID()
        let title: String
        let date: Date
        let note: String
        let status: String?
    }

    var watchLogItems: [WatchLogItem] {
        var items: [WatchLogItem] = []
        for entry in mediaEntries {
            for logString in entry.mediaLog {
                let parts = logString.components(separatedBy: "::")
                guard parts.count == 2,
                      let date = Self.isoFormatter.date(from: parts[0])
                else { continue }
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
        ChroniclesCardContainer(title: "Watch Timeline", icon: "film.stack", background: .parchment) {
            if watchLogItems.isEmpty {
                Text("Your watched movies and shows will appear here as you log them.")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(Color.white.opacity(0.4))
            } else {
                VStack(spacing: 0) {
                    ForEach(watchLogItems.prefix(5)) { item in
                        watchLogRow(item: item)
                        if item.id != watchLogItems.prefix(5).last?.id {
                            Divider()
                                .overlay(Color.white.opacity(0.1))
                                .padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    func watchLogRow(item: WatchLogItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 28, height: 28)
                Image(systemName: "film")
                    .font(.system(size: 13))
                    .foregroundStyle(ChroniclesTheme.accentAmber)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(style.typeBodySecondary)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(style.typeCaption)
                        .foregroundStyle(Color.white.opacity(0.5))
                        .lineLimit(2)
                }
                Text(item.date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(style.typeCaption)
                    .foregroundStyle(Color.white.opacity(0.3))
            }
        }
        .padding(.vertical, 8)
    }
}
