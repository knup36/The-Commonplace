// OnThisDayCard.swift
// Commonplace
//
// Chronicles card showing entries from approximately one month ago.
// Receives pre-filtered oneMonthAgoEntries from ChroniclesView —
// no filtering performed at render time.
//
// Updated v2.4 — pre-filtered data, charcoal card, colored entry icons.

import SwiftUI

struct OnThisDayCard: View {
    let oneMonthAgoEntries: [Entry]
    var style: any AppThemeStyle
    let themeManager: ThemeManager

    var body: some View {
        ChroniclesCardContainer(title: "One Month Ago", icon: "clock.arrow.circlepath", background: .parchment) {
            if oneMonthAgoEntries.isEmpty {
                Text("Nothing captured around this time last month. Keep adding entries — your archive will grow.")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.tertiaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(oneMonthAgoEntries.prefix(5)) { entry in
                        NavigationLink(value: entry) {
                            entryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        if entry.id != oneMonthAgoEntries.prefix(5).last?.id {
                            Divider()
                                .overlay(ChroniclesTheme.sectionDivider)
                                .padding(.leading, 36)
                        }
                    }
                    if oneMonthAgoEntries.count > 5 {
                        Text("\(oneMonthAgoEntries.count - 5) more from this time")
                            .font(style.typeCaption)
                            .foregroundStyle(ChroniclesTheme.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, 8)
                    }
                }
            }
        }
    }

    func entryRow(entry: Entry) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(entry.type.accentColor(for: themeManager.current).opacity(0.25))
                    .frame(width: 28, height: 28)
                Image(systemName: entry.type.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(entry.type.accentColor(for: themeManager.current).opacity(0.9))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(previewText(for: entry))
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.primaryText)
                    .lineLimit(2)
                Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(style.typeCaption)
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ChroniclesTheme.tertiaryText)
        }
        .padding(.vertical, 8)
    }

    func previewText(for entry: Entry) -> String {
        switch entry.type {
        case .location: return entry.locationName ?? "A place"
        case .link:     return entry.linkTitle ?? entry.url ?? "A link"
        case .media:    return entry.mediaTitle ?? "A media entry"
        case .music:    return entry.linkTitle ?? "A track"
        case .sticky:   return entry.stickyTitle ?? "A list"
        case .audio:    return entry.text.components(separatedBy: "\n").first
                               .flatMap { $0.isEmpty ? nil : $0 } ?? "A recording"
        default:
            let firstLine = entry.text.components(separatedBy: "\n").first ?? ""
            let text = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? entry.type.displayName : text
        }
    }
}
