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
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    chroniclesHeader
                    DogEarsCard(entries: entries, style: style)
                    OnThisDayCard(entries: entries, style: style, themeManager: themeManager)
                    MoodTimelineCard(entries: entries, style: style)
                    StatsCard(entries: entries, style: style, themeManager: themeManager)
                    WatchTimelineCard(entries: entries, style: style)
                    HabitPatternsCard(entries: entries, habits: habits, style: style)
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
    
}
