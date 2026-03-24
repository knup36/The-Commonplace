import SwiftUI
import SwiftData
import CoreLocation

// MARK: - TodayView
// Main view for the Today tab.
// Shows the daily journal block, entries captured today, On This Day, and Stats.
// Screen: Today tab (bottom navigation)

struct TodayView: View {
    @Environment(\.modelContext) var modelContext
    @Query var entries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager

    // Settings is now a NavigationLink destination — no sheet state needed
    @State private var selectedTab = 0
    @State private var keyboardVisible = false

    var style: any AppThemeStyle { themeManager.style }

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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    titleHeader
                    segmentPicker
                    if selectedTab == 0 {
                        JournalBlockView()
                        capturedTodayBlock
                        emptyTodayBlock
                    }
                    if selectedTab == 1 {
                        onThisDayBlock
                    }
                    if selectedTab == 2 {
                        FeedStatsView(entries: entries)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .scrollDismissesKeyboard(.interactively)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardVisible = false
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 50)
            }
            .background(style.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if keyboardVisible {
                        Button("Done") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .foregroundStyle(style.accent)
                    }
                }
            }
            // Settings presented via NavigationLink — no sheet needed
        }
    }

    // MARK: - Sub-views

    var titleHeader: some View {
        HStack {
            Text(selectedTab == 0 ? "Today" : selectedTab == 1 ? "On This Day" : "Stats")
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
            Text("Stats").tag(2)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
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
}
