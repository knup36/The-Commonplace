// WeeklyReviewDetailView.swift
// Commonplace
//
// Read-only detail view for completed weekly review entries.
// Shown when tapping a weekly review card in the feed.
//
// Displays: week range, stats header, then all sections separated
// by subtle dividers — people, tags, music, media, mood, habits,
// health, highlight, carry forward, gratitude.
//
// Background: purple-to-blue gradient matching the feed card.
// Text is light coloured to sit on the dark background.
// Sections separated by subtle dividers, no cards.

import SwiftUI
import SwiftData

struct WeeklyReviewDetailView: View {
    let entry: Entry
    @Query var allEntries: [Entry]
    @Query var allPersonTags: [Tag]
    var allPersons: [Tag] { allPersonTags.filter { $0.isPerson } }
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    @State private var showingDeleteConfirmation = false

    var style: any AppThemeStyle { themeManager.style }

    // MARK: - Parsed Data

    var weekStart: Date? {
        Calendar.current.dateInterval(of: .weekOfYear, for: entry.createdAt)?.start
    }

    var weekEnd: Date? {
        guard let start = weekStart else { return nil }
        return Calendar.current.date(byAdding: .day, value: 6, to: start)
    }

    var weekRange: String {
        guard let start = weekStart, let end = weekEnd else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let fmtYear = DateFormatter()
        fmtYear.dateFormat = "MMM d, yyyy"
        return "\(fmt.string(from: start)) — \(fmtYear.string(from: end))"
    }

    // Decode the stats JSON blob from weeklyReviewStats
        var stats: [String: String] {
            guard let data = entry.weeklyReviewStats,
                  let decoded = try? JSONDecoder().decode([String: String].self, from: data)
            else { return [:] }
            return decoded
        }

        var entryCount: String { stats["entries"] ?? "" }
        var habitSummary: String { stats["habits"] ?? "" }
        var avgMood: String { stats["avgmood"] ?? "" }
        var avgCalories: String { stats["avgcal"] ?? "" }
        var highlight: String { entry.weeklyReviewHighlight ?? "" }
        var carryForward: String { entry.weeklyReviewCarryForward ?? "" }
        var gratitude: String { entry.weeklyReviewGratitude ?? "" }
        var musicLines: [String] {
            stats["music"]?.components(separatedBy: "|").filter { !$0.isEmpty } ?? []
        }
        var mediaLines: [String] {
            stats["media"]?.components(separatedBy: "|").filter { !$0.isEmpty } ?? []
        }
        var tagLines: [String] {
            stats["tags"]?.components(separatedBy: "|").filter { !$0.isEmpty && $0 != WeeklyReviewTheme.weeklyReviewTag } ?? []
        }
        var personLines: [String] {
            stats["people"]?.components(separatedBy: "|").filter { !$0.isEmpty } ?? []
        }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Stats header
                statsHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 20)

                if !personLines.isEmpty {
                    sectionDivider
                    peopleSection
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }

                if !tagLines.isEmpty {
                    sectionDivider
                    tagsSection
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }

                if !musicLines.isEmpty {
                    sectionDivider
                    musicSection
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }

                if !mediaLines.isEmpty {
                    sectionDivider
                    mediaSection
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }

                if !highlight.isEmpty {
                    sectionDivider
                    reflectionSection(label: "Highlight", text: highlight)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }

                if !carryForward.isEmpty {
                    sectionDivider
                    reflectionSection(label: "Carry forward", text: carryForward)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }

                if !gratitude.isEmpty {
                    sectionDivider
                    reflectionSection(label: "Gratitude", text: gratitude)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }

                Color.clear.frame(height: 40)
            }
        }
        .background(WeeklyReviewTheme.backgroundGradient.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Menu {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(WeeklyReviewTheme.accentPurple)
                    }
                    Button {
                        withAnimation { entry.isPinned.toggle() }
                    } label: {
                        Image(systemName: entry.isPinned ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(WeeklyReviewTheme.accentPurple)
                    }
                }
            }
        }
        .confirmationDialog("Delete this review?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(entry)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Stats Header

    var statsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("✦")
                    .font(.system(size: 14))
                    .foregroundStyle(WeeklyReviewTheme.accentGold)
                Text("Weekly Review")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(WeeklyReviewTheme.primaryText)
            }
            Text(weekRange)
                .font(.system(size: 13))
                .foregroundStyle(WeeklyReviewTheme.secondaryText)
                .padding(.bottom, 8)

            HStack(spacing: 10) {
                if !entryCount.isEmpty {
                    statBox(value: entryCount, label: "entries")
                }
                if !habitSummary.isEmpty {
                    statBox(value: habitSummary, label: "habits")
                }
                if !avgCalories.isEmpty {
                    statBox(value: avgCalories, label: "avg cal")
                }
                if !avgMood.isEmpty {
                    statBox(value: avgMood, label: "avg mood")
                }
            }
        }
    }

    func statBox(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(WeeklyReviewTheme.primaryText)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(WeeklyReviewTheme.tertiaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(WeeklyReviewTheme.statBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Section Divider

    var sectionDivider: some View {
        Rectangle()
            .fill(WeeklyReviewTheme.sectionDivider)
            .frame(height: 0.5)
            .padding(.horizontal, 20)
    }

    // MARK: - People Section

    var peopleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("People")
            HStack(spacing: 10) {
                ForEach(personLines, id: \.self) { name in
                    VStack(spacing: 4) {
                        personAvatar(name: name)
                        Text(name)
                            .font(.system(size: 10))
                            .foregroundStyle(WeeklyReviewTheme.secondaryText)
                            .lineLimit(1)
                    }
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
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(WeeklyReviewTheme.accentPurple.opacity(0.4), lineWidth: 1.5))
            } else {
                Circle()
                    .fill(WeeklyReviewTheme.tagBackground)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(WeeklyReviewTheme.accentPurple)
                    )
                    .overlay(Circle().strokeBorder(WeeklyReviewTheme.accentPurple.opacity(0.4), lineWidth: 1.5))
            }
        }
    }

    // MARK: - Tags Section

    var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Tags this week")
            FlowLayout(spacing: 6, maxRows: 3) {
                ForEach(tagLines, id: \.self) { tag in
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
    }

    // MARK: - Music Section

    var musicSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Music saved")
            VStack(alignment: .leading, spacing: 6) {
                ForEach(musicLines, id: \.self) { track in
                    HStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .font(.system(size: 11))
                            .foregroundStyle(WeeklyReviewTheme.accentPurple)
                        Text(track)
                            .font(.system(size: 12))
                            .foregroundStyle(WeeklyReviewTheme.primaryText)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Media Section

    var mediaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Media watched")
            VStack(alignment: .leading, spacing: 6) {
                ForEach(mediaLines, id: \.self) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "film.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(WeeklyReviewTheme.accentPurple)
                        Text(item)
                            .font(.system(size: 12))
                            .foregroundStyle(WeeklyReviewTheme.primaryText)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Reflection Section

    func reflectionSection(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(label)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(WeeklyReviewTheme.primaryText)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Section Label

    func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(WeeklyReviewTheme.tertiaryText)
            .kerning(0.6)
    }
}
