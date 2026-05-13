// EntryCalendarCard.swift
// Commonplace
//
// Chronicles card showing a monthly calendar where each day cell contains
// a 3x3 dot grid representing the nine non-journal entry types.
// A filled dot indicates at least one entry of that type was captured that day.
//
// Dot order mirrors the new entry dialog (left-to-right, top-to-bottom):
//   Note · Shot · Sound
//   Link · List · Place
//   Music · Media · File
//
// Tapping a day expands an inline panel listing that day's entries,
// each tappable via NavigationLink(value:) — requires navigationDestination
// for Entry.self to be registered on the parent NavigationStack (ChroniclesView).
//
// Month navigation: backward up to 12 months, never forward past current month.
// allEntries passed from ChroniclesView — no internal @Query.
// Screen: Chronicles tab

import SwiftUI

struct EntryCalendarCard: View {
    let allEntries: [Entry]
    let style: any AppThemeStyle
    let themeManager: ThemeManager
    
    // MARK: - State
    
    @EnvironmentObject var router: NavigationRouter
        @State private var currentYear: Int = Calendar.current.component(.year, from: Date())
    @State private var currentMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedDay: DateComponents? = nil
    
    // MARK: - Entry type dot definitions
    // Order matches the new entry dialog grid exactly
    
    private let dotTypes: [(type: EntryType, label: String)] = [
        (.text,       "Note"),
        (.photo,      "Shot"),
        (.audio,      "Sound"),
        (.link,       "Link"),
        (.sticky,     "List"),
        (.location,   "Place"),
        (.music,      "Music"),
        (.media,      "Media"),
        (.attachment, "File"),
    ]
    
    // MARK: - Derived
    
    private var today: DateComponents {
        Calendar.current.dateComponents([.year, .month, .day], from: Date())
    }
    
    private var isCurrentMonth: Bool {
        currentYear == today.year && currentMonth == today.month
    }
    
    private var isOldestMonth: Bool {
        let monthsBack = (today.year! - currentYear) * 12 + (today.month! - currentMonth)
        return monthsBack >= 12
    }
    
    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: firstDayOfCurrentMonth)
    }
    
    private var firstDayOfCurrentMonth: Date {
        var comps = DateComponents()
        comps.year = currentYear
        comps.month = currentMonth
        comps.day = 1
        return Calendar.current.date(from: comps) ?? Date()
    }
    
    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: firstDayOfCurrentMonth)?.count ?? 30
    }
    
    private var firstWeekday: Int {
        let weekday = Calendar.current.component(.weekday, from: firstDayOfCurrentMonth)
        // weekday: 1 = Sunday ... 7 = Saturday
        // Offset so Sunday = 0, matching our grid columns
        return (weekday - Calendar.current.firstWeekday + 7) % 7
    }
    
    // Group entries by day for the current month — computed once per render
    private var entriesByDay: [Int: [Entry]] {
        var result: [Int: [Entry]] = [:]
        let cal = Calendar.current
        for entry in allEntries {
            guard entry.type != .journal else { continue }
            let comps = cal.dateComponents([.year, .month, .day], from: entry.createdAt)
            guard comps.year == currentYear, comps.month == currentMonth,
                  let day = comps.day else { continue }
            result[day, default: []].append(entry)
        }
        return result
    }
    
    private var selectedEntries: [Entry] {
        guard let sel = selectedDay, let day = sel.day else { return [] }
        return (entriesByDay[day] ?? []).sorted { $0.createdAt < $1.createdAt }
    }
    
    private var selectedDateLabel: String {
        guard let sel = selectedDay,
              let date = Calendar.current.date(from: sel) else { return "" }
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
    
    // MARK: - Body
    
    var body: some View {
        ChroniclesCardContainer(title: "Entry Calendar", icon: "calendar", cardID: "entryCalendar", background: .parchment) {
            VStack(alignment: .leading, spacing: 12) {
                monthNavigation
                weekdayHeaders
                calendarGrid
                if selectedDay != nil {
                    expandedPanel
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                legend
            }
            .animation(.easeInOut(duration: 0.2), value: selectedDay?.day)
        }
    }
    
    // MARK: - Month navigation
    
    var monthNavigation: some View {
        HStack {
            Button {
                stepMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isOldestMonth ? Color.white.opacity(0.2) : Color.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .disabled(isOldestMonth)
            
            Spacer()
            
            Text(monthLabel)
                .font(style.typeBodySecondary)
                .fontWeight(.medium)
                .foregroundStyle(Color.white)
            Text("firstWeekday: \(firstWeekday)")
                .foregroundStyle(Color.white)
            Spacer()
            
            Button {
                stepMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isCurrentMonth ? Color.white.opacity(0.2) : Color.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .disabled(isCurrentMonth)
        }
    }
    
    // MARK: - Weekday headers
    
    var weekdayHeaders: some View {
        HStack(spacing: 4) {
            ForEach(["Su","Mo","Tu","We","Th","Fr","Sa"], id: \.self) { day in
                Text(day)
                    .font(style.typeCaption)
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Calendar grid
    
    var calendarGrid: some View {
        let totalCells = firstWeekday + daysInMonth
        let totalRows = Int(ceil(Double(totalCells) / 7.0))
        
        return VStack(spacing: 4) {
            ForEach(0..<totalRows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { col in
                        let cellIndex = row * 7 + col
                        let day = cellIndex - firstWeekday + 1
                        if cellIndex < firstWeekday || day > daysInMonth {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: 48)
                        } else {
                            dayCell(day: day)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func dayCell(day: Int) -> some View {
        let entries = entriesByDay[day] ?? []
        let activeTypes = Set(entries.map { $0.type })
        let isFuture = isFutureDay(day)
        let isToday = today.day == day && isCurrentMonth
        let isSelected = selectedDay?.day == day
        
        Button {
            if !entries.isEmpty {
                let comps = DateComponents(year: currentYear, month: currentMonth, day: day)
                selectedDay = (selectedDay?.day == day) ? nil : comps
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(day)")
                    .font(.system(size: 10))
                    .foregroundStyle(isToday ? Color.white : Color.white.opacity(0.45))
                    .fontWeight(isToday ? .semibold : .regular)
                
                // 3x3 dot grid
                VStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { col in
                                let typeIndex = row * 3 + col
                                let entryType = dotTypes[typeIndex].type
                                let isActive = activeTypes.contains(entryType)
                                Circle()
                                    .fill(isActive
                                          ? entryType.accentColor(for: themeManager.current)
                                          : Color.white.opacity(0.08))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.white.opacity(0.08) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                isToday ? ChroniclesTheme.accentAmber :
                                    isSelected ? Color.white.opacity(0.2) : Color.clear,
                                lineWidth: isToday ? 1 : 0.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(isFuture ? 0.25 : 1)
        .disabled(isFuture || entries.isEmpty)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    // MARK: - Expanded day panel
    
    var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .overlay(Color.white.opacity(0.1))
                .padding(.bottom, 10)
            
            Text(selectedDateLabel)
                .font(style.typeCaption)
                .foregroundStyle(Color.white.opacity(0.5))
                .padding(.bottom, 8)
            
            ForEach(selectedEntries) { entry in
                if UIDevice.current.userInterfaceIdiom == .pad {
                                Button { router.selectEntry(entry) } label: {
                                    entryRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink(value: entry) {
                                    entryRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                
                if entry.id != selectedEntries.last?.id {
                    Divider()
                        .overlay(Color.white.opacity(0.1))
                        .padding(.leading, 36)
                }
            }
        }
    }
    
    func entryRow(entry: Entry) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(entry.type.accentColor(for: themeManager.current).opacity(0.25))
                    .frame(width: 28, height: 28)
                Image(systemName: entry.type.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(entry.type.accentColor(for: themeManager.current))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(previewText(for: entry))
                    .font(style.typeBodySecondary)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(2)
                Text(entry.createdAt.formatted(.dateTime.hour().minute()))
                    .font(style.typeCaption)
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.3))
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Legend
    
    var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .overlay(Color.white.opacity(0.1))
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3),
                spacing: 6
            ) {
                ForEach(dotTypes, id: \.label) { item in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(item.type.accentColor(for: themeManager.current))
                            .frame(width: 7, height: 7)
                        Text(item.label)
                            .font(style.typeCaption)
                            .foregroundStyle(Color.white.opacity(0.45))
                        Spacer()
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    func stepMonth(by delta: Int) {
        var comps = DateComponents()
        comps.year = currentYear
        comps.month = currentMonth + delta
        if let newDate = Calendar.current.date(from: comps) {
            currentYear = Calendar.current.component(.year, from: newDate)
            currentMonth = Calendar.current.component(.month, from: newDate)
            selectedDay = nil
        }
    }
    
    func isFutureDay(_ day: Int) -> Bool {
        guard isCurrentMonth else { return false }
        return day > (today.day ?? 0)
    }
    
    func previewText(for entry: Entry) -> String {
        switch entry.type {
        case .location:   return entry.locationName ?? "A place"
        case .link:       return entry.linkTitle ?? entry.url ?? "A link"
        case .media:      return entry.mediaTitle ?? "A media entry"
        case .music:      return entry.linkTitle ?? "A track"
        case .sticky:     return entry.stickyTitle ?? "A list"
        case .audio:      return entry.text.components(separatedBy: "\n").first
                .flatMap { $0.isEmpty ? nil : $0 } ?? "A recording"
        default:
            let first = entry.text.components(separatedBy: "\n").first ?? ""
            let text = first.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? entry.type.displayName : text
        }
    }
}
