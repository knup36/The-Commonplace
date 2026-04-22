// StatsCard.swift
// Commonplace
//
// Chronicles card showing archive statistics.
// Receives pre-computed counts from ChroniclesView —
// no filtering or counting performed at render time.
//
// Updated v2.4 — pre-computed data, charcoal card, colored type breakdown.

import SwiftUI

struct StatsCard: View {
    let totalEntries: Int
    let entriesThisWeek: Int
    let entriesThisMonth: Int
    let entryCountsByType: [(type: EntryType, count: Int)]
    var style: any AppThemeStyle
    let themeManager: ThemeManager

    var body: some View {
        ChroniclesCardContainer(title: "Your Archive", icon: "archivebox", cardID: "stats", background: .parchment) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    statCell(value: "\(totalEntries)", label: "Total")
                    statCell(value: "\(entriesThisMonth)", label: "This month")
                    statCell(value: "\(entriesThisWeek)", label: "This week")
                }
                Divider()
                    .overlay(Color.white.opacity(0.1))
                VStack(spacing: 8) {
                    ForEach(entryCountsByType, id: \.type) { item in
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(item.type.accentColor(for: themeManager.current).opacity(0.2))
                                    .frame(width: 22, height: 22)
                                Image(systemName: item.type.icon)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(item.type.accentColor(for: themeManager.current))
                            }
                            Text(item.type.displayName)
                                .font(style.typeBodySecondary)
                                .foregroundStyle(Color.white.opacity(0.75))
                                .fixedSize()
                            GeometryReader { geo in
                                Path { path in
                                    let y = geo.size.height / 2
                                    var x: CGFloat = 0
                                    while x < geo.size.width {
                                        path.move(to: CGPoint(x: x, y: y))
                                        path.addLine(to: CGPoint(x: x + 2, y: y))
                                        x += 6
                                    }
                                }
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            }
                            .frame(height: 12)
                            Text("\(item.count)")
                                .font(style.typeBodySecondary)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.white.opacity(0.5))
                                .fixedSize()
                        }
                    }
                }
            }
        }
    }

    func statCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
            Text(label)
                .font(style.typeCaption)
                .foregroundStyle(Color.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}
