import SwiftData
import Foundation

@Model
class JournalEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var weatherEmoji: String = ""
    var moodEmoji: String = ""
    var completedHabits: [String] = []
    var completedHabitSnapshots: [String] = []
    var totalHabitsAtTime: Int = 0
    var journalImageData: Data? = nil
    
    init(date: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.weatherEmoji = ""
        self.moodEmoji = ""
        self.completedHabits = []
        self.totalHabitsAtTime = 0
    }
}

@Model
class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = ""
    var order: Int = 0
    
    init(name: String, icon: String = "checkmark.circle", order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.order = order
    }
}
