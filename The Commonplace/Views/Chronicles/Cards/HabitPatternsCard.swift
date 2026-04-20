// HabitPatternsCard.swift
// Commonplace
//
// Chronicles card showing habit completion rates over time.
// Receives pre-filtered journalEntries from ChroniclesView.
// Uses fixed-width progress bar instead of GeometryReader to
// avoid layout passes during scroll.
//
// Updated v2.4 — pre-filtered data, removed GeometryReader,
//               charcoal card background.

import SwiftUI

struct HabitPatternsCard: View {
    let journalEntries: [Entry]
    let habits: [Habit]
    var style: any AppThemeStyle

    var body: some View {
        ChroniclesCardContainer(title: "Habit Patterns", icon: "checkmark.circle", background: .parchment) {
            if habits.isEmpty || journalEntries.isEmpty {
                Text("Complete habits in your daily journal to see your patterns here.")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(Color.white.opacity(0.4))
            } else {
                VStack(spacing: 8) {
                    ForEach(habits) { habit in
                        habitRow(habit: habit)
                    }
                }
            }
        }
    }

    func habitRow(habit: Habit) -> some View {
        let completed = journalEntries.filter {
            $0.completedHabits.contains(habit.id.uuidString)
        }.count
        let total = journalEntries.count
        let rate = total > 0 ? Double(completed) / Double(total) : 0
        let color = rateColor(rate)

        return HStack(spacing: 10) {
            Image(systemName: habit.icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 24)

            Text(habit.name)
                .font(style.typeBodySecondary)
                .foregroundStyle(Color.white.opacity(0.75))

            Spacer()

            Text("\(Int(rate * 100))%")
                .font(style.typeBodySecondary)
                .fontWeight(.medium)
                .foregroundStyle(color)
                .frame(width: 36, alignment: .trailing)

            // Fixed-width bar — no GeometryReader needed
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 60, height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 60 * rate, height: 6)
            }
        }
    }

    func rateColor(_ rate: Double) -> Color {
        if rate >= 0.7 { return Color(hex: "#7DD8A8") }
        if rate >= 0.4 { return ChroniclesTheme.accentAmber }
        return Color(hex: "#E57373")
    }
}
