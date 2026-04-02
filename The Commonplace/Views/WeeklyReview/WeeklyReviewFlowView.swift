// WeeklyReviewFlowView.swift
// Commonplace
//
// Full weekly review flow — presented as a sheet from the Sunday prompt card.
// User scrolls through auto-surfaced sections, fills in reflection prompts,
// exports the week's markdown archive, then saves the review.
//
// Export is required before Done unlocks — the export button must be tapped
// and succeed before the Done button becomes active.
//
// On save, creates a journal entry tagged "weekly-review" with all data
// encoded in the text field as key:value lines for later parsing.
//
// Dismissed only via the Done button + confirmation — swiping down is disabled.

import SwiftUI
import SwiftData

struct WeeklyReviewFlowView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    let allEntries: [Entry]
    let allPersons: [Tag]
    
    @State private var highlight: String = ""
    @State private var carryForward: String = ""
    @State private var gratitude: String = ""
    @State private var exportDone: Bool = false
    @State private var showingDoneConfirmation: Bool = false
    @State private var showingExportSheet: Bool = false
    @State private var exportURL: URL? = nil
    
    @FocusState private var focusedField: Field?
    
    enum Field { case highlight, carry, gratitude }
    
    var style: any AppThemeStyle { themeManager.style }
    
    // MARK: - Week Data
    
    var weekStart: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Find most recent Monday
        let weekday = calendar.component(.weekday, from: today)
        // weekday: 1=Sun, 2=Mon, ... 7=Sat
        let daysFromMonday = weekday == 1 ? 6 : weekday - 2
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
    }
    
    var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? Date()
    }
    
    var weekRange: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let fmtYear = DateFormatter()
        fmtYear.dateFormat = "MMM d, yyyy"
        return "\(fmt.string(from: weekStart)) — \(fmtYear.string(from: weekEnd))"
    }
    
    var weekEntries: [Entry] {
        allEntries.filter {
            $0.createdAt >= weekStart &&
            $0.createdAt < Calendar.current.date(byAdding: .day, value: 7, to: weekStart)! &&
            !$0.tagNames.contains(WeeklyReviewTheme.weeklyReviewTag)
        }
    }
    
    var weekPeople: [String] {
        let personTags = weekEntries.flatMap { $0.tagNames.filter { $0.hasPrefix("@") } }
        let names = personTags.map { String($0.dropFirst()) }
        return Array(Set(names)).sorted()
    }
    
    var weekTags: [String] {
        let tags = weekEntries.flatMap { $0.tagNames.filter { !$0.hasPrefix("@") } }
        let counts = Dictionary(tags.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.sorted { $0.value > $1.value }.prefix(8).map { $0.key }
    }
    
    var weekMusic: [Entry] {
        weekEntries.filter { $0.type == .music }
    }
    
    var weekMedia: [Entry] {
        weekEntries.filter { $0.type == .media }
    }
    
    var habitCompletionSummary: String {
        let journalEntries = weekEntries.filter { $0.type == .journal }
        guard !journalEntries.isEmpty else { return "" }
        let totalCompleted = journalEntries.reduce(0) { $0 + $1.completedHabitSnapshots.count }
        let totalPossible = journalEntries.reduce(0) { $0 + $1.totalHabitsAtTime }
        guard totalPossible > 0 else { return "" }
        return "\(totalCompleted)/\(totalPossible)"
    }
    
    var habitBreakdown: [(name: String, completed: Int, total: Int)] {
        let journalEntries = weekEntries.filter { $0.type == .journal }
        guard !journalEntries.isEmpty else { return [] }
        
        // Collect all unique habit names seen this week
        var allHabitNames: [String] = []
        for entry in journalEntries {
            for name in entry.completedHabitSnapshots where !allHabitNames.contains(name) {
                allHabitNames.append(name)
            }
        }
        
        // Also include habits that were tracked but never completed
        let maxHabits = journalEntries.map { $0.totalHabitsAtTime }.max() ?? 0
        let journalDays = journalEntries.count
        
        // Count completions per habit
        return allHabitNames.map { name in
            let completed = journalEntries.reduce(0) {
                $0 + ($1.completedHabitSnapshots.contains(name) ? 1 : 0)
            }
            return (name: name, completed: completed, total: journalDays)
        }.sorted { $0.completed > $1.completed }
    }
    
    var averageMoodEmoji: String? {
        let moodEntries = weekEntries.filter { $0.type == .journal && !$0.moodEmoji.isEmpty }
        guard !moodEntries.isEmpty else { return nil }
        let scores = moodEntries.compactMap { MoodOption.score(for: $0.moodEmoji) }
        guard !scores.isEmpty else { return nil }
        let avg = scores.reduce(0, +) / scores.count
        return MoodOption.all.min(by: { abs(($0.score) - avg) < abs(($1.score) - avg) })?.emoji
    }
    
    var averageCalories: String? {
        let healthEntries = weekEntries.filter { $0.type == .journal && $0.healthDataFetched }
        guard !healthEntries.isEmpty else { return nil }
        let total = healthEntries.compactMap { $0.healthActiveCalories }.reduce(0, +)
        return "\(Int(total / Double(healthEntries.count)))"
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    reviewHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                    
                    // This week at a glance
                    if !weekEntries.isEmpty {
                        sectionHeader("This week")
                        glanceSection
                            .padding(.bottom, 20)
                    }
                    
                    // Habits
                    if !habitBreakdown.isEmpty {
                        sectionDivider
                        sectionHeader("Habits")
                        habitsSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                    
                    // Health
                    if let cal = averageCalories {
                        sectionDivider
                        sectionHeader("Health")
                        healthSection(avgCal: cal)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                    
                    // People
                    if !weekPeople.isEmpty {
                        sectionDivider
                        sectionHeader("People")
                        peopleSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                    
                    // Tags
                    if !weekTags.isEmpty {
                        sectionDivider
                        sectionHeader("Most used tags")
                        tagsSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                    
                    // Music
                    if !weekMusic.isEmpty {
                        sectionDivider
                        sectionHeader("Music saved")
                        musicSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                    
                    // Media
                    if !weekMedia.isEmpty {
                        sectionDivider
                        sectionHeader("Media watched")
                        mediaSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                    
                    // Reflection prompts
                    sectionDivider
                    sectionHeader("Reflection")
                    reflectionSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    
                    // Export + Done
                    sectionDivider
                    exportSection
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    
                    Color.clear.frame(height: 40)
                }
            }
            .background(WeeklyReviewTheme.backgroundGradient.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .keyboardAvoiding()
            .interactiveDismissDisabled()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(WeeklyReviewTheme.secondaryText)
                }
            }
            .confirmationDialog(
                "Save your weekly review?",
                isPresented: $showingDoneConfirmation,
                titleVisibility: .visible
            ) {
                Button("Save") { saveReview() }
                Button("Keep editing", role: .cancel) {}
            }
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportURL {
                    ShareSheet(url: url)
                }
            }
        }
    }
    
    // MARK: - Header
    
    var reviewHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("✦")
                    .font(.system(size: 16))
                    .foregroundStyle(WeeklyReviewTheme.accentGold)
                Text("Weekly Review")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(WeeklyReviewTheme.primaryText)
            }
            Text(weekRange)
                .font(.system(size: 13))
                .foregroundStyle(WeeklyReviewTheme.secondaryText)
            Text("\(weekEntries.count) entries captured this week")
                .font(.system(size: 12))
                .foregroundStyle(WeeklyReviewTheme.tertiaryText)
        }
    }
    
    // MARK: - Section Header
    
    func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(WeeklyReviewTheme.tertiaryText)
            .kerning(0.6)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
    }
    
    var sectionDivider: some View {
        Rectangle()
            .fill(WeeklyReviewTheme.sectionDivider)
            .frame(height: 0.5)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
    }
    
    // MARK: - Glance Section
    
    var glanceSection: some View {
        let grouped = Dictionary(grouping: weekEntries) { $0.type }
        let sorted = grouped.keys.sorted { $0.displayName < $1.displayName }
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(sorted, id: \.self) { type in
                let entries = grouped[type] ?? []
                NavigationLink(destination: WeeklyReviewEntryListView(
                    entries: entries.sorted { $0.createdAt > $1.createdAt },
                    title: type.displayName
                )) {
                    HStack(spacing: 10) {
                        Image(systemName: type.icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(type.accentColor)
                            .frame(width: 20)
                        Text("\(entries.count) \(entries.count == 1 ? type.displayName : type.displayName + "s")")
                            .font(.system(size: 13))
                            .foregroundStyle(type.accentColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(WeeklyReviewTheme.tertiaryText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(WeeklyReviewTheme.statBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(type.accentColor.opacity(0.2), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
    // MARK: - Habits Section
    
    var habitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if habitBreakdown.isEmpty {
                Text("No habits tracked this week")
                    .font(.system(size: 13))
                    .foregroundStyle(WeeklyReviewTheme.secondaryText)
            } else {
                ForEach(habitBreakdown, id: \.name) { habit in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(habitColor(habit.completed, total: habit.total))
                        Text(habit.name)
                            .font(.system(size: 13))
                            .foregroundStyle(WeeklyReviewTheme.primaryText)
                        Spacer()
                        Text("\(habit.completed)/\(habit.total)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(habitColor(habit.completed, total: habit.total))
                    }
                }
            }
        }
    }
    
    func habitColor(_ completed: Int, total: Int) -> Color {
        guard total > 0 else { return WeeklyReviewTheme.tertiaryText }
        let ratio = Double(completed) / Double(total)
        if ratio >= 0.7 { return Color(hex: "#34C759") }      // green — strong
        if ratio >= 0.4 { return Color(hex: "#FF9F0A") }      // amber — needs work
        return Color(hex: "#FF453A")                           // red — struggling
    }
    
    // MARK: - Health Section
    
    func healthSection(avgCal: String) -> some View {
        HStack(spacing: 16) {
            healthStat(value: avgCal, label: "avg cal/day")
            if let emoji = averageMoodEmoji {
                healthStat(value: emoji, label: "avg mood")
            }
        }
    }
    
    func healthStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(WeeklyReviewTheme.primaryText)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(WeeklyReviewTheme.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(WeeklyReviewTheme.statBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - People Section
    
    var peopleSection: some View {
        HStack(spacing: 12) {
            ForEach(weekPeople.prefix(6), id: \.self) { name in
                VStack(spacing: 4) {
                    personAvatar(name: name)
                    Text(name)
                        .font(.system(size: 10))
                        .foregroundStyle(WeeklyReviewTheme.secondaryText)
                        .lineLimit(1)
                        .frame(width: 44)
                }
            }
        }
    }
    
    func personAvatar(name: String) -> some View {
        let person = allPersons.first { $0.name == name }
        return Group {
            if let path = person?.profilePhotoPath,
               let data = MediaFileManager.load(path: path),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(WeeklyReviewTheme.accentPurple.opacity(0.4), lineWidth: 1.5))
            } else {
                Circle()
                    .fill(WeeklyReviewTheme.tagBackground)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(WeeklyReviewTheme.accentPurple)
                    )
                    .overlay(Circle().strokeBorder(WeeklyReviewTheme.accentPurple.opacity(0.4), lineWidth: 1.5))
            }
        }
    }
    
    // MARK: - Tags Section
    
    var tagsSection: some View {
        FlowLayout(spacing: 6, maxRows: 3) {
            ForEach(weekTags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 11))
                    .foregroundStyle(WeeklyReviewTheme.accentPurple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(WeeklyReviewTheme.tagBackground)
                    .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Music Section
    
    var musicSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(weekMusic.prefix(5)) { entry in
                HStack(spacing: 10) {
                    if let artworkPath = entry.musicArtworkPath,
                       let data = MediaFileManager.load(path: artworkPath),
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(WeeklyReviewTheme.tagBackground)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 14))
                                    .foregroundStyle(WeeklyReviewTheme.accentPurple)
                            )
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.linkTitle ?? "Unknown Track")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(WeeklyReviewTheme.primaryText)
                            .lineLimit(1)
                        if let artist = entry.musicArtist {
                            Text(artist)
                                .font(.system(size: 11))
                                .foregroundStyle(WeeklyReviewTheme.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Media Section
    
    var mediaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(weekMedia.prefix(5)) { entry in
                HStack(spacing: 10) {
                    if let coverPath = entry.mediaCoverPath,
                       let data = MediaFileManager.load(path: coverPath),
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(WeeklyReviewTheme.tagBackground)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "film.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(WeeklyReviewTheme.accentPurple)
                            )
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.mediaTitle ?? "Unknown")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(WeeklyReviewTheme.primaryText)
                            .lineLimit(1)
                        if let status = entry.mediaStatus {
                            Text(status == "finished" ? "Finished" : status == "inProgress" ? "In Progress" : "Want to Watch")
                                .font(.system(size: 11))
                                .foregroundStyle(WeeklyReviewTheme.secondaryText)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Reflection Section
    
    var reflectionSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            reflectionField(
                label: "What was the highlight of your week?",
                placeholder: "The best moment was...",
                text: $highlight,
                field: .highlight
            )
            reflectionField(
                label: "What do you want to carry into next week?",
                placeholder: "I want to bring forward...",
                text: $carryForward,
                field: .carry
            )
            reflectionField(
                label: "What are you grateful for?",
                placeholder: "I'm grateful for...",
                text: $gratitude,
                field: .gratitude
            )
        }
    }
    
    func reflectionField(label: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WeeklyReviewTheme.secondaryText)
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 13))
                        .foregroundStyle(WeeklyReviewTheme.tertiaryText)
                        .padding(.top, 10)
                        .padding(.leading, 12)
                }
                TextEditor(text: text)
                    .font(.system(size: 13))
                    .foregroundStyle(WeeklyReviewTheme.primaryText)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 80)
                    .padding(.horizontal, 8)
                    .focused($focusedField, equals: field)
            }
            .padding(.vertical, 4)
            .background(WeeklyReviewTheme.statBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(WeeklyReviewTheme.accentPurple.opacity(0.2), lineWidth: 0.5)
            )
        }
    }
    
    // MARK: - Export Section
    
    var exportSection: some View {
        VStack(spacing: 12) {
            Button {
                exportWeek()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: exportDone ? "checkmark.circle.fill" : "square.and.arrow.up")
                        .font(.system(size: 14))
                    Text(exportDone ? "Week exported" : "Export this week's archive")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(exportDone ? WeeklyReviewTheme.accentGold : WeeklyReviewTheme.accentPurple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(WeeklyReviewTheme.tagBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            exportDone
                            ? WeeklyReviewTheme.accentGold.opacity(0.4)
                            : WeeklyReviewTheme.accentPurple.opacity(0.3),
                            lineWidth: 0.5
                        )
                )
            }
            .buttonStyle(.plain)
            
            Button {
                showingDoneConfirmation = true
            } label: {
                Text("Done")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(exportDone
                                     ? WeeklyReviewTheme.primaryText
                                     : WeeklyReviewTheme.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(exportDone
                                ? Color(hex: "#534AB7").opacity(0.4)
                                : WeeklyReviewTheme.statBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!exportDone)
        }
    }
    
    // MARK: - Export
    
    func exportWeek() {
        guard let result = try? MarkdownExporter.exportWeek(
            entries: allEntries,
            weekStart: weekStart
        ) else { return }
        exportURL = result.zipURL
        exportDone = true
        showingExportSheet = true
    }
    
    // MARK: - Save
    
    func saveReview() {
        let entry = Entry(type: .journal, text: "", tags: [WeeklyReviewTheme.weeklyReviewTag])
        entry.tagNames = [WeeklyReviewTheme.weeklyReviewTag]
        entry.createdAt = Date()
        
        // Reflection answers
        entry.weeklyReviewHighlight    = highlight.isEmpty ? nil : highlight
        entry.weeklyReviewCarryForward = carryForward.isEmpty ? nil : carryForward
        entry.weeklyReviewGratitude    = gratitude.isEmpty ? nil : gratitude
        
        // Stats — encode as JSON into weeklyReviewStats
        var stats: [String: String] = [:]
        stats["entries"] = "\(weekEntries.count)"
        if !habitCompletionSummary.isEmpty { stats["habits"] = habitCompletionSummary }
        if let mood = averageMoodEmoji     { stats["avgmood"] = mood }
        if let cal = averageCalories       { stats["avgcal"] = cal }
        if !weekPeople.isEmpty             { stats["people"] = weekPeople.joined(separator: "|") }
        if !weekTags.isEmpty               { stats["tags"] = weekTags.joined(separator: "|") }
        if !weekMusic.isEmpty {
            stats["music"] = weekMusic.compactMap { $0.linkTitle }.joined(separator: "|")
        }
        if !weekMedia.isEmpty {
            stats["media"] = weekMedia.compactMap { $0.mediaTitle }.joined(separator: "|")
        }
        entry.weeklyReviewStats = try? JSONEncoder().encode(stats)
        
        modelContext.insert(entry)
        try? modelContext.save()
        SearchIndex.shared.index(entry: entry)
        dismiss()
    }
}

