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
    @State private var keyboardVisible = false
    
    var style: any AppThemeStyle { themeManager.style }
    
    var todayEntries: [Entry] {
        entries
            .filter { Calendar.current.isDateInToday($0.createdAt) }
            .filter { $0.type != .journal }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    // MARK: - Body
    
    var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        titleHeader
                        WeeklyReviewCard()
                        if let entry = entries.first(where: {
                            Calendar.current.isDateInToday($0.createdAt) && $0.type == .journal
                        }),
                           !entry.weatherEmoji.isEmpty,
                           !entry.moodEmoji.isEmpty,
                           !entry.vibeEmoji.isEmpty {
                            JournalPromptCard(
                                weather: entry.weatherEmoji,
                                mood: entry.moodEmoji,
                                vibe: entry.vibeEmoji
                            )
                        }
                        JournalBlockView()
                        capturedTodayBlock
                        emptyTodayBlock
                    }
                    .padding(.vertical)
                }
            .scrollDismissesKeyboard(.interactively)
            .keyboardAvoiding()
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardVisible = false
            }            .background(style.background)
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
                Text("Today")
                    .font(style.typeLargeTitle)
                    .foregroundStyle(style.primaryText)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 4)
        }
    
    @ViewBuilder
    var capturedTodayBlock: some View {
        if !todayEntries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Captured Today", systemImage: "tray.fill")
                                    .font(style.typeTitle3)
                                    .foregroundStyle(style.secondaryText)
                    .padding(.horizontal)
                ForEach(todayEntries) { entry in
                    NavigationLink(destination: NavigationRouter.destination(for: entry)) {
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
                                    .font(style.typeBodySecondary)
                                    .foregroundStyle(style.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
        }
    }
}
