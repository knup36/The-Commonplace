// SlimEntryFeed.swift
// Commonplace
//
// Reusable compact single-line entry list.
// Designed for dense contexts where you want to show many entries
// without the visual weight of full EntryRowView cards.
//
// Format per row:
//   [colored dot]  [title/preview]  [date]
//
// The colored dot uses the entry's type accent color — no icons or
// labels needed, the color carries the type identity.
//
// Title/preview is derived per entry type:
//   .text     — first line of text (the title)
//   .link     — link title or URL
//   .location — location name
//   .music    — track title or artist
//   .media    — media title
//   .journal  — formatted date
//   .audio    — transcript preview or "Sound"
//   default   — first line of text or type display name
//
// Usage:
//   SlimEntryFeed(entries: slimEntries, style: style)
//
// Used in:
//   FolioDetailView — entries below stickies and photos
//   (future) ChroniclesView, PersonDetailView, SearchResultsView

import SwiftUI

struct SlimEntryFeed: View {
    let entries: [Entry]
    var style: any AppThemeStyle
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                NavigationLink(destination: NavigationRouter.destination(for: entry)) {
                    slimRow(entry: entry)
                }
                .buttonStyle(.plain)

                if entry.id != entries.last?.id {
                    Divider()
                        .overlay(style.cardDivider)
                        .padding(.leading, 28)
                }
            }
        }
        .background(style.surface.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Row

    func slimRow(entry: Entry) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(entry.type.detailAccentColor(for: themeManager.current))
                .frame(width: 7, height: 7)
                .padding(.leading, 12)

            Text(slimTitle(for: entry))
                .font(style.typeBodySecondary)
                .foregroundStyle(style.primaryText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                .font(style.typeCaption)
                .foregroundStyle(style.tertiaryText)
                .padding(.trailing, 12)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Title Derivation

    func slimTitle(for entry: Entry) -> String {
        switch entry.type {
        case .text:
            let parts = entry.text.components(separatedBy: "\n")
            let title = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return title.isEmpty ? "Thought" : title
        case .link:
            return entry.linkTitle ?? entry.url ?? "Link"
        case .location:
            return entry.locationName ?? "Place"
        case .music:
            if let title = entry.linkTitle, !title.isEmpty { return title }
            if let artist = entry.musicArtist { return artist }
            return "Music"
        case .media:
            return entry.mediaTitle ?? "Media"
        case .journal:
            return entry.createdAt.formatted(.dateTime.weekday(.wide).month(.wide).day())
        case .audio:
            if let transcript = entry.transcript, !transcript.isEmpty {
                return String(transcript.prefix(60))
            }
            return "Sound"
        default:
            let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? entry.type.displayName : String(text.prefix(60))
        }
    }
}
