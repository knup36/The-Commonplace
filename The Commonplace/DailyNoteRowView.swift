import SwiftUI
import SwiftData

struct DailyNoteRowView: View {
    let entry: Entry
    @Query var journalEntries: [JournalEntry]
    @Query(sort: \Habit.order) var habits: [Habit]
    
    let purple = Color(hex: "#BF5AF2")
    
    var journalEntry: JournalEntry? {
        journalEntries.first {
            Calendar.current.isDate($0.date, inSameDayAs: entry.createdAt)
        }
    }
    
    var completedHabits: [Habit] {
        guard let je = journalEntry else { return [] }
        return habits.filter { je.completedHabits.contains($0.id.uuidString) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // Date
            Text(entry.createdAt.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(purple)
            
            // Weather + Mood
            if let je = journalEntry {
                HStack(spacing: 8) {
                    if !je.weatherEmoji.isEmpty {
                        Text(je.weatherEmoji)
                            .font(.title3)
                    }
                    if !je.moodEmoji.isEmpty {
                        Text(je.moodEmoji)
                            .font(.title3)
                    }
                }
            }
            
            // Note text
                        if !entry.text.isEmpty {
                            let lineLimit = 6
                            let lines = entry.text.components(separatedBy: "\n")
                            let truncated = entry.text.count > 300 || lines.count > lineLimit

                            Text(entry.text)
                                .font(.body)
                                .lineLimit(lineLimit)
                                .foregroundStyle(.primary)

                            if truncated {
                                Text("more...")
                                    .font(.caption)
                                    .foregroundStyle(purple.opacity(0.7))
                            }
                        }
            
            // Habit summary — uses snapshots so deleted habits don't affect past entries
            if let je = journalEntry, (!je.completedHabitSnapshots.isEmpty || je.totalHabitsAtTime > 0) {
                let completed = je.completedHabitSnapshots.count
                let total = je.totalHabitsAtTime > 0 ? je.totalHabitsAtTime : habits.count
                let percentage = total > 0 ? Int((Double(completed) / Double(total)) * 100) : 0
                
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(purple)
                    Text("\(completed) of \(total) habits complete · \(percentage)%")
                        .font(.caption)
                        .foregroundStyle(purple)
                }
            }
            
            // Journal photo
            if let imageData = journalEntry?.journalImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
