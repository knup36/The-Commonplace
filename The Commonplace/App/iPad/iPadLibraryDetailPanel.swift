// iPadLibraryDetailPanel.swift
// Commonplace
//
// iPad Library tab — detail column of NavigationSplitView.
//
// Intentionally mirrors iPadFeedDetailPanel in structure and visual style.
//
// Two states:
//   - Empty (no entry selected): floating archive stats on panel background.
//   - Selected: entry detail rendered inside a floating rounded card,
//     identical to the feed detail panel card treatment.
//
// The feed (CollectionDetailView, PersonDetailView, iPadTagFeedPanel) lives
// in the content column (iPadLibraryView) which navigates internally between
// the list and the feed. This panel is purely for entry detail — it never
// shows a feed.
//
// selectedEntry is owned by iPadRootView and passed as a binding to both
// iPadLibraryView (sets it on entry tap) and here (reads it to render card).

import SwiftUI
import SwiftData

struct iPadLibraryDetailPanel: View {
    @Binding var selectedEntry: Entry?

    @Query(sort: \Entry.createdAt, order: .reverse) private var allEntries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager

    var style: any AppThemeStyle { themeManager.style }

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
    // Identical to iPadFeedDetailPanel.entryCard:
    // GeometryReader + minHeight fills card with bgColor on rubber-band overscroll.

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
    // Identical to iPadFeedDetailPanel.floatingStats.

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
        let now = Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let thisMonth = allEntries.filter { $0.createdAt >= startOfMonth }.count
        let thisWeek = allEntries.filter { $0.createdAt >= startOfWeek }.count

        return HStack(spacing: 0) {
            floatingStat(value: "\(allEntries.count)", label: "Total")
            floatingStat(value: "\(thisMonth)", label: "This month")
            floatingStat(value: "\(thisWeek)", label: "This week")
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
        let typeCounts: [(type: EntryType, count: Int)] = EntryType.allCases.compactMap { type in
            let count = allEntries.filter { $0.type == type }.count
            return count > 0 ? (type: type, count: count) : nil
        }.sorted { $0.count > $1.count }

        return VStack(spacing: 10) {
            ForEach(typeCounts, id: \.type) { item in
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

// MARK: - iPadTagFeedPanel

// Content column view for a selected tag.
// Shows a slim feed of entries tagged with tagName.
// Tapping an entry calls onSelect to set selectedEntry in iPadRootView,
// which iPadLibraryDetailPanel renders as a floating card.

struct iPadTagFeedPanel: View {
    let tagName: String
    var onSelect: (Entry) -> Void

    @Query var allEntries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager

    var style: any AppThemeStyle { themeManager.style }

    var taggedEntries: [Entry] {
        allEntries
            .filter { $0.tagNames.contains(tagName) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(tagName)")
                        .font(style.typeLargeTitle)
                        .foregroundStyle(style.primaryText)
                    Text("\(taggedEntries.count) \(taggedEntries.count == 1 ? "entry" : "entries")")
                        .font(style.typeCaption)
                        .foregroundStyle(style.secondaryText)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if taggedEntries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tag")
                            .font(.system(size: 36))
                            .foregroundStyle(style.tertiaryText)
                        Text("No entries tagged #\(tagName)")
                            .font(style.typeBody)
                            .foregroundStyle(style.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    SlimEntryFeed(entries: taggedEntries, style: style) { entry in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            onSelect(entry)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer().frame(height: 40)
            }
        }
        .background(style.background.ignoresSafeArea())
    }
}
