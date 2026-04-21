// WatchTimelineCard.swift
// Commonplace
//
// Chronicles card showing media engagement as a GitHub-style contribution graph.
// 52 weeks × 7 days grid, scrolled to most recent weeks by default.
// Red intensity indicates number of media log entries that day.
//
// Interaction model:
//   - Tap a cell → detail panel shows cover art for that day's entries
//   - Tap eyeball on a cover chip → spotlight mode, grid shows only that title
//   - In spotlight mode, detail panel shows only that title
//   - "Show full day" link exits spotlight for the current day view
//   - Tap eyeball again or X badge → exit spotlight entirely
//
// Activity counted when: a mediaLog entry is added OR mediaStatus
// is set to inProgress/rewatch/replay (uses entry createdAt date).
//
// Updated v2.4 — full redesign, contribution graph replacing flat list.

import SwiftUI

struct WatchTimelineCard: View {
    let mediaEntries: [Entry]
    var style: any AppThemeStyle
    
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedDate: Date? = nil
    @State private var spotlightEntry: Entry? = nil
    @State private var showFullDay: Bool = false
    
    private static let isoFormatter = ISO8601DateFormatter()
    private let cellSize: CGFloat = 22
    private let cellSpacing: CGFloat = 3
    
    let cellColors: [Color] = [
        Color.white.opacity(0.05),
        Color(hex: "#7A1F1F"),
        Color(hex: "#A32D2D"),
        Color(hex: "#CC3333"),
        Color(hex: "#E24B4A")
    ]
    
    // MARK: - Activity map
    
    var activityByDay: [Date: [Entry]] {
        var map: [Date: [Entry]] = [:]
        let cal = Calendar.current
        for entry in mediaEntries {
            if ["inProgress", "rewatch", "replay"].contains(entry.mediaStatus) {
                let day = cal.startOfDay(for: entry.createdAt)
                if !(map[day]?.contains(where: { $0.id == entry.id }) ?? false) {
                    map[day, default: []].append(entry)
                }
            }
            for logString in entry.mediaLog {
                let parts = logString.components(separatedBy: "::")
                guard parts.count == 2,
                      let date = Self.isoFormatter.date(from: parts[0]) else { continue }
                let day = cal.startOfDay(for: date)
                if !(map[day]?.contains(where: { $0.id == entry.id }) ?? false) {
                    map[day, default: []].append(entry)
                }
            }
        }
        return map
    }
    
    func entriesForDay(_ date: Date) -> [Entry] {
        activityByDay[Calendar.current.startOfDay(for: date)] ?? []
    }
    
    func intensityForDay(_ date: Date) -> Int {
        let entries = entriesForDay(date)
        if let spotlight = spotlightEntry {
            return entries.contains(where: { $0.id == spotlight.id }) ? 4 : 0
        }
        return min(entries.count, 4)
    }
    
    var displayedEntries: [Entry] {
        guard let date = selectedDate else { return [] }
        let all = entriesForDay(date)
        if let spotlight = spotlightEntry, !showFullDay {
            return all.filter { $0.id == spotlight.id }
        }
        return all
    }
    
    // MARK: - Weeks
    
    var weeks: [[Date]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<52).reversed().map { w in
            (0..<7).compactMap { d in
                cal.date(byAdding: .day, value: -(w * 7 + (6 - d)), to: today)
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ChroniclesCardContainer(title: "Watch Timeline", icon: "film.stack", background: .parchment) {
            VStack(alignment: .leading, spacing: 10) {
                
                // Spotlight badge
                if let spotlight = spotlightEntry {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: "#E24B4A"))
                        Text(spotlight.mediaTitle ?? "Unknown")
                            .font(style.typeTitle3)
                            .foregroundStyle(Color.white.opacity(0.85))
                            .lineLimit(nil)
                            .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                spotlightEntry = nil
                                showFullDay = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(hex: "#E24B4A").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color(hex: "#E24B4A").opacity(0.25), lineWidth: 0.5)
                    )
                }
                
                // Grid
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 3) {
                            monthLabelRow
                            HStack(alignment: .top, spacing: cellSpacing) {
                                dayOfWeekLabels
                                HStack(spacing: cellSpacing) {
                                    ForEach(Array(weeks.enumerated()), id: \.offset) { wi, week in
                                        VStack(spacing: cellSpacing) {
                                            ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                                                let intensity = intensityForDay(date)
                                                let isSelected = selectedDate.map {
                                                    Calendar.current.isDate($0, inSameDayAs: date)
                                                } ?? false
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(cellColors[intensity])
                                                    .frame(width: cellSize, height: cellSize)
                                                    .overlay(
                                                        isSelected
                                                        ? RoundedRectangle(cornerRadius: 2)
                                                            .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                                                        : nil
                                                    )
                                                    .onTapGesture {
                                                        withAnimation(.easeInOut(duration: 0.15)) {
                                                            selectedDate = date
                                                            showFullDay = false
                                                        }
                                                    }
                                            }
                                        }
                                        .id("week-\(wi)")
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 2)
                    }
                    .onAppear {
                        proxy.scrollTo("week-51", anchor: .trailing)
                    }
                }
                
                // Legend
                HStack(spacing: 4) {
                    Text("less")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.3))
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(cellColors[i])
                            .frame(width: 14, height: 14)
                    }
                    Text("more")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                
                // Detail panel
                detailPanel
            }
        }
    }
    
    // MARK: - Month labels
    
    var monthLabelRow: some View {
        HStack(spacing: cellSpacing) {
            Color.clear.frame(width: 18, height: 12)
            HStack(spacing: cellSpacing) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { wi, week in
                    let firstDay = week.first ?? Date()
                    let dayOfMonth = Calendar.current.component(.day, from: firstDay)
                    let showLabel = dayOfMonth <= 7 || wi == 0
                    Text(showLabel ? firstDay.formatted(.dateTime.month(.abbreviated)) : "")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .frame(width: cellSize, height: 12)
                }
            }
        }
    }
    
    // MARK: - Day of week labels
    
    var dayOfWeekLabels: some View {
        VStack(spacing: cellSpacing) {
            ForEach(["", "M", "", "W", "", "F", ""], id: \.self) { label in
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .frame(width: 14, height: cellSize)
            }
        }
    }
    
    // MARK: - Detail panel
    
    var detailPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let date = selectedDate {
                Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(style.typeBodySecondary)
                    .foregroundStyle(Color.white.opacity(0.4))
                
                if displayedEntries.isEmpty {
                    Text("Nothing logged this day")
                        .font(style.typeBodySecondary)
                        .foregroundStyle(Color.white.opacity(0.25))
                        .italic()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(displayedEntries) { entry in
                                NavigationLink(value: entry) {
                                    coverChip(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    if spotlightEntry != nil && !showFullDay {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showFullDay = true
                            }
                        } label: {
                            Text("Show full day")
                                .font(style.typeCaption)
                                .foregroundStyle(Color.white.opacity(0.35))
                                .underline()
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("Tap a square to see what you watched")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(Color.white.opacity(0.25))
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
    
    // MARK: - Cover chip
    
    func coverChip(entry: Entry) -> some View {
        let isSpotlit = spotlightEntry?.id == entry.id
        return VStack(alignment: .center, spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let path = entry.mediaCoverPath,
                       let data = MediaFileManager.load(path: path),
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: entry.mediaType == "podcast" ? 80 : 120)
                            .clipped()
                    } else {
                        ZStack {
                            Color.white.opacity(0.08)
                            Image(systemName: entry.mediaType == "game"
                                  ? "gamecontroller.fill"
                                  : entry.mediaType == "podcast" ? "mic.fill"
                                  : entry.mediaType == "tv" ? "tv.fill" : "film.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.white.opacity(0.3))
                        }
                        .frame(width: 80, height: entry.mediaType == "podcast" ? 80 : 120)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: entry.mediaType == "podcast" ? 10 : 5))
                .overlay(alignment: .topTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isSpotlit {
                                spotlightEntry = nil
                                showFullDay = false
                            } else {
                                spotlightEntry = entry
                                showFullDay = false
                            }
                        }
                    } label: {
                        Image(systemName: isSpotlit ? "eye.fill" : "eye")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isSpotlit ? Color(hex: "#E24B4A") : Color.white.opacity(0.8))
                            .frame(width: 24, height: 24)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Circle())
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Text(entry.mediaTitle ?? "Unknown")
                .font(style.typeCaption)
                .foregroundStyle(Color.white.opacity(0.5))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 80)
        }
    }
}
