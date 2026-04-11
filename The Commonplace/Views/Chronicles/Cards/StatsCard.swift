// StatsCard.swift
// Commonplace
//
// Chronicles card showing archive statistics.
// Displays total entry count, this week, this month,
// and a breakdown of entries by type sorted by count.

import SwiftUI

struct StatsCard: View {
    let entries: [Entry]
    var style: any AppThemeStyle
    let themeManager: ThemeManager
    
    var totalEntries: Int { entries.count }
    
    var entriesThisWeek: Int {
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: Date()
        )) ?? Date()
        return entries.filter { $0.createdAt >= weekStart }.count
    }
    
    var entriesThisMonth: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let monthStart = calendar.date(from: components) ?? Date()
        return entries.filter { $0.createdAt >= monthStart }.count
    }
    
    var entryCountsByType: [(type: EntryType, count: Int)] {
        EntryType.allCases.compactMap { type in
            let count = entries.filter { $0.type == type }.count
            return count > 0 ? (type, count) : nil
        }.sorted { $0.count > $1.count }
    }
    
    var body: some View {
        ChroniclesCardContainer(title: "Your Archive", icon: "archivebox") {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    statCell(value: "\(totalEntries)", label: "Total")
                    statCell(value: "\(entriesThisMonth)", label: "This month")
                    statCell(value: "\(entriesThisWeek)", label: "This week")
                }
                Divider()
                    .overlay(ChroniclesTheme.sectionDivider)
                VStack(spacing: 6) {
                    ForEach(entryCountsByType, id: \.type) { item in
                        HStack(spacing: 4) {
                            Image(systemName: item.type.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(item.type.accentColor(for: themeManager.current))
                                .frame(width: 16)
                            Text(item.type.displayName)
                                .font(style.typeBodySecondary)
                                .foregroundStyle(ChroniclesTheme.primaryText)
                                .fixedSize()
                            GeometryReader { geo in
                                Path { path in
                                    let y = geo.size.height - 1
                                    var x: CGFloat = 0
                                    while x < geo.size.width {
                                        path.move(to: CGPoint(x: x, y: y))
                                        path.addLine(to: CGPoint(x: x + 2, y: y))
                                        x += 6
                                    }
                                }
                                .stroke(ChroniclesTheme.tertiaryText, lineWidth: 1)
                            }
                            .frame(height: 12)
                            Text("\(item.count)")
                                .font(style.typeBodySecondary)
                                .foregroundStyle(ChroniclesTheme.secondaryText)
                                .fixedSize()
                        }
                    }
                }
            }
        }
    }
    
    func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(ChroniclesTheme.accentAmber)
            Text(label)
                .font(style.typeCaption)
                .foregroundStyle(ChroniclesTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(ChroniclesTheme.statBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
