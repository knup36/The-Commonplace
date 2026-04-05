import SwiftUI
import SwiftData
import PhotosUI

// MARK: - JournalBlockView
// The daily journal card shown on the Today tab.
// Contains weather/mood pickers, habits, daily note, and daily photo.
// All data now lives on Entry — JournalEntry is no longer used.
// Screen: Today tab → Today segment

struct JournalBlockView: View {
    @Environment(\.modelContext) var modelContext
    @Query var entries: [Entry]
    @Query(sort: \Habit.order) var habits: [Habit]
    @StateObject private var locationManager = LocationManager()
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var dailyNoteText = ""
    @State private var showingVibePicker = false
    @State private var showingJournalPhotoPicker = false
    @State private var journalImage: UIImage? = nil
    @FocusState private var noteFieldFocused: Bool
    
    var style: any AppThemeStyle { themeManager.style }
    var journalAccent: Color { EntryType.journal.detailAccentColor(for: themeManager.current) }
    var journalCardBg: Color { EntryType.journal.cardColor(for: themeManager.current) }
    var journalDivider: Color { style.cardDivider }
    
    var today: Date { Calendar.current.startOfDay(for: Date()) }
    
    // Single source of truth — today's journal Entry
    var todayEntry: Entry? {
        entries.first {
            Calendar.current.isDateInToday($0.createdAt) && $0.type == .journal
        }
    }
    
    var dateString: String {
        Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
    
    let weatherOptions = ["☀️", "🌤️", "⛅", "🌧️", "⛈️", "🌨️", "🌫️", "🌬️", "🌈"]
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            journalHeader
            Divider().overlay(journalDivider)
            emojiPickerRow(label: "Weather", icon: "cloud.sun.fill", options: weatherOptions,
                           selected: todayEntry?.weatherEmoji ?? "", onSelect: { setWeather($0) })
            moodPickerRow
            Divider().overlay(journalDivider)
            vibeBlock
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
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style.cardBorder, lineWidth: 0.5)
        )
        .padding(.horizontal)
        .sheet(isPresented: $showingJournalPhotoPicker) {
            ImagePicker(image: $journalImage).ignoresSafeArea()
        }
        .onChange(of: journalImage) { _, newImage in
            if let image = newImage,
               let data = ImageProcessor.resizeAndCompress(image: image) {
                let entry = getOrCreateTodayEntry()
                if let path = try? MediaFileManager.save(data, type: .journal, id: entry.id.uuidString) {
                    entry.journalImagePath = path
                }
                journalImage = nil
            }
        }
        .onAppear {
            locationManager.requestLocation()
            loadDailyNote()
        }
        .onDisappear {
            if let entry = todayEntry {
                SearchIndex.shared.index(entry: entry)
            }
        }
    }
    var vibeBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Vibe", systemImage: "sparkles")
                .font(style.typeBodySecondary)
                .foregroundStyle(style.cardSecondaryText)
            Button {
                showingVibePicker = true
            } label: {
                HStack(spacing: 8) {
                    if let entry = todayEntry, !entry.vibeEmoji.isEmpty {
                        Text(entry.vibeEmoji)
                            .font(.largeTitle)
                        Button {
                            todayEntry?.vibeEmoji = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(style.tertiaryText)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("Tap to set your vibe...")
                            .font(style.typeBody)
                            .foregroundStyle(style.cardMetadataText)
                    }
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingVibePicker) {
                EmojiPickerSheet(
                    selectedEmoji: Binding(
                        get: { todayEntry?.vibeEmoji ?? "" },
                        set: { newValue in
                            getOrCreateTodayEntry().vibeEmoji = newValue
                            showingVibePicker = false
                        }
                    )
                )
                .presentationDetents([.medium])
            }
        }
        
    }
    var moodPickerRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "face.smiling")
                    .foregroundStyle(style.secondaryText)
                if let moodEmoji = todayEntry?.moodEmoji, !moodEmoji.isEmpty,
                   let label = MoodOption.label(for: moodEmoji) {
                    Text("Mood: \(label) \(moodEmoji)")
                        .font(style.typeBodySecondary)
                        .foregroundStyle(style.cardSecondaryText)
                    Button {
                        todayEntry?.moodEmoji = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(style.tertiaryText)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Mood")
                        .font(style.typeBodySecondary)
                        .foregroundStyle(style.cardSecondaryText)
                }
            }
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 9),
                spacing: 4
            ) {
                ForEach(MoodOption.all, id: \.emoji) { mood in
                    Text(mood.emoji)
                        .font(.title2)
                        .padding(4)
                        .background(
                            todayEntry?.moodEmoji == mood.emoji
                            ? journalAccent.opacity(0.2)
                            : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            todayEntry?.moodEmoji == mood.emoji
                            ? RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(journalAccent.opacity(0.4), lineWidth: 0.5)
                            : nil
                        )
                        .onTapGesture {
                            setMood(todayEntry?.moodEmoji == mood.emoji ? "" : mood.emoji)
                        }
                }
            }
        }
    }
    
    // MARK: - Sub-views
    
    var journalHeader: some View {
        HStack {
            Text(dateString)
                .font(style.typeTitle3)
                .fontWeight(.bold)
                .foregroundStyle(style.cardPrimaryText)
            Spacer()
            HStack(spacing: 6) {
                Text("Journal")
                    .font(style.typeCaption)
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
                .font(style.typeBodySecondary)
                .foregroundStyle(style.cardSecondaryText)
            if habits.isEmpty {
                Text("Tap + to add habits to track")
                    .font(style.typeCaption)
                    .foregroundStyle(style.cardMetadataText)
                    .padding(.top, 2)
            } else {
                VStack(spacing: 4) {
                    ForEach(habits) { habit in
                        HabitRowView(
                            habit: habit,
                            isCompleted: todayEntry?.completedHabits.contains(habit.id.uuidString) ?? false,
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
                .font(style.typeBodySecondary)
                .foregroundStyle(style.cardSecondaryText)
            CommonplaceTextEditor(
                text: $dailyNoteText,
                placeholder: "How was your day...",
                usesSerifFont: false,
                minHeight: 60
            )
            .foregroundStyle(style.cardPrimaryText)
            .focused($noteFieldFocused)
            .onChange(of: dailyNoteText) { _, newValue in saveDailyNote(newValue) }
        }
    }
    
    var dailyPhotoBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Daily Photo", systemImage: "camera.fill")
                .font(style.typeBodySecondary)
                .foregroundStyle(style.cardSecondaryText)
            if let path = todayEntry?.journalImagePath,
               let data = MediaFileManager.load(path: path),
               let uiImage = UIImage(data: data) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable().scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Button {
                        if let path = todayEntry?.journalImagePath {
                            MediaFileManager.delete(path: path)
                        }
                        todayEntry?.journalImagePath = nil
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
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(journalAccent.opacity(0.3), lineWidth: 0.5)
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
                .font(style.typeBodySecondary)
                .foregroundStyle(style.cardSecondaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(options, id: \.self) { emoji in
                        Text(emoji)
                            .font(.title2)
                            .padding(6)
                            .background(selected == emoji ? journalAccent.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                selected == emoji
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
    
    func getOrCreateTodayEntry() -> Entry {
        if let existing = todayEntry {
            if existing.totalHabitsAtTime != habits.count {
                existing.totalHabitsAtTime = habits.count
            }
            return existing
        }
        let entry = Entry(type: .journal, text: "", tags: [])
        entry.createdAt = today
        entry.totalHabitsAtTime = habits.count
        if let location = locationManager.currentLocation {
            entry.captureLatitude = location.coordinate.latitude
            entry.captureLongitude = location.coordinate.longitude
            entry.captureLocationName = locationManager.currentPlaceName
        }
        modelContext.insert(entry)
        // Index immediately on creation
        SearchIndex.shared.index(entry: entry)
        return entry
    }
    
    func setWeather(_ emoji: String) {
        let entry = getOrCreateTodayEntry()
        entry.weatherEmoji = emoji
        SearchIndex.shared.index(entry: entry)
    }
    
    func setMood(_ emoji: String) {
        let entry = getOrCreateTodayEntry()
        entry.moodEmoji = emoji
        SearchIndex.shared.index(entry: entry)
    }
    
    func toggleHabit(_ habit: Habit) {
        let entry = getOrCreateTodayEntry()
        let id = habit.id.uuidString
        if entry.completedHabits.contains(id) {
            entry.completedHabits.removeAll { $0 == id }
            entry.completedHabitSnapshots.removeAll { $0 == habit.name }
        } else {
            entry.completedHabits.append(id)
            entry.completedHabitSnapshots.append(habit.name)
        }
        SearchIndex.shared.index(entry: entry)
    }
    
    func saveDailyNote(_ text: String) {
            if let existing = todayEntry {
                existing.text = text
                existing.touch()
            } else if !text.isEmpty {
                let entry = getOrCreateTodayEntry()
                entry.text = text
                entry.touch()
            }
        }
    
    func loadDailyNote() {
        dailyNoteText = todayEntry?.text ?? ""
    }
}
