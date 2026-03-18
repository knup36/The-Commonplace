import SwiftUI
import SwiftData

// MARK: - DailyNoteRowView
// Feed card content for journal entries.
// Shows date, weather/mood emojis, note text, habit summary, and journal photo.
// Screen: Feed, Collections, Today tab — journal entry cards

struct DailyNoteRowView: View {
    let entry: Entry
    @Query var journalEntries: [JournalEntry]
    @Query(sort: \Habit.order) var habits: [Habit]
    @EnvironmentObject var themeManager: ThemeManager

    var style: any AppThemeStyle { themeManager.style }
    var purple: Color { InkwellTheme.journalAccent }

    var journalEntry: JournalEntry? {
        journalEntries.first {
            Calendar.current.isDate($0.date, inSameDayAs: entry.createdAt)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Date
            Text(entry.createdAt.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(style.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(purple)

            // Weather + Mood
            if let je = journalEntry {
                HStack(spacing: 8) {
                    if !je.weatherEmoji.isEmpty {
                        Text(je.weatherEmoji).font(.title3)
                    }
                    if !je.moodEmoji.isEmpty {
                        Text(je.moodEmoji).font(.title3)
                    }
                }
            }

            // Note text
            if !entry.text.isEmpty {
                let lineLimit = 6
                let lines = entry.text.components(separatedBy: "\n")
                let truncated = entry.text.count > 300 || lines.count > lineLimit
                Text(entry.text)
                    .font(style.body)
                    .lineLimit(lineLimit)
                    .foregroundStyle(style.primaryText)
                if truncated {
                    Text("more...")
                        .font(style.caption)
                        .foregroundStyle(purple.opacity(0.7))
                }
            }

            // Habit summary
            if let je = journalEntry, (!je.completedHabitSnapshots.isEmpty || je.totalHabitsAtTime > 0) {
                let completed = je.completedHabitSnapshots.count
                let total = je.totalHabitsAtTime > 0 ? je.totalHabitsAtTime : habits.count
                let percentage = total > 0 ? Int((Double(completed) / Double(total)) * 100) : 0
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(purple)
                    Text("\(completed) of \(total) habits complete · \(percentage)%")
                        .font(style.caption)
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
