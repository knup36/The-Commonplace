import SwiftUI
import SwiftData

// MARK: - JournalMetadataSection
// Displays the journal metadata section within EntryDetailView.
// Shown when entry.type == .journal.
// Shows the formatted date, weather/mood emojis, completed habits,
// a divider, and the journal photo.
// All data now lives directly on Entry — no JournalEntry query needed.
// Screen: Entry Detail (tap any journal entry in the Feed or Collections tab)

struct JournalMetadataSection: View {
    @Bindable var entry: Entry
    var style: any AppThemeStyle
    var accentColor: Color

    var body: some View {
        if entry.type == .journal {
            VStack(alignment: .leading, spacing: 12) {
                Text(entry.createdAt.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                                    .font(style.typeLargeTitle)
                                    .foregroundStyle(style.cardPrimaryText)

                HStack(spacing: 16) {
                    if !entry.weatherEmoji.isEmpty {
                        VStack(spacing: 2) {
                            Text(entry.weatherEmoji).font(.largeTitle)
                            Text("Weather").font(style.typeCaption)
                                                            .foregroundStyle(style.cardSecondaryText)
                                                    }
                                                }
                                                if !entry.moodEmoji.isEmpty {
                                                    VStack(spacing: 2) {
                                                        Text(entry.moodEmoji).font(.largeTitle)
                                                        Text("Mood").font(style.typeCaption)
                                                            .foregroundStyle(style.cardSecondaryText)
                                                    }
                                                }
                                                if !entry.vibeEmoji.isEmpty {
                                                    VStack(spacing: 2) {
                                                        Text(entry.vibeEmoji).font(.largeTitle)
                                                        Text("Vibe").font(style.typeCaption)
                                                            .foregroundStyle(style.cardSecondaryText)
                        }
                    }
                }

                if entry.healthDataFetched {
                    ActivityRingsView(
                        activeCalories: entry.healthActiveCalories ?? 0,
                        exerciseMinutes: entry.healthExerciseMinutes ?? 0,
                        standHours: entry.healthStandHours ?? 0,
                        workoutName: entry.healthWorkoutName,
                        workoutDuration: entry.healthWorkoutDuration,
                        workoutCalories: entry.healthWorkoutCalories,
                        style: style
                    )
                }

                if !entry.completedHabitSnapshots.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Habits")
                                                    .font(style.typeCaption)
                                                    .foregroundStyle(style.cardSecondaryText)
                                                ForEach(entry.completedHabitSnapshots, id: \.self) { habitName in
                                                    HStack(spacing: 8) {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundStyle(accentColor)
                                                        Text(habitName)
                                                            .font(style.typeBodySecondary)
                                                            .foregroundStyle(style.cardPrimaryText)
                                                    }
                                                }
                    }
                }

                Divider()

                Text("Note")
                                    .font(style.typeCaption)
                                    .foregroundStyle(style.cardSecondaryText)
            }

            // Journal photo
            if let path = entry.journalImagePath,
               let data = MediaFileManager.load(path: path),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
