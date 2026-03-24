// AddHabitView.swift
// Commonplace
//
// Sheet for adding a new habit or editing an existing one.
// Accessible via Settings → Habits → + (new) or tap a habit (edit).
//
// Add mode:
//   - Empty name field, default icon
//   - Cancel button on left, Add button on right
//
// Edit mode:
//   - Pre-populated name and icon
//   - Delete button on left (red), Save button on right
//   - Delete removes the habit from SwiftData and dismisses

import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Habit.order) var habits: [Habit]

    var habit: Habit? = nil

    @State private var name = ""
    @State private var selectedIcon = "checkmark.circle"

    var isEditing: Bool { habit != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit Name") {
                    TextField("e.g. Exercise, Read, Meditate", text: $name)
                        .autocorrectionDisabled()
                }
                Section("Icon") {
                    IconPickerView(selectedIcon: $selectedIcon)
                }
            }
            .navigationTitle(isEditing ? "Edit Habit" : "Add Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditing {
                        Button("Delete", role: .destructive) {
                            if let habit {
                                modelContext.delete(habit)
                            }
                            dismiss()
                        }
                        .foregroundStyle(.red)
                    } else {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Add") {
                        guard !name.isEmpty else { return }
                        if let habit {
                            habit.name = name
                            habit.icon = selectedIcon
                        } else {
                            let newHabit = Habit(name: name, icon: selectedIcon, order: habits.count)
                            modelContext.insert(newHabit)
                        }
                        dismiss()
                    }
                    .bold()
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let habit {
                    name = habit.name
                    selectedIcon = habit.icon
                }
            }
        }
    }
}
