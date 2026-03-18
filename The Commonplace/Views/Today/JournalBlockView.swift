import SwiftUI
import SwiftData
import PhotosUI

// MARK: - JournalBlockView
// The daily journal card shown on the Today tab.
// Contains weather/mood pickers, habits, daily note, and daily photo.
// Owns all its own state — no bindings needed from TodayView.
// Screen: Today tab → Today segment

struct JournalBlockView: View {
    @Environment(\.modelContext) var modelContext
    @Query var entries: [Entry]
    @Query var journalEntries: [JournalEntry]
    @Query(sort: \Habit.order) var habits: [Habit]
    @StateObject private var locationManager = LocationManager()
    @EnvironmentObject var themeManager: ThemeManager

    @State private var dailyNoteText = ""
    @State private var showingJournalPhotoPicker = false
    @State private var journalImage: UIImage? = nil
    @FocusState private var noteFieldFocused: Bool

    var style: any AppThemeStyle { themeManager.style }
    var journalAccent: Color { InkwellTheme.journalAccent }
    var journalCardBg: Color { InkwellTheme.journalCard }
    var journalDivider: Color { InkwellTheme.journalBorder }

    var today: Date { Calendar.current.startOfDay(for: Date()) }

    var todayJournalEntry: JournalEntry? {
        journalEntries.first { Calendar.current.isDateInToday($0.date) }
    }

    var dailyNoteEntry: Entry? {
        entries.first {
            Calendar.current.isDateInToday($0.createdAt) && $0.type == .journal
        }
    }

    var dateString: String {
        Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    let weatherOptions = ["☀️", "🌤️", "⛅", "🌧️", "⛈️", "🌨️", "🌫️", "🌈"]
    let moodOptions = ["🤩", "😊", "😐", "😔", "😤", "😴", "🥲", "😌"]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            journalHeader
            Divider().overlay(journalDivider)
            emojiPickerRow(label: "Weather", icon: "cloud.sun.fill", options: weatherOptions,
                           selected: todayJournalEntry?.weatherEmoji ?? "", onSelect: { setWeather($0) })
            emojiPickerRow(label: "Mood", icon: "face.smiling", options: moodOptions,
                           selected: todayJournalEntry?.moodEmoji ?? "", onSelect: { setMood($0) })
            Divider().overlay(journalDivider)
            habitsBlock
            Divider().overlay(journalDivider)
            dailyNoteBlock
            Divider().overlay(journalDivider)
            dailyPhotoBlock
        }
        .padding(16)
        .background(journalCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            style.usesSerifFonts
            ? RoundedRectangle(cornerRadius: 16).strokeBorder(
                LinearGradient(
                    colors: [InkwellTheme.cardBorderTop, journalAccent.opacity(0.2)],
                    startPoint: .top, endPoint: .bottom
                ), lineWidth: 0.5)
            : nil
        )
        .shadow(color: style.usesSerifFonts ? .black.opacity(0.3) : .clear, radius: 6, x: 0, y: 3)
        .padding(.horizontal)
        .sheet(isPresented: $showingJournalPhotoPicker) {
            ImagePicker(image: $journalImage).ignoresSafeArea()
        }
        .onChange(of: journalImage) { _, newImage in
            if let image = newImage, let data = image.jpegData(compressionQuality: 0.8) {
                getOrCreateJournalEntry().journalImageData = data
                journalImage = nil
            }
        }
        .onAppear {
            locationManager.requestLocation()
            loadDailyNote()
        }
    }

    // MARK: - Sub-views

    var journalHeader: some View {
        HStack {
            Text(dateString)
                .font(style.usesSerifFonts ? .system(.title3, design: .serif) : .title3)
                .fontWeight(.bold)
                .foregroundStyle(style.primaryText)
            Spacer()
            HStack(spacing: 6) {
                Text("Journal")
                    .font(.caption).fontWeight(.light)
                    .foregroundStyle(journalAccent)
                ZStack {
                    Circle().fill(journalAccent).frame(width: 18, height: 18)
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(style.background)
                }
            }
        }
    }

    var habitsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Habits", systemImage: "checkmark.circle.fill")
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(style.secondaryText)
            if habits.isEmpty {
                Text("Tap + to add habits to track")
                    .font(.caption)
                    .foregroundStyle(style.tertiaryText)
                    .padding(.top, 2)
            } else {
                VStack(spacing: 4) {
                    ForEach(habits) { habit in
                        HabitRowView(
                            habit: habit,
                            isCompleted: todayJournalEntry?.completedHabits.contains(habit.id.uuidString) ?? false,
                            onToggle: { toggleHabit(habit) },
                            accentColor: journalAccent,
                            style: style
                        )
                    }
                }
            }
        }
    }

    var dailyNoteBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Daily Note", systemImage: "pencil")
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(style.secondaryText)
            AutoResizingTextEditor(
                text: $dailyNoteText,
                placeholder: "How was your day...",
                minHeight: 60
            )
            .font(style.body)
            .foregroundStyle(style.primaryText)
            .focused($noteFieldFocused)
            .onChange(of: dailyNoteText) { _, newValue in saveDailyNote(newValue) }
        }
    }

    var dailyPhotoBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Daily Photo", systemImage: "camera.fill")
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(style.secondaryText)
            if let imageData = todayJournalEntry?.journalImageData,
               let uiImage = UIImage(data: imageData) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable().scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Button {
                        getOrCreateJournalEntry().journalImageData = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white).padding(8)
                    }
                }
            } else {
                Button { showingJournalPhotoPicker = true } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Photo")
                    }
                    .font(.subheadline)
                    .foregroundStyle(journalAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(journalAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        style.usesSerifFonts
                        ? RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(journalAccent.opacity(0.3), lineWidth: 0.5)
                        : nil
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    func emojiPickerRow(label: String, icon: String, options: [String], selected: String, onSelect: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(style.secondaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(options, id: \.self) { emoji in
                        Text(emoji)
                            .font(.title2)
                            .padding(6)
                            .background(selected == emoji ? journalAccent.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                selected == emoji && style.usesSerifFonts
                                ? RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(journalAccent.opacity(0.4), lineWidth: 0.5)
                                : nil
                            )
                            .onTapGesture { onSelect(selected == emoji ? "" : emoji) }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    func getOrCreateJournalEntry() -> JournalEntry {
        if let existing = todayJournalEntry { return existing }
        let entry = JournalEntry(date: today)
        entry.totalHabitsAtTime = habits.count
        modelContext.insert(entry)
        return entry
    }

    func setWeather(_ emoji: String) { getOrCreateJournalEntry().weatherEmoji = emoji }
    func setMood(_ emoji: String) { getOrCreateJournalEntry().moodEmoji = emoji }

    func toggleHabit(_ habit: Habit) {
        let entry = getOrCreateJournalEntry()
        let id = habit.id.uuidString
        if entry.completedHabits.contains(id) {
            entry.completedHabits.removeAll { $0 == id }
            entry.completedHabitSnapshots.removeAll { $0 == habit.name }
        } else {
            entry.completedHabits.append(id)
            entry.completedHabitSnapshots.append(habit.name)
        }
    }

    func saveDailyNote(_ text: String) {
        if let existing = dailyNoteEntry {
            existing.text = text
        } else if !text.isEmpty {
            let entry = Entry(type: .journal, text: text, tags: [])
            if let location = locationManager.currentLocation {
                entry.captureLatitude = location.coordinate.latitude
                entry.captureLongitude = location.coordinate.longitude
                entry.captureLocationName = locationManager.currentPlaceName
            }
            modelContext.insert(entry)
        }
    }

    func loadDailyNote() {
        dailyNoteText = dailyNoteEntry?.text ?? ""
    }
}
