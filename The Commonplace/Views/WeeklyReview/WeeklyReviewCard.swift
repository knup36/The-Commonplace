// WeeklyReviewCard.swift
// Commonplace
//
// Sunday prompt card shown in the Today tab above the journal block.
// Only appears on Sundays when no weekly review has been completed this week.
// Tapping "Start Review" opens WeeklyReviewFlowView as a full screen cover.
//
// Dismissed automatically once a weekly review entry is saved.

import SwiftUI
import SwiftData

struct WeeklyReviewCard: View {
    @Query var allEntries: [Entry]
    @Query(sort: \Tag.name) var allPersonTags: [Tag]
    var allPersons: [Tag] { allPersonTags.filter { $0.isPerson } }
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingReview = false
    
    var style: any AppThemeStyle { themeManager.style }
    
    var hasReviewedThisWeek: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = weekday == 1 ? 6 : weekday - 2
        let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
        return allEntries.contains {
            $0.tagNames.contains(WeeklyReviewTheme.weeklyReviewTag) &&
            $0.createdAt >= weekStart
        }
    }

    var isSunday: Bool {
        Calendar.current.component(.weekday, from: Date()) == 1
    }

    var entryCountThisWeek: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = weekday == 1 ? 6 : weekday - 2
        let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
        return allEntries.filter {
            $0.createdAt >= weekStart &&
            $0.createdAt < weekEnd &&
            !$0.tagNames.contains(WeeklyReviewTheme.weeklyReviewTag)
        }.count
    }

    var body: some View {
        if isSunday && !hasReviewedThisWeek {
            ZStack {
                // Gold ring border
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(WeeklyReviewTheme.goldRingGradient, lineWidth: 2)

                // Gradient background
                RoundedRectangle(cornerRadius: 15)
                    .fill(WeeklyReviewTheme.cardGradient)
                    .padding(2)

                // Content
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("✦")
                                .font(.system(size: 12))
                                .foregroundStyle(WeeklyReviewTheme.accentGold)
                            Text("Your week is ready to review")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(WeeklyReviewTheme.primaryText)
                        }
                        Text("\(entryCountThisWeek) entries captured this week")
                            .font(.system(size: 12))
                            .foregroundStyle(WeeklyReviewTheme.secondaryText)
                    }
                    Spacer()
                    Button {
                        showingReview = true
                    } label: {
                        Text("Start")
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
            .padding(.horizontal)
            .fullScreenCover(isPresented: $showingReview) {
                WeeklyReviewFlowView(
                    allEntries: allEntries,
                    allPersons: allPersons
                )
            }
        }
    }
}
