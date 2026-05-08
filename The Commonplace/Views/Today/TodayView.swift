// TodayView.swift
// Commonplace
//
// Main view for the Today tab.
// Split into three segments via native Picker(.segmented):
//   - Journal (0): WeeklyReviewCard, JournalPromptCard, JournalBlockView
//   - Entries (1): entries captured today (non-journal)
//   - Media Log (2): NowPlayingBlock (in-progress TV and Movies)
// Segment selection persisted via @AppStorage.
// Screen: Today tab (bottom navigation)

import SwiftUI
import TipKit
import SwiftData
import CoreLocation

// MARK: - TodayView
// Main view for the Today tab.
// Split into three segments via native Picker(.segmented):
//   - Journal (0): WeeklyReviewCard, JournalPromptCard, JournalBlockView
//   - Entries (1): entries captured today (non-journal)
//   - Media Log (2): NowPlayingBlock (in-progress TV and Movies)
// Segment selection persisted via @AppStorage.
// Screen: Today tab (bottom navigation)

struct TodayView: View {
    @Environment(\.modelContext) var modelContext
    @Query var entries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager
    
    @AppStorage("todaySelectedSegment") private var selectedSegment: Int = 0
    @State private var keyboardVisible = false
    
    var style: any AppThemeStyle { themeManager.style }
    
    var todayEntries: [Entry] {
            entries
                .filter { Calendar.current.isDateInToday($0.createdAt) }
                .filter { $0.type != .journal }
                .sorted { $0.createdAt > $1.createdAt }
        }

        var todayJournalEntry: Entry? {
            entries.first {
                Calendar.current.isDateInToday($0.createdAt) && $0.type == .journal
            }
        }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    titleHeader
                    
                    TipView(TodayViewTip(), arrowEdge: .top)
                        .padding(.horizontal, 16)
                    
                    // Segment picker — native style per architecture convention
                    Picker("Today Segment", selection: $selectedSegment) {
                        Text("Journal").tag(0)
                        Text("Entries").tag(1)
                        Text("Media Log").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Segment content
                    switch selectedSegment {
                    case 0:
                        journalSegment
                    case 1:
                        entriesSegment
                    case 2:
                        mediaLogSegment
                    default:
                        journalSegment
                    }
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
            }
            .background(style.background)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Entry.self) { entry in
                NavigationRouter.destination(for: entry)
            }
            .navigationDestination(for: Tag.self) { tag in
                NavigationRouter.destination(for: tag)
            }
            .navigationDestination(for: Collection.self) { collection in
                CollectionDetailView(collection: collection)
            }
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
        }
    }
    
    // MARK: - Segments
    
    // Journal segment: weekly review, prompt card, journal block
    @ViewBuilder
    var journalSegment: some View {
        WeeklyReviewCard()
        if let entry = todayJournalEntry,
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
    }
    
    // Entries segment: today's non-journal captures
    @ViewBuilder
    var entriesSegment: some View {
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
        } else {
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
    
    // Media Log segment: in-progress TV and Movies via NowPlayingBlock
    @ViewBuilder
    var mediaLogSegment: some View {
        NowPlayingBlock()
        // NowPlayingBlock returns EmptyView when nothing is in progress.
        // The check below surfaces a legible empty state in that case.
        if !entries.contains(where: {
                    $0.type == .media &&
                    ["movie", "tv"].contains($0.mediaType ?? "") &&
                    ["inProgress", "rewatch", "replay"].contains($0.mediaStatus ?? "")
                }) {
            VStack(spacing: 8) {
                Image(systemName: "play.circle")
                    .font(.system(size: 32))
                    .foregroundStyle(style.tertiaryText)
                Text("Nothing in progress")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(style.tertiaryText)
                Text("Start watching something and it'll appear here.")
                    .font(style.typeCaption)
                    .foregroundStyle(style.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
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
}
