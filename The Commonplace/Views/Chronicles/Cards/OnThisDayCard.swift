// OnThisDayCard.swift
// Commonplace
//
// Chronicles card showing entries from approximately one month ago.
// Renamed from "On This Day" — that card requires a full year of data
// before it populates, so this surfaces memories from 28–35 days ago
// instead, giving new users immediate value.
//
// Each entry row shows the entry type icon in its accent color,
// preview text, and a relative time label.
// All rows are tappable — navigate directly to the entry.
//
// Updated v2.4 — renamed, 30-day window, colored entry type icons.

import SwiftUI

struct OnThisDayCard: View {
    let entries: [Entry]
    var style: any AppThemeStyle
    let themeManager: ThemeManager
    
    // Entries from 28–35 days ago — a "one month ago" window
    var oneMonthAgoEntries: [Entry] {
        let calendar = Calendar.current
        let now = Date()
        guard let windowStart = calendar.date(byAdding: .day, value: -35, to: now),
              let windowEnd   = calendar.date(byAdding: .day, value: -28, to: now)
        else { return [] }
        return entries.filter { $0.createdAt >= windowStart && $0.createdAt <= windowEnd }
    }
    
    var body: some View {
        ChroniclesCardContainer(title: "One Month Ago", icon: "clock.arrow.circlepath", background: .parchment) {
            if oneMonthAgoEntries.isEmpty {
                Text("Nothing captured around this time last month. Keep adding entries — your archive will grow.")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.tertiaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(oneMonthAgoEntries.prefix(5)) { entry in
                        NavigationLink(destination: NavigationRouter.destination(for: entry)) {
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
                        let remaining = oneMonthAgoEntries.count - 5
                        Text("\(remaining) more from this time")
                            .font(style.typeCaption)
                            .foregroundStyle(ChroniclesTheme.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, 8)
                    }
                }
            }
        }
    }
    
    // MARK: - Row
    
    func entryRow(entry: Entry) -> some View {
        HStack(spacing: 10) {
            // Colored entry type icon — uses real accent color from theme
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
    
    // MARK: - Helpers
    
    func relativeDate(for date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 7  { return "\(days) days ago" }
        let weeks = days / 7
        return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
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
