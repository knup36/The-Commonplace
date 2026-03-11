import SwiftUI

struct EntryRowView: View {
    let entry: Entry
    @EnvironmentObject var themeManager: ThemeManager

    var isInkwell: Bool { themeManager.current == .inkwell }

    var entryColor: Color {
        if isInkwell { return InkwellTheme.cardBackground(for: entry.type) }
        switch entry.type {
        case .text:     return Color(uiColor: .systemGray5)
        case .photo:    return Color.pink.opacity(0.15)
        case .audio:    return Color.orange.opacity(0.15)
        case .link:     return Color.blue.opacity(0.15)
        case .journal:  return Color(hex: "#BF5AF2").opacity(0.15)
        case .location: return Color.green.opacity(0.15)
        case .sticky:   return Color(hex: "#FFD60A").opacity(0.15)
        }
    }

    var entryAccentColor: Color {
        if isInkwell { return InkwellTheme.accentColor(for: entry.type) }
        switch entry.type {
        case .text:     return Color(uiColor: .systemGray)
        case .photo:    return Color.pink
        case .audio:    return Color.orange
        case .link:     return Color.blue
        case .journal:  return Color(hex: "#BF5AF2")
        case .location: return Color.green
        case .sticky:   return Color(hex: "#FFD60A")
        }
    }

    var iconForType: String {
        switch entry.type {
        case .text:     return "text.alignleft"
        case .photo:    return "photo"
        case .audio:    return "waveform"
        case .link:     return "link"
        case .journal:  return "bookmark.fill"
        case .location: return "mappin.circle.fill"
        case .sticky:   return "checklist"
        }
    }

    var typeName: String {
        switch entry.type {
        case .text:     return "Note"
        case .photo:    return "Photo"
        case .audio:    return "Audio"
        case .link:     return "Link"
        case .journal:  return "Journal"
        case .location: return "Place"
        case .sticky:   return "List"
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    var typeLabel: some View {
        if isInkwell {
            HStack(spacing: 5) {
                Circle()
                    .fill(entryAccentColor)
                    .frame(width: 5, height: 5)
                Text(typeName.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .kerning(0.8)
                    .foregroundStyle(entryAccentColor)
            }
        }
    }

    var metadataColumn: some View {
        HStack(spacing: 6) {
            Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(isInkwell ? entryAccentColor.opacity(0.5) : entryAccentColor.opacity(0.5))
                        Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(isInkwell ? entryAccentColor.opacity(0.5) : entryAccentColor.opacity(0.5))
            if !isInkwell {
                ZStack {
                    Circle()
                        .fill(entryAccentColor.opacity(0.1))
                        .frame(width: 22, height: 22)
                    Image(systemName: iconForType)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(entryAccentColor.opacity(0.7))
                }
            }
        }
        .fixedSize()
    }

    @ViewBuilder
    var cardContent: some View {
        if let imageData = entry.imageData {
            AnimatedImageView(data: imageData, isAnimated: AnimatedImageView.isGIF(data: imageData), crop: false)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        if entry.type == .link {
            LinkPreviewView(entry: entry)
        }
        if entry.type == .location {
            LocationRowView(entry: entry)
        }
        if entry.type == .journal {
            DailyNoteRowView(entry: entry)
        } else if entry.type == .sticky {
                        StickyEntryView(entry: entry, isPreview: true)
        } else {
            let displayText = entry.type == .audio && entry.text.isEmpty
                ? (entry.transcript ?? "")
                : entry.text
            if !displayText.isEmpty {
                Text(displayText)
                    .font(isInkwell && (entry.type == .text || entry.type == .audio)
                          ? .system(.body, design: .serif)
                          : .body)
                    .italic(entry.type == .link || entry.type == .photo || entry.type == .location)
                    .lineLimit(4)
                    .foregroundStyle(
                        isInkwell
                            ? (entry.type == .text || entry.type == .audio
                               ? InkwellTheme.inkPrimary
                               : InkwellTheme.inkSecondary)
                            : (entry.type == .text || entry.type == .audio
                               ? Color.primary
                               : Color.secondary)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    var tagsRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(alignment: .center) {
                if entry.isFavorited {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(isInkwell ? InkwellTheme.amber : .yellow)
                }
                if !entry.tags.isEmpty {
                    HStack(spacing: 4) {
                                            ForEach(entry.tags.prefix(3), id: \.self) { tag in
                                                Text(tag)
                                                    .font(.caption)
                                                    .italic(isInkwell)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(entryAccentColor.opacity(isInkwell ? 0.15 : 0.12))
                                                    .foregroundStyle(entryAccentColor.opacity(isInkwell ? 0.9 : 0.5))
                                                    .clipShape(Capsule())
                                                    .overlay(
                                                        isInkwell
                                                        ? Capsule().strokeBorder(entryAccentColor.opacity(0.3), lineWidth: 0.5)
                                                        : nil
                                                    )
                                            }
                                            if entry.tags.count > 3 {
                                                Text("+\(entry.tags.count - 3)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                }
                Spacer()
            }
            metadataColumn
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            typeLabel
            cardContent
            Divider()
                .overlay(isInkwell ? InkwellTheme.cardBorderTop : Color(uiColor: .separator))
                .opacity(isInkwell ? 0.6 : 1)
            tagsRow
        }
        .padding(12)
        .background(entryColor)
        .clipShape(RoundedRectangle(cornerRadius: isInkwell ? 14 : 12))
        .overlay(
            isInkwell
            ? RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [InkwellTheme.cardBorderTop, InkwellTheme.cardBorderColor(for: entry.type)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
            : nil
        )
        .shadow(color: isInkwell ? Color.black.opacity(0.4) : Color.clear, radius: 6, x: 0, y: 3)
    }
}
