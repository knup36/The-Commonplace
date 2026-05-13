// ConnectedPagesSection.swift
// Commonplace
//
// Reusable Connected Pages section used in all entry detail views.
// Renders below EntryTagRow, above the metadata divider.
//
// View mode:
//   - Hidden entirely when no links exist
//   - Shows Chronicles-style rows (dot + title + date) when links exist
//   - Each row navigates to the linked entry via NavigationLink(value:)
//
// Edit mode:
//   - Shows "Add linked entry +" row when no links exist
//   - Shows same Chronicles-style rows with leading ✕ remove badge
//   - Tapping ✕ calls LinkedEntryService.unlink and updates immediately
//   - Tapping "+" or the add row presents ConnectPageSheet
//
// Architecture:
//   - Fetches linked entries via targeted @Query filtered by UUID — not full archive
//   - ConnectPageSheet owns its own full archive @Query
//   - .sheet lives on the Group in body — never on a child view — to avoid
//     NavigationLink interference (sheet on child view captures nav stack)

import SwiftUI
import SwiftData

struct ConnectedPagesSection: View {
    @Bindable var entry: Entry
    var style: any AppThemeStyle
    var accentColor: Color
    @Binding var showingConnectSheet: Bool
    
    @Environment(\.modelContext) private var context
    @EnvironmentObject var editMode: EditModeManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var router: NavigationRouter
    
    // Fetch only the entries referenced by linkedEntryIDs — not the full archive
    @Query private var allEntries: [Entry]
    
    private var linkedEntries: [Entry] {
        let linkedIDSet = Set(entry.linkedEntryIDs)
        return allEntries.filter { linkedIDSet.contains($0.id.uuidString) }
    }
    
    init(entry: Entry, style: any AppThemeStyle, accentColor: Color, showingConnectSheet: Binding<Bool>) {
        self.entry = entry
        self.style = style
        self.accentColor = accentColor
        self._showingConnectSheet = showingConnectSheet
        
        let linkedIDs = entry.linkedEntryIDs.compactMap { UUID(uuidString: $0) }
        self._allEntries = Query(
            filter: #Predicate<Entry> { linkedIDs.contains($0.id) },
            sort: \Entry.createdAt,
            order: .reverse
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if editMode.isEditing {
                editModeSection
            } else {
                viewModeSection
            }
        }
        .sheet(isPresented: $showingConnectSheet) {
            ConnectPageSheet(entry: entry) {}
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }
    
    // MARK: - View Mode
    
    @ViewBuilder
    var viewModeSection: some View {
        if !linkedEntries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel
                VStack(spacing: 0) {
                    ForEach(linkedEntries) { linked in
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            Button { router.selectEntry(linked) } label: {
                                entryRow(linked)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(destination: NavigationRouter.destination(for: linked)) {
                                entryRow(linked)
                            }
                            .buttonStyle(.plain)
                        }
                        if linked.id != linkedEntries.last?.id {
                            Divider()
                                .overlay(style.cardDivider)
                                .padding(.leading, 20)
                        }
                    }
                }
            }
        }
        // Hidden entirely when empty — no empty state in view mode
    }
    
    // MARK: - Edit Mode
    
    var editModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if linkedEntries.isEmpty {
                addLinkedEntryRow
            } else {
                sectionLabel
                VStack(spacing: 0) {
                    ForEach(linkedEntries) { linked in
                        HStack(spacing: 0) {
                            // Remove badge
                            Button {
                                LinkedEntryService.unlink(entry, from: linked, context: context)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(style.background)
                                        .frame(width: 20, height: 20)
                                    Circle()
                                        .fill(style.cardMetadataText.opacity(0.25))
                                        .frame(width: 18, height: 18)
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(style.cardMetadataText)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 8)
                            
                            if UIDevice.current.userInterfaceIdiom == .pad {
                                Button { router.selectEntry(linked) } label: {
                                    entryRow(linked)
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink(destination: NavigationRouter.destination(for: linked)) {
                                    entryRow(linked)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if linked.id != linkedEntries.last?.id {
                            Divider()
                                .overlay(style.cardDivider)
                                .padding(.leading, 20)
                        }
                    }
                }
                addMoreButton
            }
        }
    }
    
    // MARK: - Shared Entry Row (view + edit mode)
    
    func entryRow(_ linked: Entry) -> some View {
        let accent = linked.type.detailAccentColor(for: themeManager.current)
        return HStack(spacing: 10) {
            Circle()
                .fill(accent)
                .frame(width: 8, height: 8)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(rowTitle(for: linked))
                    .font(style.typeBodySecondary)
                    .foregroundStyle(style.cardPrimaryText)
                    .lineLimit(2)
                Text(linked.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(style.typeCaption)
                    .foregroundStyle(accent.opacity(0.7))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(style.cardMetadataText)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    // MARK: - Section Label
    
    var sectionLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "link")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(style.cardMetadataText)
            Text("CONNECTED PAGES")
                .font(style.typeSectionHeader)
                .foregroundStyle(style.cardMetadataText)
        }
    }
    
    // MARK: - Add Row (empty edit mode)
    
    var addLinkedEntryRow: some View {
        Button {
            showingConnectSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(style.cardMetadataText)
                Text("Add linked entry...")
                    .font(.body)
                    .foregroundStyle(style.cardMetadataText)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Add More Button (non-empty edit mode)
    
    var addMoreButton: some View {
        Button {
            showingConnectSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                Text("Add another")
                    .font(style.typeCaption)
            }
            .foregroundStyle(accentColor)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Title Derivation
    
    func rowTitle(for entry: Entry) -> String {
        switch entry.type {
        case .text:
            let first = entry.text.components(separatedBy: "\n").first ?? ""
            return first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Note" : first
        case .link:       return entry.linkTitle ?? entry.url ?? "Link"
        case .location:   return entry.locationName ?? "Place"
        case .music:      return entry.linkTitle ?? entry.musicArtist ?? "Music"
        case .media:      return entry.mediaTitle ?? "Media"
        case .journal:    return entry.createdAt.formatted(.dateTime.weekday(.wide).month(.wide).day())
        case .audio:      return entry.transcript.flatMap { $0.isEmpty ? nil : String($0.prefix(60)) } ?? "Sound"
        case .photo:
            let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? "Shot" : String(text.prefix(60))
        case .sticky:     return entry.stickyTitle ?? "List"
        case .attachment: return entry.attachmentFilename ?? "Attachment"
        }
    }
}
