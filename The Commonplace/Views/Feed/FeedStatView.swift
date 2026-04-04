import SwiftUI
import SwiftData

// MARK: - FeedStatsView
// Stats summary shown in the Today tab under the Stats segment.
// Shows total entries, per-type icon grid, capturing days, streak,
// most active day of week, and entries this week/month.
// Screen: Today tab → Stats segment

struct FeedStatsView: View {
    let entries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager
    
    var style: any AppThemeStyle { themeManager.style }
    var accentColor: Color { style.accent }
    
    // MARK: - Computed stats
    
    var totalEntries: Int { entries.count }
    
    var countsByType: [(type: EntryType, count: Int)] {
        EntryType.allCases.compactMap { type in
            let count = entries.filter { $0.type == type }.count
            return count > 0 ? (type: type, count: count) : nil
        }
    }
    
    var daysSinceFirst: Int? {
        guard let first = entries.map({ $0.createdAt }).min() else { return nil }
        return Calendar.current.dateComponents([.day], from: first, to: Date()).day
    }
    
    var currentStreak: Int {
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())
        let entryDays = Set(entries.map { Calendar.current.startOfDay(for: $0.createdAt) })
        while entryDays.contains(checkDate) {
            streak += 1
            checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate)!
        }
        return streak
    }
    
    var mostActiveDay: String? {
        guard !entries.isEmpty else { return nil }
        let calendar = Calendar.current
        var dayCounts: [Int: Int] = [:]
        for entry in entries {
            let weekday = calendar.component(.weekday, from: entry.createdAt)
            dayCounts[weekday, default: 0] += 1
        }
        guard let maxWeekday = dayCounts.max(by: { $0.value < $1.value })?.key else { return nil }
        let formatter = DateFormatter()
        return formatter.weekdaySymbols[maxWeekday - 1]
    }
    
    var entriesThisWeek: Int {
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return entries.filter { $0.createdAt >= startOfWeek }.count
    }
    
    var entriesThisMonth: Int {
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        return entries.filter { $0.createdAt >= startOfMonth }.count
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Total
            Text("\(totalEntries) Entries")
                .font(style.typeLargeTitle)
                .foregroundStyle(style.primaryText)
            
            Divider()
                .overlay(style.tertiaryText.opacity(0.3))
            
            // Icon grid — 4 per row
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(countsByType, id: \.type) { item in
                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(item.type.cardColor(for: themeManager.current))
                                .frame(width: 72, height: 72)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(style.cardBorder, lineWidth: 0.5)
                                )
                            Image(systemName: item.type.icon)
                                .font(.system(size: 32, weight: .medium))
                                .foregroundStyle(item.type.detailAccentColor(for: themeManager.current))
                        }
                        Text("\(item.count)")
                            .font(style.typeCaption)
                            .fontWeight(.medium)
                            .foregroundStyle(item.type.detailAccentColor(for: themeManager.current))
                    }
                }
            }
            
            Divider()
                .overlay(style.tertiaryText.opacity(0.3))
            
            // Capturing days + streak
            HStack {
                if let days = daysSinceFirst {
                    Text("capturing for \(days) days")
                        .font(style.typeCaption)
                        .foregroundStyle(style.tertiaryText)
                }
                Spacer()
                if currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(accentColor)
                        Text("streak \(currentStreak)")
                            .font(style.typeCaption)
                            .foregroundStyle(accentColor)
                    }
                }
            }
            
            Divider()
                .overlay(style.tertiaryText.opacity(0.3))
            
            // Most active day
            if let day = mostActiveDay {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(style.tertiaryText)
                    Text("Most active: \(day)")
                        .font(style.typeCaption)
                        .foregroundStyle(style.secondaryText)
                }
            }
            
            // This week / this month
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundStyle(style.tertiaryText)
                    Text("\(entriesThisWeek) this week")
                        .font(style.typeCaption)
                        .foregroundStyle(style.secondaryText)
                }
                Text("·")
                    .foregroundStyle(style.tertiaryText)
                Text("\(entriesThisMonth) this month")
                    .font(style.typeCaption)
                    .foregroundStyle(style.secondaryText)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }
}
