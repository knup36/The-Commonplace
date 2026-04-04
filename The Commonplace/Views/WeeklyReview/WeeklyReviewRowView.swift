// WeeklyReviewRowView.swift
// Commonplace
//
// Feed card for weekly review journal entries.
// Identified by entry.tagNames.contains("weekly-review").
// Visually distinct from regular entries — purple to blue gradient
// background with gold ring border.
//
// Shows: week date range, entry count, habit completion,
// average mood, and first line of the highlight reflection.

import SwiftUI

struct WeeklyReviewRowView: View {
    let entry: Entry
    @EnvironmentObject var themeManager: ThemeManager
    
    var style: any AppThemeStyle { themeManager.style }
    
    var weekRange: String {
        guard let weekStart = weekStartDate else { return "" }
        let calendar = Calendar.current
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let fmtYear = DateFormatter()
        fmtYear.dateFormat = "MMM d, yyyy"
        return "\(fmt.string(from: weekStart)) — \(fmtYear.string(from: weekEnd))"
    }
    
    var weekStartDate: Date? {
        Calendar.current.dateInterval(of: .weekOfYear, for: entry.createdAt)?.start
    }
    
    var stats: [String: String] {
        guard let data = entry.weeklyReviewStats,
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return decoded
    }
    
    var entryCount: Int {
        Int(stats["entries"] ?? "") ?? 0
    }
    
    var habitSummary: String? {
        stats["habits"]
    }
    
    var averageMoodEmoji: String? {
        stats["avgmood"]
    }
    
    var highlightPreview: String? {
        guard let text = entry.weeklyReviewHighlight, !text.isEmpty else { return nil }
        return "\"\(text)\""
    }
    
    var body: some View {
        ZStack {
            // Gold ring border
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(WeeklyReviewTheme.goldRingGradient, lineWidth: 2)
            
            // Gradient card
            RoundedRectangle(cornerRadius: 15)
                .fill(WeeklyReviewTheme.cardGradient)
                .padding(2)
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 6) {
                    Text("✦")
                        .font(.system(size: 12))
                        .foregroundStyle(WeeklyReviewTheme.accentGold)
                    Text("Weekly Review")
                        .font(AppTypeScale.bodySecondary)
                        .foregroundStyle(WeeklyReviewTheme.primaryText)
                }
                
                // Date range
                Text(weekRange)
                    .font(AppTypeScale.caption)
                    .foregroundStyle(WeeklyReviewTheme.secondaryText)
                
                // Stats pills
                HStack(spacing: 6) {
                    if entryCount > 0 {
                        statPill("\(entryCount) entries")
                    }
                    if let habits = habitSummary {
                        statPill(habits)
                    }
                    if let mood = averageMoodEmoji {
                        statPill("\(mood) avg mood")
                    }
                }
                
                // Highlight preview
                if let preview = highlightPreview {
                    Text(preview)
                        .font(AppTypeScale.caption)
                        .italic()
                        .foregroundStyle(WeeklyReviewTheme.secondaryText)
                        .lineLimit(2)
                }
                
                // Tag
                Text("#weekly-review")
                    .font(AppTypeScale.sectionHeader)
                    .foregroundStyle(WeeklyReviewTheme.accentPurple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(WeeklyReviewTheme.tagBackground)
                    .clipShape(Capsule())
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity)
    }
    
    func statPill(_ text: String) -> some View {
        Text(text)
            .font(AppTypeScale.sectionHeader)
            .foregroundStyle(Color(hex: "#C8B9FF").opacity(0.9))
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
    }
}
