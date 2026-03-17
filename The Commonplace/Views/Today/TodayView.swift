import SwiftUI
import SwiftData
import CoreLocation
import PhotosUI

// MARK: - TodayView
// Main view for the Today tab.
// Shows the daily journal block (weather, mood, habits, note, photo),
// entries captured today, and On This Day memories.
// Screen: Today tab (bottom navigation)

struct TodayView: View {
    @Environment(\.modelContext) var modelContext
    @Query var entries: [Entry]
    @Query var journalEntries: [JournalEntry]
    @Query(sort: \Habit.order) var habits: [Habit]
    @StateObject private var locationManager = LocationManager()
    @EnvironmentObject var themeManager: ThemeManager

    @State private var showingSettings = false
    @State private var dailyNoteText = ""
    @State private var selectedTab = 0
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

    var todayEntries: [Entry] {
        entries
            .filter { Calendar.current.isDateInToday($0.createdAt) }
            .filter { $0.type != .journal }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var onThisDayEntries: [(yearsAgo: Int, entries: [Entry])] {
        let calendar = Calendar.current
        let today = Date()
        let thisYear = calendar.component(.year, from: today)
        let thisMonth = calendar.component(.month, from: today)
        let thisDay = calendar.component(.day, from: today)
        let pastEntries = entries.filter {
            let year = calendar.component(.year, from: $0.createdAt)
            let month = calendar.component(.month, from: $0.createdAt)
            let day = calendar.component(.day, from: $0.createdAt)
            return month == thisMonth && day == thisDay && year != thisYear
        }
        let grouped = Dictionary(grouping: pastEntries) {
            thisYear - calendar.component(.year, from: $0.createdAt)
        }
        return grouped.keys.sorted().map { yearsAgo in
            (yearsAgo: yearsAgo, entries: grouped[yearsAgo]!.sorted { $0.createdAt > $1.createdAt })
        }
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    titleHeader
                    segmentPicker
                    if selectedTab == 0 {
                        journalBlock
                        capturedTodayBlock
                        emptyTodayBlock
                    }
                    if selectedTab == 1 {
                        onThisDayBlock
                    }
                }
                .padding(.vertical)
            }
            .background(style.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if noteFieldFocused {
                        Button("Done") { noteFieldFocused = false }
                            .foregroundStyle(style.accent)
                    } else {
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(style.accent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
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
    }

    // MARK: - Sub-views

    var titleHeader: some View {
        HStack {
            Text(selectedTab == 0 ? "Today" : "On This Day")
                .font(style.usesSerifFonts
                      ? .system(size: 34, weight: .bold, design: .serif)
                      : .largeTitle.bold())
                .foregroundStyle(style.primaryText)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    var segmentPicker: some View {
        Picker("", selection: $selectedTab) {
            Text("Today").tag(0)
            Text("On This Day").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    var journalBlock: some View {
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
    }

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
    var capturedTodayBlock: some View {
        if !todayEntries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Captured Today", systemImage: "tray.fill")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(style.secondaryText)
                    .padding(.horizontal)
                ForEach(todayEntries) { entry in
                    NavigationLink(destination: destinationView(for: entry)) {
                        EntryRowView(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
        }
    }

    @ViewBuilder
    var emptyTodayBlock: some View {
        if todayEntries.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 32))
                    .foregroundStyle(style.tertiaryText)
                Text("Nothing captured yet today")
                    .font(.subheadline)
                    .foregroundStyle(style.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
        }
    }

    var onThisDayBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if onThisDayEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.system(size: 32))
                        .foregroundStyle(style.tertiaryText)
                    Text("Nothing on this day in previous years")
                        .font(.subheadline)
                        .foregroundStyle(style.tertiaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                ForEach(onThisDayEntries, id: \.yearsAgo) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.yearsAgo == 1 ? "1 year ago" : "\(group.yearsAgo) years ago")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(style.accent)
                            .padding(.horizontal)
                        ForEach(group.entries) { entry in
                            ZStack {
                                NavigationLink(destination: destinationView(for: entry)) { EmptyView() }
                                    .opacity(0)
                                EntryRowView(entry: entry)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Emoji picker row

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

    @ViewBuilder
    func destinationView(for entry: Entry) -> some View {
        switch entry.type {
        case .location: LocationDetailView(entry: entry)
        case .sticky:   StickyDetailView(entry: entry)
        default:        EntryDetailView(entry: entry)
        }
    }
}

// MARK: - HabitRowView
// Individual habit row in TodayView's habits block.
// Shows checkmark, habit icon, name, and strikethrough when completed.
// Screen: Today tab → journal block → habits section

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
                    .font(.subheadline)
                    .foregroundStyle(accentColor.opacity(0.7))
                    .frame(width: 20, alignment: .center)
                Text(habit.name)
                    .font(style.body)
                    .foregroundStyle(isCompleted ? style.tertiaryText : style.primaryText)
                    .strikethrough(isCompleted, color: style.tertiaryText)
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}
