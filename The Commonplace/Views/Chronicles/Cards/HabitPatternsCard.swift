// HabitPatternsCard.swift
// Commonplace
//
// Chronicles card showing habit completion rates and patterns over time.
// Calculates completion percentage per habit across all journal entries.
// Progress bar colored green (70%+), amber (40-69%), red (below 40%).
// Empty state shown when no habits or journal entries exist yet.

import SwiftUI

struct HabitPatternsCard: View {
    let entries: [Entry]
    let habits: [Habit]
    var style: any AppThemeStyle

    var journalEntries: [Entry] {
        entries.filter { $0.type == .journal && !$0.completedHabitSnapshots.isEmpty }
    }

    var body: some View {
        ChroniclesCardContainer(title: "Habit Patterns", icon: "checkmark.circle") {
            if habits.isEmpty || journalEntries.isEmpty {
                Text("Complete habits in your daily journal to see your patterns here.")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.tertiaryText)
            } else {
                VStack(spacing: 8) {
                    ForEach(habits) { habit in
                        habitPatternRow(habit: habit)
                    }
                }
            }
        }
    }

    func habitPatternRow(habit: Habit) -> some View {
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
