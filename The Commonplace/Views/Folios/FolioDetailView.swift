// FolioDetailView.swift
// Commonplace
//
// Detail view for a Tag that has been promoted to a Folio (subjectType == "folioGeneric").
// Organizes all entries tagged with this Folio into type-aware sections.
//
// Layout:
//   Header     — large emoji, formatted name, colored entry type counts
//   Stickies   — compact 2-column grid of checklist cards (always first)
//   Shots      — 4-column tight thumbnail grid
//   Slim feed  — all other entry types as single-line rows, colored dot accent
//
// Entry type counts in header use each type's accent color.
// Zero counts shown dimmed — all 9 types always visible.
//
// Slim row format: [colored dot] [title/preview] [date]
// No section headers — entry type colors do the organizational work.
//
// Toolbar: ··· menu with Pin/Unpin and Delete.
// Demotion not available in v2.0.

import SwiftUI
import SwiftData

struct FolioDetailView: View {
    var tag: Tag
    @Query(sort: \Entry.createdAt, order: .reverse) var allEntries: [Entry]
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var editMode = EditModeManager()

    @State private var showingDeleteConfirmation = false

    var style: any AppThemeStyle { themeManager.style }

    // MARK: - Entry Grouping

    var taggedEntries: [Entry] {
        allEntries.filter { $0.tagNames.contains(tag.name) }
    }

    var stickyEntries: [Entry] {
        taggedEntries.filter { $0.type == .sticky }
    }

    var photoEntries: [Entry] {
        taggedEntries.filter { $0.type == .photo }
    }

    var slimEntries: [Entry] {
        taggedEntries.filter { $0.type != .sticky && $0.type != .photo }
    }

    // MARK: - Count per type (all 9, in display order)

    let typeOrder: [EntryType] = [.text, .photo, .audio, .link, .journal, .location, .sticky, .music, .media]

    func count(for type: EntryType) -> Int {
        taggedEntries.filter { $0.type == type }.count
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                folioHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if !stickyEntries.isEmpty {
                    stickySection
                        .padding(.horizontal, 16)
                }

                if !photoEntries.isEmpty {
                    photoGrid
                        .padding(.horizontal, 16)
                }

                if !slimEntries.isEmpty {
                    slimFeed
                        .padding(.horizontal, 16)
                }

                Spacer().frame(height: 80)
            }
        }
        .background(style.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        withAnimation { tag.isPinned.toggle() }
                        try? modelContext.save()
                    } label: {
                        Label(tag.isPinned ? "Remove Bookmark" : "Bookmark",
                                                      systemImage: tag.isPinned ? "bookmark.slash" : "bookmark")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Folio", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(style.accent)
                }
            }
        }
        .confirmationDialog(
            "Delete \"\(tag.folioDisplayName)\"?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Folio", role: .destructive) {
                modelContext.delete(tag)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The tag and its emoji will be removed. Your entries will not be deleted.")
        }
        .onDisappear {
            try? modelContext.save()
        }
    }

    // MARK: - Header

    var folioHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(tag.subjectEmoji ?? "◆")
                    .font(.system(size: 44))
                VStack(alignment: .leading, spacing: 2) {
                    Text(tag.folioDisplayName)
                        .font(style.typeLargeTitle)
                        .foregroundStyle(style.primaryText)
                    Text("\(taggedEntries.count) \(taggedEntries.count == 1 ? "entry" : "entries")")
                        .font(style.typeCaption)
                        .foregroundStyle(style.secondaryText)
                }
            }

            // Colored entry type counts
            HStack(spacing: 0) {
                ForEach(typeOrder, id: \.self) { type in
                    let c = count(for: type)
                    Text("\(c)")
                        .font(.system(size: 15, weight: c > 0 ? .semibold : .regular))
                        .foregroundStyle(
                            c > 0
                                ? type.detailAccentColor(for: themeManager.current)
                                : style.tertiaryText.opacity(0.3)
                        )
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(style.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Sticky Section

    var stickySection: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
            spacing: 10
        ) {
            ForEach(stickyEntries) { entry in
                NavigationLink(destination: NavigationRouter.destination(for: entry)) {
                    CompactEntryCard(entry: entry, style: style)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Photo Grid (4 columns)

    var photoGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 4),
            spacing: 3
        ) {
            ForEach(photoEntries) { entry in
                NavigationLink(destination: NavigationRouter.destination(for: entry)) {
                    photoThumb(entry: entry)
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    func photoThumb(entry: Entry) -> some View {
        GeometryReader { geo in
            Group {
                if let path = entry.imagePath,
                   let data = MediaFileManager.load(path: path),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(style.surface)
                        .frame(width: geo.size.width, height: geo.size.width)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(style.tertiaryText)
                        )
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Slim Feed

        var slimFeed: some View {
            SlimEntryFeed(entries: slimEntries, style: style)
        }
}
