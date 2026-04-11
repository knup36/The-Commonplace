// WeeklyReviewCard.swift
// Commonplace
//
// Persistent review prompt shown in the Today tab above the journal block.
// Shows one card per unreviewed completed week (Sunday–Saturday).
// Stacks multiple cards if multiple weeks are unreviewed — newest first.
// Cannot be dismissed — only completing the review clears the card.
//
// Week definition: Sunday through Saturday.
// The most recently completed week always ends last Saturday.
// Looks back up to 8 weeks to find unreviewed weeks.

import SwiftUI
import SwiftData

struct WeeklyReviewCard: View {
    @Query var allEntries: [Entry]
    @Query(sort: \Tag.name) var allPersonTags: [Tag]
    var allPersons: [Tag] { allPersonTags.filter { $0.isPerson } }
    @EnvironmentObject var themeManager: ThemeManager
    @State private var reviewingWeekStart: IdentifiableDate? = nil

    var style: any AppThemeStyle { themeManager.style }

    // MARK: - Week Calculation

    /// The most recently completed Sunday — always the anchor
    var lastSunday: Date {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let weekday = calendar.component(.weekday, from: today)
            // Only show completed weeks — a week completes when Saturday has passed
            // weekday: 1=Sun, 2=Mon... 7=Sat
            // On Sunday (1): last completed Sunday was 7 days ago
            // On any other day: go back to last Sunday, then back one more week
            // since the current week isn't complete yet
            let daysToLastSunday = weekday == 1 ? 7 : weekday - 1
            let lastSun = calendar.date(byAdding: .day, value: -daysToLastSunday, to: today) ?? today
            // If today is Sunday, the week that JUST ended (last Sun to yesterday Sat) is reviewable
            // If today is Mon-Sat, go back one more week since current week isn't done
            return weekday == 1 ? lastSun : calendar.date(byAdding: .day, value: -7, to: lastSun) ?? lastSun
        }

    /// Returns the start (Sunday) of the Nth most recent completed week
    /// week 0 = most recent completed week, week 1 = week before that, etc.
    func weekStart(weeksAgo: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: -(weeksAgo * 7), to: lastSunday) ?? lastSunday
    }

    func weekEnd(for start: Date) -> Date {
        let calendar = Calendar.current
        // End is Saturday = start + 6 days, end of that day
        return calendar.date(byAdding: .day, value: 7, to: start) ?? start
    }

    /// All unreviewed completed weeks, newest first, up to 8 weeks back
    var unreviewedWeeks: [Date] {
        (0..<8).compactMap { weeksAgo -> Date? in
            let start = weekStart(weeksAgo: weeksAgo)
            let end = weekEnd(for: start)
            let hasReview = allEntries.contains {
                $0.tagNames.contains(WeeklyReviewTheme.weeklyReviewTag) &&
                $0.createdAt >= start &&
                $0.createdAt < end
            }
            return hasReview ? nil : start
        }
    }

    func entryCount(for weekStart: Date) -> Int {
        let end = weekEnd(for: weekStart)
        return allEntries.filter {
            $0.createdAt >= weekStart &&
            $0.createdAt < end &&
            !$0.tagNames.contains(WeeklyReviewTheme.weeklyReviewTag)
        }.count
    }

    func weekRangeString(for weekStart: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let end = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return "\(fmt.string(from: weekStart)) – \(fmt.string(from: end))"
    }

    // MARK: - Body

    var body: some View {
        ForEach(unreviewedWeeks, id: \.self) { weekStart in
            reviewCard(for: weekStart)
                .padding(.horizontal)
        }
        .fullScreenCover(item: $reviewingWeekStart) { identifiable in
                    WeeklyReviewFlowView(
                        allEntries: allEntries,
                        allPersons: allPersons,
                        weekStart: identifiable.date
                    )
                }
    }

    // MARK: - Card

    func reviewCard(for weekStart: Date) -> some View {
        ZStack {
            // Gold ring border
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(WeeklyReviewTheme.goldRingGradient, lineWidth: 2)

            // Gradient background
            RoundedRectangle(cornerRadius: 15)
                .fill(WeeklyReviewTheme.cardGradient)
                .padding(2)

            // Content
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Text("✦")
                            .font(.system(size: 12))
                            .foregroundStyle(WeeklyReviewTheme.accentGold)
                        Text("Week of \(weekRangeString(for: weekStart))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(WeeklyReviewTheme.primaryText)
                    }
                    Spacer()
                }
                Text("\(entryCount(for: weekStart)) entries captured")
                    .font(.system(size: 12))
                    .foregroundStyle(WeeklyReviewTheme.secondaryText)
                Button {
                    reviewingWeekStart = IdentifiableDate(date: weekStart)
                } label: {
                    Text("Start Review")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(WeeklyReviewTheme.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#534AB7").opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(WeeklyReviewTheme.accentPurple.opacity(0.4), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
    }
}
struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}
