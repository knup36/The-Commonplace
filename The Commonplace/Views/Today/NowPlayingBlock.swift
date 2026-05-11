// NowPlayingBlock.swift
// Commonplace
//
// A Today tab block showing all In Progress media entries (TV, Movies, Games).
// Displays a 4-wide portrait poster grid with quick-log actions per title.
//
// Actions:
//   ✓ Watched — appends a "Watched" log entry immediately with a checkmark
//               flash animation over the poster.
//   💬 Note   — expands an inline text field below the poster for a typed note.
//               Only one note input is open at a time.
//
// Statuses included: inProgress, rewatch, replay
// Hidden entirely when no qualifying entries exist.

import SwiftUI
import SwiftData

struct NowPlayingBlock: View {
    @Environment(\.modelContext) var modelContext
        @Query(filter: #Predicate<Entry> {
            $0.typeRawValue == "media"
        }, sort: \Entry.createdAt, order: .reverse) var entries: [Entry]
        @EnvironmentObject var themeManager: ThemeManager
    
    var style: any AppThemeStyle { themeManager.style }

    /// Injected by TodayView on iPad. Nil on iPhone — NavigationLink used instead.
    var onSelectEntry: ((Entry) -> Void)? = nil
    
    // MARK: - State
    
    @State private var activeNoteEntryID: UUID? = nil
    @State private var noteText: String = ""
    @State private var watchedFlashIDs: Set<UUID> = []
    
    // MARK: - Derived
    
    var inProgressEntries: [Entry] {
        entries.filter {
            $0.type == .media &&
            ["movie", "tv"].contains($0.mediaType ?? "") &&
            ["inProgress", "rewatch", "replay"].contains($0.mediaStatus ?? "")
        }
        .sorted { ($0.mediaTitle ?? "") < ($1.mediaTitle ?? "") }
    }
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        private static let isoFormatter = ISO8601DateFormatter()
    
    // MARK: - Body
    
    var body: some View {
        if inProgressEntries.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 12) {
                Label("Now Playing", systemImage: "play.circle.fill")
                    .font(style.typeTitle3)
                    .foregroundStyle(style.secondaryText)
                    .padding(.horizontal)
                
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(inProgressEntries) { entry in
                        posterCell(entry: entry)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Poster Cell
        
        @ViewBuilder
        func posterCell(entry: Entry) -> some View {
            VStack(spacing: 6) {
                
                // Poster
                // iPad: callback drives detail panel. iPhone: NavigationLink push as before.
                let posterZStack = ZStack {
                    posterImage(entry: entry)
                        .aspectRatio(2/3, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(style.cardBorder, lineWidth: 0.5)
                        )
                    
                    // Watched flash overlay
                    if watchedFlashIDs.contains(entry.id) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.6))
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                
                if let onSelect = onSelectEntry {
                    Button { onSelect(entry) } label: { posterZStack }
                        .buttonStyle(.plain)
                } else {
                    NavigationLink(destination: NavigationRouter.destination(for: entry)) {
                        posterZStack
                    }
                    .buttonStyle(.plain)
                }
            
            // Action buttons
            HStack(spacing: 16) {
                // Watched
                Button {
                    appendWatched(entry: entry)
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(style.accent)
                }
                .buttonStyle(.plain)
                
                // Note
                Button {
                    if activeNoteEntryID == entry.id {
                        activeNoteEntryID = nil
                        noteText = ""
                    } else {
                        activeNoteEntryID = entry.id
                        noteText = ""
                    }
                } label: {
                    Image(systemName: activeNoteEntryID == entry.id ? "bubble.left.fill" : "bubble.left")
                        .font(.system(size: 16))
                        .foregroundStyle(style.accent)
                }
                .buttonStyle(.plain)
            }
            
            // Inline note input
            if activeNoteEntryID == entry.id {
                VStack(spacing: 6) {
                    CommonplaceTextEditor(
                        text: $noteText,
                        placeholder: "What are you thinking?",
                        usesSerifFont: false,
                        focusOnAppear: true
                    )
                    .padding(8)
                    .background(style.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    HStack {
                        Spacer()
                        Button("Cancel") {
                            activeNoteEntryID = nil
                            noteText = ""
                        }
                        .font(style.typeCaption)
                        .foregroundStyle(style.secondaryText)
                        
                        Button("Add") {
                            appendNote(entry: entry)
                        }
                        .font(style.typeCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(style.accent)
                        .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Poster Image
    
    @ViewBuilder
    func posterImage(entry: Entry) -> some View {
        if let path = entry.mediaCoverPath,
           let data = MediaFileManager.load(path: path),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(style.surface)
                .overlay(
                    Image(systemName: entry.type.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(style.tertiaryText)
                )
        }
    }
    
    // MARK: - Actions
    
    func appendWatched(entry: Entry) {
        let today = Calendar.current.startOfDay(for: Date())
        let alreadyLogged = entry.mediaLog.contains { log in
                    let parts = log.components(separatedBy: "::")
                    guard parts.count == 2,
                          let date = Self.isoFormatter.date(from: parts[0]) else { return false }
                    return Calendar.current.startOfDay(for: date) == today && parts[1] == "Watched"
                }
                guard !alreadyLogged else { return }

                let dateString = Self.isoFormatter.string(from: Date())
        entry.mediaLog.append("\(dateString)::Watched")
        entry.touch()
        
        // Flash animation
        withAnimation(.easeIn(duration: 0.15)) {
            watchedFlashIDs.insert(entry.id)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                _ = self.watchedFlashIDs.remove(entry.id)
            }
        }
    }
    
    func appendNote(entry: Entry) {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let dateString = Self.isoFormatter.string(from: Date())
                entry.mediaLog.append("\(dateString)::\(trimmed)")
        entry.touch()
        activeNoteEntryID = nil
        noteText = ""
    }
}
