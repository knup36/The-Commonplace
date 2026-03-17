import SwiftUI
import SwiftData

// MARK: - JournalMetadataSection
// Displays the journal metadata section within EntryDetailView.
// Shown when entry.type == .journal.
// Shows the formatted date, weather/mood emojis, completed habits,
// a divider, and the journal photo (if one was taken that day).
// Pulls JournalEntry data for the same day as the entry's createdAt date.
// Screen: Entry Detail (tap any journal entry in the Feed or Collections tab)

struct JournalMetadataSection: View {
    @Bindable var entry: Entry
    var style: any AppThemeStyle
    var accentColor: Color

    @Query var journalEntries: [JournalEntry]

    var journalEntry: JournalEntry? {
        journalEntries.first { Calendar.current.isDate($0.date, inSameDayAs: entry.createdAt) }
    }

    var body: some View {
        if entry.type == .journal {
            VStack(alignment: .leading, spacing: 12) {
                Text(entry.createdAt.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(style.title)
                    .fontWeight(.bold)
                    .foregroundStyle(accentColor)

                if let je = journalEntry {
                    HStack(spacing: 16) {
                        if !je.weatherEmoji.isEmpty {
                            VStack(spacing: 2) {
                                Text(je.weatherEmoji).font(.largeTitle)
                                Text("Weather").font(.caption2)
                                    .foregroundStyle(style.secondaryText)
                            }
                        }
                        if !je.moodEmoji.isEmpty {
                            VStack(spacing: 2) {
                                Text(je.moodEmoji).font(.largeTitle)
                                Text("Mood").font(.caption2)
                                    .foregroundStyle(style.secondaryText)
                            }
                        }
                    }
                }

                if let je = journalEntry, !je.completedHabitSnapshots.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Habits")
                            .font(style.caption)
                            .foregroundStyle(style.secondaryText)
                        ForEach(je.completedHabitSnapshots, id: \.self) { habitName in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(accentColor)
                                Text(habitName)
                                    .font(style.subheadline)
                                    .foregroundStyle(style.primaryText)
                            }
                        }
                    }
                }

                Divider()

                Text("Note")
                    .font(style.caption)
                    .foregroundStyle(style.secondaryText)
            }

            // Journal photo
            if let imageData = journalEntry?.journalImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
