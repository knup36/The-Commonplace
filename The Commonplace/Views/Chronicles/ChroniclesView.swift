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

        // MARK: - Card order

        // Stored as comma-separated string since AppStorage doesn't support [String]
        @AppStorage("chronicles_card_order") private var cardOrderString: String =
            "dogEars,onThisDay,mood,stats,watchTimeline,habitPatterns"

        @State private var showingReorder = false

        var cardOrder: [String] {
            get { cardOrderString.components(separatedBy: ",") }
        }

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
                VStack(spacing: 16) {
                                    chroniclesHeader
                                    ForEach(cardOrder, id: \.self) { cardID in
                                        switch cardID {
                                        case "dogEars":
                                            DogEarsCard(
                                                stickyEntries: stickyEntries,
                                                laterEntries: laterEntries,
                                                style: style
                                            )
                                        case "onThisDay":
                                            OnThisDayCard(
                                                oneMonthAgoEntries: oneMonthAgoEntries,
                                                style: style,
                                                themeManager: themeManager
                                            )
                                        case "mood":
                                            MoodTimelineCard(
                                                journalEntries: journalEntries,
                                                style: style
                                            )
                                        case "stats":
                                            StatsCard(
                                                totalEntries: totalEntries,
                                                entriesThisWeek: entriesThisWeek,
                                                entriesThisMonth: entriesThisMonth,
                                                entryCountsByType: entryCountsByType,
                                                style: style,
                                                themeManager: themeManager
                                            )
                                        case "watchTimeline":
                                            WatchTimelineCard(
                                                mediaEntries: mediaEntries,
                                                style: style
                                            )
                                        case "habitPatterns":
                                            HabitPatternsCard(
                                                journalEntries: journalEntries,
                                                habits: habits,
                                                style: style
                                            )
                                        default:
                                            EmptyView()
                                        }
                                    }
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
                Button {
                    showingReorder = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(style.secondaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
            .sheet(isPresented: $showingReorder) {
                ChroniclesReorderView(cardOrder: Binding(
                    get: { cardOrder },
                    set: { cardOrderString = $0.joined(separator: ",") }
                ))
            }
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

        // One month ago window (30-32 days)
                if let windowStart = calendar.date(byAdding: .day, value: -32, to: now),
                   let windowEnd   = calendar.date(byAdding: .day, value: -30, to: now) {
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
