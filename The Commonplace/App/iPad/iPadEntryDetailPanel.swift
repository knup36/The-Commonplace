// iPadEntryDetailPanel.swift
// Commonplace
//
// Shared right column detail panel for all iPad tabs.
//
// Two states:
//   - Empty (no entry selected): floating archive stats rendered directly
//     on the panel background — total, this month, this week, plus a type
//     breakdown. No card wrapper; quiet and elegant.
//   - Selected: the entry's existing detail view rendered inside a rounded
//     card that sits within the panel with padding on all sides, giving it
//     a physical "lifted paper" feel.
//
// Used by all tabs that have a detail column:
//   Feed    → iPadEntryDetailPanel(selectedEntry: $selectedFeedEntry)
//   Library → iPadEntryDetailPanel(selectedEntry: $selectedLibraryEntry)
//   Today   → iPadEntryDetailPanel(selectedEntry: $selectedTodayEntry)
//   Home    → iPadEntryDetailPanel(selectedEntry: $selectedHomeEntry)
//   Chronicles (future) → iPadEntryDetailPanel(selectedEntry: $selectedChroniclesEntry)
//
// Stats data is computed here via @Query, mirroring ChroniclesView logic.
// Detail views are rendered via NavigationRouter.destination(for:) —
// zero duplication of detail view code.
//
// Right column rule: this panel is always reserved for entry detail cards.
// No feeds, grids, or lists may live in the right column. This is what
// enables the consistent floating card treatment, bgColor bleed, and
// slide/scale animations across all tabs. No exceptions.

import SwiftUI
import SwiftData

struct iPadEntryDetailPanel: View {
    @Binding var selectedEntry: Entry?

    @Query(sort: \Entry.createdAt, order: .reverse) private var allEntries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager

    var style: any AppThemeStyle { themeManager.style }

    // MARK: - Stats

    private var totalEntries: Int { allEntries.count }

    private var entriesThisWeek: Int {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return allEntries.filter { $0.createdAt >= start }.count
    }

    private var entriesThisMonth: Int {
        let start = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return allEntries.filter { $0.createdAt >= start }.count
    }

    private var entryCountsByType: [(type: EntryType, count: Int)] {
        EntryType.allCases.compactMap { type in
            let count = allEntries.filter { $0.type == type }.count
            return count > 0 ? (type: type, count: count) : nil
        }
        .sorted { $0.count > $1.count }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            style.background.ignoresSafeArea()

            if let entry = selectedEntry {
                entryCard(for: entry)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .scale(scale: 0.94).combined(with: .opacity)
                    ))
                    .zIndex(1)
            } else {
                floatingStats
                    .transition(.opacity)
                    .zIndex(0)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: selectedEntry?.id)
    }

    // MARK: - Entry Card

    private func entryCard(for entry: Entry) -> some View {
        let bgColor = entry.type.cardColor(for: themeManager.current)
        return GeometryReader { geo in
            ScrollView {
                NavigationRouter.destination(for: entry)
                    .frame(minHeight: geo.size.height)
            }
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(style.cardBorder, lineWidth: 0.5)
            )
        }
        .padding(.top, 4)
        .padding(.horizontal, 16)
        .id(entry.id)
    }

    // MARK: - Floating Stats (empty state)

    private var floatingStats: some View {
        VStack(spacing: 32) {
            statsSummaryRow
            Divider()
                .overlay(style.cardDivider)
                .padding(.horizontal, 32)
            typeBreakdown
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: 380)
    }

    private var statsSummaryRow: some View {
        HStack(spacing: 0) {
            floatingStat(value: "\(totalEntries)", label: "Total")
            floatingStat(value: "\(entriesThisMonth)", label: "This month")
            floatingStat(value: "\(entriesThisWeek)", label: "This week")
        }
    }

    private func floatingStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(style.primaryText)
            Text(label)
                .font(style.typeCaption)
                .foregroundStyle(style.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var typeBreakdown: some View {
        VStack(spacing: 10) {
            ForEach(entryCountsByType, id: \.type) { item in
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(item.type.accentColor(for: themeManager.current).opacity(0.15))
                            .frame(width: 22, height: 22)
                        Image(systemName: item.type.icon)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(item.type.accentColor(for: themeManager.current))
                    }
                    Text(item.type.displayName)
                        .font(style.typeBodySecondary)
                        .foregroundStyle(style.secondaryText)
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
                        .stroke(style.cardDivider.opacity(0.6), lineWidth: 1)
                    }
                    .frame(height: 12)
                    Text("\(item.count)")
                        .font(style.typeBodySecondary)
                        .fontWeight(.medium)
                        .foregroundStyle(style.tertiaryText)
                        .fixedSize()
                }
            }
        }
    }
}
