// HabitSettingsView.swift
// Commonplace
//
// Dedicated settings page for managing daily habits.
// Accessible via Settings → Habits.
//
// Features:
//   - View all habits with their icon
//   - Tap a habit to edit name and icon (via AddHabitView in edit mode)
//   - Drag grabber handles to reorder
//   - Add new habits via + button in toolbar
//   - Delete habits from within the edit sheet only
//
// Uses a plain List with always-active edit mode so grabbers
// are always visible for reordering.

import SwiftUI
import SwiftData

struct HabitSettingsView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Habit.order) var habits: [Habit]
    @EnvironmentObject var themeManager: ThemeManager

    @State private var showingAddHabit = false
    @State private var habitToEdit: Habit? = nil
    @State private var editMode: EditMode = .active

    var style: any AppThemeStyle { themeManager.style }
    var accent: Color { style.accent }

    var body: some View {
        List {
            ForEach(habits) { habit in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.12))
                            .frame(width: 36, height: 36)
                            .overlay(
                                style.usesSerifFonts
                                ? Circle().strokeBorder(accent.opacity(0.3), lineWidth: 0.5)
                                : nil
                            )
                        Image(systemName: habit.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(accent)
                    }
                    Text(habit.name)
                        .font(style.usesSerifFonts
                              ? .system(.body, design: .serif)
                              : .body)
                        .foregroundStyle(style.primaryText)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    habitToEdit = habit
                }
            }
            .onMove { from, to in
                var reordered = habits
                reordered.move(fromOffsets: from, toOffset: to)
                for (index, habit) in reordered.enumerated() {
                    habit.order = index
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(style.usesSerifFonts ? .hidden : .visible)
        .background(style.usesSerifFonts ? style.background : Color(uiColor: .systemGroupedBackground))
        .environment(\.editMode, $editMode)
        .navigationTitle("Daily Habits")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddHabit = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(accent)
                }
            }
        }
        .sheet(isPresented: $showingAddHabit) {
            AddHabitView(habit: nil)
        }
        .sheet(item: $habitToEdit) { habit in
            AddHabitView(habit: habit)
        }
    }
}
