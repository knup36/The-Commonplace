import SwiftUI
import SwiftData

// MARK: - AddHabitView
// Form for adding or editing a habit.
// Pass a habit to edit an existing one, or nil to create a new one.
// Screen: Settings → Daily Habits

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
                    Button("Cancel") { dismiss() }
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
