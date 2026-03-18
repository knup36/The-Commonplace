import SwiftUI
import SwiftData

// MARK: - FeedStatsView
// Stats summary that lives above the Feed title, revealed by pulling down.
// Shows total entries, per-type counts in entry accent colors,
// days since first entry, and current capture streak.
// Screen: Feed tab — pull down to reveal

struct FeedStatsView: View {
    let entries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager

    var style: any AppThemeStyle { themeManager.style }

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

    var accentColor: Color { style.usesSerifFonts ? InkwellTheme.amber : .accentColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Total
            Text("\(totalEntries) entries")
                .font(style.usesSerifFonts ? .system(.subheadline, design: .serif) : .subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(style.secondaryText)

            // Per-type counts
            let columns = [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading)
            ]
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(countsByType, id: \.type) { item in
                    Text("\(item.count) \(typeName(item.type))")
                        .font(style.usesSerifFonts ? .system(.subheadline, design: .serif) : .subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(InkwellTheme.accentColor(for: item.type))
                }
            }

            // Divider
            Divider()
                .overlay(style.usesSerifFonts ? InkwellTheme.cardBorderTop : Color(uiColor: .separator))
                .opacity(0.6)

            // Streak row
            HStack {
                if let days = daysSinceFirst {
                    Text("capturing for \(days) days")
                        .font(style.caption)
                        .foregroundStyle(style.tertiaryText)
                }
                Spacer()
                if currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(accentColor)
                        Text("streak \(currentStreak)")
                            .font(style.caption)
                            .foregroundStyle(accentColor)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }

    func typeName(_ type: EntryType) -> String {
        switch type {
        case .text:     return "notes"
        case .photo:    return "photos"
        case .audio:    return "audio"
        case .link:     return "links"
        case .journal:  return "journal"
        case .location: return "places"
        case .sticky:   return "stickies"
        case .music:    return "music"
        }
    }
}
