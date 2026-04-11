// JournalMetadataSection.swift
// Commonplace
//
// Displays the journal metadata section within EntryDetailView.
// Shown when entry.type == .journal.
// Shows the formatted date as hero header, weather/mood/vibe emojis inline,
// habit summary capsule, activity rings, and journal photo.
// All data now lives directly on Entry — no JournalEntry query needed.
// Screen: Entry Detail (tap any journal entry in the Feed or Collections tab)

import SwiftUI
import SwiftData

struct JournalMetadataSection: View {
    @Bindable var entry: Entry
    var style: any AppThemeStyle
    var accentColor: Color

    var body: some View {
        if entry.type == .journal {
            VStack(alignment: .leading, spacing: 12) {

                // Hero date header
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.createdAt.formatted(.dateTime.weekday(.wide)))
                        .font(.custom("NewYorkLarge-Black", size: 34))
                        .foregroundStyle(style.cardPrimaryText)
                    Text(entry.createdAt.formatted(.dateTime.month(.wide).day().year()))
                        .font(style.typeBodySecondary)
                        .fontWeight(.light)
                        .foregroundStyle(style.cardSecondaryText)
                }

                // Emojis + habits + activity rings inline
                HStack(spacing: 12) {
                    if !entry.weatherEmoji.isEmpty {
                        Text(entry.weatherEmoji).font(.title2)
                    }
                    if !entry.moodEmoji.isEmpty {
                        Text(entry.moodEmoji).font(.title2)
                    }
                    if !entry.vibeEmoji.isEmpty {
                        Text(entry.vibeEmoji).font(.title2)
                    }
                    if !entry.completedHabitSnapshots.isEmpty {
                        VStack(spacing: 1) {
                            Text("\(entry.completedHabitSnapshots.count)/\(entry.totalHabitsAtTime)")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(accentColor)
                            Text("Habits")
                                .font(style.typeCaption)
                                .foregroundStyle(style.cardSecondaryText)
                        }
                        .frame(width: 56, height: 56)
                        .background(accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if entry.healthDataFetched {
                        VStack(spacing: 1) {
                            let moveProgress = min((entry.healthActiveCalories ?? 0) / 330, 1.0)
                            let exerciseProgress = min((entry.healthExerciseMinutes ?? 0) / 15, 1.0)
                            let standProgress = min((entry.healthStandHours ?? 0) / 12, 1.0)
                            ZStack {
                                RingShape(radius: 19, lineWidth: 4, progress: 1.0)
                                    .stroke(Color(red: 1.0, green: 0.23, blue: 0.19).opacity(0.15), lineWidth: 4)
                                RingShape(radius: 19, lineWidth: 4, progress: moveProgress)
                                    .stroke(Color(red: 1.0, green: 0.23, blue: 0.19), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                RingShape(radius: 13, lineWidth: 4, progress: 1.0)
                                    .stroke(Color(red: 0.20, green: 0.78, blue: 0.35).opacity(0.15), lineWidth: 4)
                                RingShape(radius: 13, lineWidth: 4, progress: exerciseProgress)
                                    .stroke(Color(red: 0.20, green: 0.78, blue: 0.35), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                RingShape(radius: 7, lineWidth: 4, progress: 1.0)
                                    .stroke(Color(red: 0.0, green: 0.78, blue: 0.75).opacity(0.15), lineWidth: 4)
                                RingShape(radius: 7, lineWidth: 4, progress: standProgress)
                                    .stroke(Color(red: 0.0, green: 0.78, blue: 0.75), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            }
                            .frame(width: 46, height: 46)
                            Text("Activity")
                                .font(style.typeCaption)
                                .foregroundStyle(style.cardSecondaryText)
                        }
                        .frame(width: 56, height: 56)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
