// OnThisDayCard.swift
// Commonplace
//
// Chronicles card showing entries from approximately one month ago.
// Receives pre-filtered oneMonthAgoEntries from ChroniclesView —
// no filtering performed at render time.
//
// Updated v2.4 — pre-filtered data, charcoal card, colored entry icons.

import SwiftUI

struct OnThisDayCard: View {
    let oneMonthAgoEntries: [Entry]
    var style: any AppThemeStyle
    let themeManager: ThemeManager

    @State private var showingAll = false

        var photoEntries: [Entry] {
            oneMonthAgoEntries.filter { $0.type == .photo && $0.imagePath != nil }
        }

        var nonPhotoEntries: [Entry] {
            oneMonthAgoEntries.filter { $0.type != .photo || $0.imagePath == nil }
                .sorted { $0.createdAt > $1.createdAt }
        }

        var visibleNonPhotoEntries: [Entry] {
            showingAll ? nonPhotoEntries : Array(nonPhotoEntries.prefix(5))
        }

        var body: some View {
            ChroniclesCardContainer(title: "One Month Ago", icon: "clock.arrow.circlepath", cardID: "onThisDay", background: .parchment) {
                if oneMonthAgoEntries.isEmpty {
                    Text("Nothing captured around this time last month. Keep adding entries — your archive will grow.")
                        .font(style.typeBodySecondary)
                        .foregroundStyle(ChroniclesTheme.tertiaryText)
                } else {
                    VStack(alignment: .leading, spacing: 12) {

                        // Photo thumbnail grid
                        if !photoEntries.isEmpty {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 4),
                                spacing: 3
                            ) {
                                ForEach(photoEntries) { entry in
                                    NavigationLink(value: entry) {
                                        photoThumb(entry: entry)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Slim entry rows
                        if !nonPhotoEntries.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(visibleNonPhotoEntries) { entry in
                                    NavigationLink(value: entry) {
                                        entryRow(entry: entry)
                                    }
                                    .buttonStyle(.plain)
                                    if entry.id != visibleNonPhotoEntries.last?.id {
                                        Divider()
                                            .overlay(ChroniclesTheme.sectionDivider)
                                            .padding(.leading, 36)
                                    }
                                }

                                // Show more
                                if !showingAll && nonPhotoEntries.count > 5 {
                                    Button {
                                        showingAll = true
                                    } label: {
                                        Text("\(nonPhotoEntries.count - 5) more from this time")
                                            .font(style.typeCaption)
                                            .foregroundStyle(style.accent)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                            .padding(.top, 8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
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
                    .foregroundStyle(entry.type.accentColor(for: themeManager.current).opacity(0.9))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(previewText(for: entry))
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.primaryText)
                    .lineLimit(2)
                Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(style.typeCaption)
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ChroniclesTheme.tertiaryText)
        }
        .padding(.vertical, 8)
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
                            .fill(ChroniclesTheme.cardGradient)
                            .frame(width: geo.size.width, height: geo.size.width)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(ChroniclesTheme.tertiaryText)
                            )
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }

        func previewText(for entry: Entry) -> String {
        switch entry.type {
        case .location: return entry.locationName ?? "A place"
        case .link:     return entry.linkTitle ?? entry.url ?? "A link"
        case .media:    return entry.mediaTitle ?? "A media entry"
        case .music:    return entry.linkTitle ?? "A track"
        case .sticky:   return entry.stickyTitle ?? "A list"
        case .audio:    return entry.text.components(separatedBy: "\n").first
                               .flatMap { $0.isEmpty ? nil : $0 } ?? "A recording"
        default:
            let firstLine = entry.text.components(separatedBy: "\n").first ?? ""
            let text = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? entry.type.displayName : text
        }
    }
}
