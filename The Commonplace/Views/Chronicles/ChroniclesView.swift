// ChroniclesView.swift
// Commonplace
//
// The Chronicles tab — a retrospective space for browsing your archive over time.
// Complements Today (present tense) with a past-tense perspective on your life.
//
// Mental model: Today = present tense. Chronicles = past tense.
//
// Launch cards (v2.0):
//   1. On This Day    — entries from this date in past years
//   2. Mood Timeline  — 14-day sentiment chart (wraps MoodTimelineView)
//   3. Stats          — entry counts, totals, streaks
//   4. Watch Timeline — chronological media log across all entries
//   5. Habit Patterns — completion rates and streaks over time
//
// Architecture:
//   Each insight is a self-contained card in a vertical scroll.
//   New cards added per release — no restructuring needed.
//   Gift Cards (ambient nudges) are NOT in this view — they surface
//   contextually throughout the app when the data earns it.

import SwiftUI
import SwiftData

struct ChroniclesView: View {
    @Query(sort: \Entry.createdAt, order: .reverse) var entries: [Entry]
    @Query(sort: \Habit.order) var habits: [Habit]
    @EnvironmentObject var themeManager: ThemeManager

    var style: any AppThemeStyle { themeManager.style }

    // MARK: - On This Day

    var onThisDayEntries: [Entry] {
        let calendar = Calendar.current
        let today = Date()
        let currentMonth = calendar.component(.month, from: today)
        let currentDay = calendar.component(.day, from: today)
        let currentYear = calendar.component(.year, from: today)

        return entries.filter { entry in
            let month = calendar.component(.month, from: entry.createdAt)
            let day = calendar.component(.day, from: entry.createdAt)
            let year = calendar.component(.year, from: entry.createdAt)
            return month == currentMonth && day == currentDay && year != currentYear
        }
    }

    // MARK: - Stats

    var totalEntries: Int { entries.count }

    var entriesThisWeek: Int {
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
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

    // MARK: - Watch Timeline

    var mediaEntries: [Entry] {
        entries.filter { $0.type == .media && !$0.mediaLog.isEmpty }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    chroniclesHeader
                    onThisDayCard
                    moodTimelineCard
                    statsCard
                    watchTimelineCard
                    habitPatternsCard
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 16)
            }
            .background(style.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
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

    // MARK: - Card Container

    func chroniclesCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ChroniclesTheme.accentAmber)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(ChroniclesTheme.accentAmber)
            }
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ChroniclesTheme.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(ChroniclesTheme.cardBorderGradient, lineWidth: 0.5)
                )
        )
    }

    // MARK: - On This Day Card

    @ViewBuilder
    var onThisDayCard: some View {
        if onThisDayEntries.isEmpty {
            chroniclesCard(title: "On This Day", icon: "calendar") {
                Text("No entries from this date in previous years yet. Keep capturing — your archive grows with time.")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.tertiaryText)
            }
        } else {
            chroniclesCard(title: "On This Day", icon: "calendar") {
                VStack(spacing: 10) {
                    ForEach(onThisDayEntries.prefix(3)) { entry in
                        NavigationLink(destination: NavigationRouter.destination(for: entry)) {
                            onThisDayRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        if entry.id != onThisDayEntries.prefix(3).last?.id {
                            Divider()
                                .overlay(ChroniclesTheme.sectionDivider)
                        }
                    }
                    if onThisDayEntries.count > 3 {
                        Text("\(onThisDayEntries.count - 3) more from this date")
                            .font(style.typeCaption)
                            .foregroundStyle(ChroniclesTheme.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
    }

    func onThisDayRow(entry: Entry) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(yearsAgoText(for: entry.createdAt))
                    .font(style.typeCaption)
                    .foregroundStyle(ChroniclesTheme.accentAmber)
                Text(entryPreviewText(for: entry))
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.primaryText)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: entry.type.icon)
                .font(.system(size: 12))
                .foregroundStyle(ChroniclesTheme.tertiaryText)
        }
    }

    func yearsAgoText(for date: Date) -> String {
        let years = Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
        return years == 1 ? "1 year ago" : "\(years) years ago"
    }

    func entryPreviewText(for entry: Entry) -> String {
        switch entry.type {
        case .location: return entry.locationName ?? "A place"
        case .link:     return entry.linkTitle ?? entry.url ?? "A link"
        case .media:    return entry.mediaTitle ?? "A media entry"
        case .music:    return entry.linkTitle ?? "A track"
        default:
            let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? entry.type.displayName : text
        }
    }

    // MARK: - Mood Timeline Card

    var moodTimelineCard: some View {
        let journalEntries = entries.filter { $0.type == .journal }
        return chroniclesCard(title: "Mood", icon: "waveform.path.ecg") {
            if journalEntries.isEmpty {
                Text("Start journaling to see your mood patterns over time.")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.tertiaryText)
            } else {
                MoodTimelineView(entries: entries)
            }
        }
    }

    // MARK: - Stats Card

    var statsCard: some View {
        chroniclesCard(title: "Your Archive", icon: "archivebox") {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    statCell(value: "\(totalEntries)", label: "Total")
                    statCell(value: "\(entriesThisMonth)", label: "This month")
                    statCell(value: "\(entriesThisWeek)", label: "This week")
                }
                Divider()
                    .overlay(ChroniclesTheme.sectionDivider)
                VStack(spacing: 6) {
                    ForEach(entryCountsByType.prefix(5), id: \.type) { item in
                        HStack {
                            Image(systemName: item.type.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(item.type.accentColor(for: themeManager.current))
                                .frame(width: 16)
                            Text(item.type.displayName)
                                .font(style.typeBodySecondary)
                                .foregroundStyle(ChroniclesTheme.primaryText)
                            Spacer()
                            Text("\(item.count)")
                                .font(style.typeBodySecondary)
                                .foregroundStyle(ChroniclesTheme.secondaryText)
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

    // MARK: - Watch Timeline Card

    @ViewBuilder
    var watchTimelineCard: some View {
        chroniclesCard(title: "Watch Timeline", icon: "film.stack") {
            if mediaEntries.isEmpty {
                Text("Your watched movies and shows will appear here as you log them.")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.tertiaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(watchLogItems.prefix(5), id: \.date) { item in
                        watchLogRow(item: item)
                        if item.date != watchLogItems.prefix(5).last?.date {
                            Divider()
                                .overlay(ChroniclesTheme.sectionDivider)
                                .padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    struct WatchLogItem {
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

    // MARK: - Habit Patterns Card

    @ViewBuilder
    var habitPatternsCard: some View {
        let journalEntries = entries.filter { $0.type == .journal && !$0.completedHabitSnapshots.isEmpty }
        chroniclesCard(title: "Habit Patterns", icon: "checkmark.circle") {
            if habits.isEmpty || journalEntries.isEmpty {
                Text("Complete habits in your daily journal to see your patterns here.")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.tertiaryText)
            } else {
                VStack(spacing: 8) {
                    ForEach(habits.prefix(5)) { habit in
                        habitPatternRow(habit: habit, journalEntries: journalEntries)
                    }
                }
            }
        }
    }

    func habitPatternRow(habit: Habit, journalEntries: [Entry]) -> some View {
        let completed = journalEntries.filter {
            $0.completedHabits.contains(habit.id.uuidString)
        }.count
        let total = journalEntries.count
        let rate = total > 0 ? Double(completed) / Double(total) : 0

        return HStack(spacing: 10) {
            Image(systemName: habit.icon)
                .font(.system(size: 13))
                .foregroundStyle(rateColor(rate))
                .frame(width: 24)
            Text(habit.name)
                .font(style.typeBodySecondary)
                .foregroundStyle(ChroniclesTheme.primaryText)
            Spacer()
            Text("\(Int(rate * 100))%")
                .font(style.typeBodySecondary)
                .fontWeight(.medium)
                .foregroundStyle(rateColor(rate))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ChroniclesTheme.statBackground)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(rateColor(rate))
                        .frame(width: geo.size.width * rate)
                }
            }
            .frame(width: 60, height: 6)
        }
    }

    func rateColor(_ rate: Double) -> Color {
        if rate >= 0.7 { return .green }
        if rate >= 0.4 { return ChroniclesTheme.accentAmber }
        return .red.opacity(0.8)
    }
}
