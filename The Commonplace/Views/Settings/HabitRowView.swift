// MARK: - HabitRowView
// Individual habit row in TodayView's habits block.
// Shows checkmark, habit icon, name, and strikethrough when completed.
// Screen: Today tab → journal block → habits section

import SwiftUI
import SwiftData

struct HabitRowView: View {
    let habit: Habit
    let isCompleted: Bool
    let onToggle: () -> Void
    let accentColor: Color
    var style: any AppThemeStyle
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? accentColor : accentColor.opacity(0.4))
                Image(systemName: habit.icon)
                    .font(style.typeBodySecondary)
                    .foregroundStyle(accentColor.opacity(0.7))
                    .frame(width: 20, alignment: .center)
                Text(habit.name)
                    .font(style.typeBody)
                    .foregroundStyle(isCompleted ? style.cardMetadataText : style.cardPrimaryText)
                    .strikethrough(isCompleted, color: style.cardMetadataText)
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}
