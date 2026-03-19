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
