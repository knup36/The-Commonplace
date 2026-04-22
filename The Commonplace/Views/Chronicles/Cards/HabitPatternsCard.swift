// HabitPatternsCard.swift
// Commonplace
//
// Chronicles card showing habit completion rates over time.
// Receives pre-filtered journalEntries from ChroniclesView.
// Uses fixed-width progress bar instead of GeometryReader to
// avoid layout passes during scroll.
//
// Window picker — 7 days, 4 weeks, 3 months — persisted via
// @AppStorage. Sliding pill control with recessed track.
//
// Updated v2.4 — window picker, pre-filtered data, fixed-width bars.

import SwiftUI

struct HabitPatternsCard: View {
    let journalEntries: [Entry]
    let habits: [Habit]
    var style: any AppThemeStyle

    @AppStorage("habitPatternsWindow") private var selectedWindow: Int = 1

    let windows: [(label: String, days: Int)] = [
        ("7 days",   7),
        ("4 weeks",  28),
        ("3 months", 90)
    ]

    var filteredEntries: [Entry] {
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -windows[selectedWindow].days,
            to: Date()
        ) ?? Date()
        return journalEntries.filter { $0.createdAt >= cutoff }
    }

    var body: some View {
        ChroniclesCardContainer(title: "Habit Patterns", icon: "checkmark.circle", cardID: "habitPatterns", background: .parchment) {
            if habits.isEmpty || journalEntries.isEmpty {
                Text("Complete habits in your daily journal to see your patterns here.")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(Color.white.opacity(0.4))
            } else {
                VStack(spacing: 12) {
                    windowPicker
                    if filteredEntries.isEmpty {
                        Text("No journal entries in this window yet.")
                            .font(style.typeBodySecondary)
                            .foregroundStyle(Color.white.opacity(0.3))
                            .italic()
                    } else {
                        VStack(spacing: 8) {
                            ForEach(habits) { habit in
                                habitRow(habit: habit)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Window Picker

    var windowPicker: some View {
        GeometryReader { geo in
            let segmentWidth = geo.size.width / CGFloat(windows.count)

            ZStack(alignment: .leading) {
                // Recessed track
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.black.opacity(0.3), lineWidth: 0.5)
                    )

                // Sliding pill
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                    .frame(width: segmentWidth - 4)
                    .offset(x: CGFloat(selectedWindow) * segmentWidth + 2)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedWindow)

                // Labels
                HStack(spacing: 0) {
                    ForEach(Array(windows.enumerated()), id: \.offset) { i, window in
                        Text(window.label)
                            .font(style.typeCaption)
                            .fontWeight(selectedWindow == i ? .semibold : .regular)
                            .foregroundStyle(selectedWindow == i
                                ? Color.white.opacity(0.9)
                                : Color.white.opacity(0.4))
                            .frame(width: segmentWidth)
                            .animation(.easeInOut(duration: 0.2), value: selectedWindow)
                            .onTapGesture {
                                withAnimation { selectedWindow = i }
                            }
                    }
                }
            }
            .frame(height: 30)
        }
        .frame(height: 30)
    }

    // MARK: - Habit Row

    func habitRow(habit: Habit) -> some View {
        let completed = filteredEntries.filter {
            $0.completedHabits.contains(habit.id.uuidString)
        }.count
        let total = filteredEntries.count
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
                            .frame(width: 44, alignment: .trailing)
                            .lineLimit(1)

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
