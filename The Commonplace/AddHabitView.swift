import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Habit.order) var habits: [Habit]
    
    @State private var name = ""
    @State private var selectedIcon = "checkmark.circle"
    
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
            .navigationTitle("Add Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        guard !name.isEmpty else { return }
                        let habit = Habit(name: name, icon: selectedIcon, order: habits.count)
                        modelContext.insert(habit)
                        dismiss()
                    }
                    .bold()
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
