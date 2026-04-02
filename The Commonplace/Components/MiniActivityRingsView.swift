// MiniActivityRingsView.swift
// Commonplace
//
// Compact concentric activity rings for use in feed cards.
// Shows Move, Exercise, Stand rings sized for inline display.
// No stats, no workout row — purely visual summary.
// Used in DailyNoteRowView alongside mood/weather emojis.

import SwiftUI

struct MiniActivityRingsView: View {
    let activeCalories: Double
    let exerciseMinutes: Double
    let standHours: Double

    private let moveColor     = Color(red: 1.0,  green: 0.23, blue: 0.19)
    private let exerciseColor = Color(red: 0.20, green: 0.78, blue: 0.35)
    private let standColor    = Color(red: 0.0,  green: 0.78, blue: 0.75)

    private let moveGoal: Double     = 330
    private let exerciseGoal: Double = 15
    private let standGoal: Double    = 12

    var body: some View {
        let moveProgress     = min(activeCalories / moveGoal, 1.0)
        let exerciseProgress = min(exerciseMinutes / exerciseGoal, 1.0)
        let standProgress    = min(standHours / standGoal, 1.0)

        ZStack {
            RingShape(radius: 16, lineWidth: 3, progress: 1.0)
                .stroke(moveColor.opacity(0.15), lineWidth: 3)
            RingShape(radius: 16, lineWidth: 3, progress: moveProgress)
                .stroke(moveColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))

            RingShape(radius: 11, lineWidth: 3, progress: 1.0)
                .stroke(exerciseColor.opacity(0.15), lineWidth: 3)
            RingShape(radius: 11, lineWidth: 3, progress: exerciseProgress)
                .stroke(exerciseColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))

            RingShape(radius: 6, lineWidth: 3, progress: 1.0)
                .stroke(standColor.opacity(0.15), lineWidth: 3)
            RingShape(radius: 6, lineWidth: 3, progress: standProgress)
                .stroke(standColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .frame(width: 38, height: 38)
    }
}
