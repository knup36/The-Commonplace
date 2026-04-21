// ChroniclesView.swift
// Commonplace
//
// The Chronicles tab — a retrospective space for browsing your archive over time.
// Complements Today (present tense) with a past-tense perspective on your life.
//
// Performance note (v2.4):
//   All expensive filtering is pre-computed here as @State vars, populated
//   once on appear via computeData(). Individual cards receive pre-filtered
//   arrays rather than computing from the full entry set on every render.
//   This eliminates repeated O(n) passes across multiple cards simultaneously.

import SwiftUI
import SwiftData

struct ChroniclesView: View {
    @Query(sort: \Entry.createdAt, order: .reverse) var entries: [Entry]
    @Query(sort: \Habit.order) var habits: [Habit]
    @EnvironmentObject var themeManager: ThemeManager

    var style: any AppThemeStyle { themeManager.style }

    // MARK: - Pre-computed data

    @State private var journalEntries: [Entry] = []
    @State private var mediaEntries: [Entry] = []
    @State private var stickyEntries: [Entry] = []
    @State private var laterEntries: [Entry] = []
    @State private var oneMonthAgoEntries: [Entry] = []
    @State private var entryCountsByType: [(type: EntryType, count: Int)] = []
    @State private var totalEntries: Int = 0
    @State private var entriesThisWeek: Int = 0
    @State private var entriesThisMonth: Int = 0

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    chroniclesHeader
                    DogEarsCard(
                        stickyEntries: stickyEntries,
                        laterEntries: laterEntries,
                        style: style
                    )
                    OnThisDayCard(
                        oneMonthAgoEntries: oneMonthAgoEntries,
                        style: style,
                        themeManager: themeManager
                    )
                    MoodTimelineCard(
                        journalEntries: journalEntries,
                        style: style
                    )
                    StatsCard(
                        totalEntries: totalEntries,
                        entriesThisWeek: entriesThisWeek,
                        entriesThisMonth: entriesThisMonth,
                        entryCountsByType: entryCountsByType,
                        style: style,
                        themeManager: themeManager
                    )
                    WatchTimelineCard(
                        mediaEntries: mediaEntries,
                        style: style
                    )
                    HabitPatternsCard(
                        journalEntries: journalEntries,
                        habits: habits,
                        style: style
                    )
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 16)
            }
            .background(style.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Entry.self) { entry in
                NavigationRouter.destination(for: entry)
            }
        }
        .onAppear { computeData() }
        .onChange(of: entries.count) { _, _ in computeData() }
    }

    // MARK: - Header

    var chroniclesHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Chronicles")
                    .font(style.typeLargeTitle)
                    .foregroundStyle(style.primaryText)
                Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.secondaryText)
            }
            Spacer()
            Text(ChroniclesTheme.headerSymbol)
                .font(.system(size: 20))
                .foregroundStyle(ChroniclesTheme.accentAmber)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Pre-computation

    func computeData() {
        let calendar = Calendar.current
        let now = Date()

        // Journal entries
        journalEntries = entries.filter { $0.type == .journal }

        // Media entries with logs
        mediaEntries = entries.filter {
                    $0.type == .media && (
                        !$0.mediaLog.isEmpty ||
                        ["inProgress", "rewatch", "replay"].contains($0.mediaStatus)
                    )
                }

        // Stickies with unchecked items
        stickyEntries = entries.filter { entry in
            guard entry.type == .sticky else { return false }
            return entry.stickyItems.contains { raw in
                let id = raw.components(separatedBy: "::").first ?? ""
                return !entry.stickyChecked.contains(id)
            }
        }

        // Later-tagged entries
        laterEntries = entries.filter { $0.tagNames.contains("later") }

        // One month ago window (28-35 days)
        if let windowStart = calendar.date(byAdding: .day, value: -35, to: now),
           let windowEnd   = calendar.date(byAdding: .day, value: -28, to: now) {
            oneMonthAgoEntries = entries.filter {
                $0.createdAt >= windowStart && $0.createdAt <= windowEnd
            }
        }

        // Stats
        totalEntries = entries.count

        if let weekStart = calendar.date(from: calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: now
        )) {
            entriesThisWeek = entries.filter { $0.createdAt >= weekStart }.count
        }

        if let monthStart = calendar.date(from: calendar.dateComponents(
            [.year, .month], from: now
        )) {
            entriesThisMonth = entries.filter { $0.createdAt >= monthStart }.count
        }

        entryCountsByType = EntryType.allCases.compactMap { type in
            let count = entries.filter { $0.type == type }.count
            return count > 0 ? (type, count) : nil
        }.sorted { $0.count > $1.count }
    }
}
