// Habit.swift
// Commonplace
//
// SwiftData model representing a daily habit tracked in the Today tab.
// Habits are ordered and displayed in JournalBlockView for daily check-off.
// Completed habit IDs are stored on the journal Entry for that day.
//
// ============================================================
// SCHEMA VERSION: 1
// Last updated: v1.0
//
// Schema change policy: same as Entry.swift — optional fields safe to add
// at any time. Never remove fields without deprecating first.
//
// Field version history:
//   v1.0  — id, name, icon, order, createdAt
//
// Notes:
//   - Habit completion is stored on Entry.completedHabits ([String] of habit IDs)
//     not on the Habit model itself — habits are definitions, not logs
//   - Entry.completedHabitSnapshots stores habit names at time of completion
//     so renaming a habit doesn't corrupt historical journal entries
// ============================================================

import SwiftData
import Foundation

// MARK: - Habit
// Represents a daily habit that can be tracked in the Today tab journal.
// Habits are ordered and displayed in JournalBlockView for daily check-off.

@Model
class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "checkmark.circle"
    var order: Int = 0
    var createdAt: Date = Date()

    init(name: String, icon: String, order: Int) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.order = order
        self.createdAt = Date()
    }
}
