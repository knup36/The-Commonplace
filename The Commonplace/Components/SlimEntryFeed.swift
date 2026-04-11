// SlimEntryFeed.swift
// Commonplace
//
// Reusable compact entry list — discrete cards matching the regular feed aesthetic.
// Each entry is a standalone card with thumbnail, title, subtitle, and date.
// Fonts and typescale match EntryRowView for visual consistency.
//
// Thumbnail per type:
//   .location — live map snapshot
//   .media    — cover art
//   .link     — preview image or favicon
//   .music    — album artwork
//   .audio    — waveform visualization
//   others    — no thumbnail
//
// Usage:
//   SlimEntryFeed(entries: slimEntries, style: style)
//
// Used in:
//   FolioDetailView — entries below stickies and photos

import SwiftUI
import MapKit
import CoreLocation

struct SlimEntryFeed: View {
    let entries: [Entry]
    var style: any AppThemeStyle
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 8) {
            ForEach(entries) { entry in
                NavigationLink(destination: NavigationRouter.destination(for: entry)) {
                    slimRow(entry: entry)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Row

    func slimRow(entry: Entry) -> some View {
        let accent = entry.type.detailAccentColor(for: themeManager.current)
        let cardColor = entry.type.cardColor(for: themeManager.current)
        return HStack(spacing: 10) {

            // Thumbnail
            if hasThumbnail(entry: entry) {
                slimThumbnail(entry: entry)
                    .padding(.leading, 10)
            }

            // Text content
            VStack(alignment: .leading, spacing: 3) {
                if entry.type == .link, let title = entry.linkTitle, !title.isEmpty {
                    Text(title)
                        .font(style.typeTitle3)
                        .fontWeight(.semibold)
                        .foregroundStyle(style.cardPrimaryText)
                        .lineLimit(3)
                        .lineSpacing(4)
                } else {
                    Text(slimTitle(for: entry))
                        .font(style.typeTitle3)
                        .fontWeight(.semibold)
                        .foregroundStyle(style.cardPrimaryText)
                        .lineLimit(3)
                    let subtitle = slimSubtitle(for: entry)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(style.typeBody)
                            .foregroundStyle(style.cardSecondaryText)
                            .lineLimit(2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                .font(style.typeCaption)
                .foregroundStyle(accent)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style.cardBorder, lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Thumbnail

    func hasThumbnail(entry: Entry) -> Bool {
        switch entry.type {
        case .location, .media, .link, .music, .audio: return true
        default: return false
        }
    }

    @ViewBuilder
    func slimThumbnail(entry: Entry) -> some View {
        let accent = entry.type.detailAccentColor(for: themeManager.current)
        let size: CGFloat = 48

        switch entry.type {
        case .location:
            if let lat = entry.captureLatitude, let lon = entry.captureLongitude {
                SlimMapThumbnail(latitude: lat, longitude: lon, size: size)
            } else {
                slimIconThumb(icon: entry.type.icon, accent: accent, size: size)
            }
        case .media:
            if let path = entry.mediaCoverPath,
               let data = MediaFileManager.load(path: path),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                slimIconThumb(icon: entry.type.icon, accent: accent, size: size)
            }
        case .link:
            if let path = entry.previewImagePath,
               let data = MediaFileManager.load(path: path),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let faviconPath = entry.faviconPath,
                      let data = MediaFileManager.load(path: faviconPath),
                      let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                slimIconThumb(icon: entry.type.icon, accent: accent, size: size)
            }
        case .music:
            if let path = entry.musicArtworkPath,
               let data = MediaFileManager.load(path: path),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                slimIconThumb(icon: entry.type.icon, accent: accent, size: size)
            }
        case .audio:
            SlimWaveformThumbnail(entry: entry, accent: accent, size: size)
        default:
            EmptyView()
        }
    }

    func slimIconThumb(icon: String, accent: Color, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(accent.opacity(0.15))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(accent)
            )
    }

    // MARK: - Subtitle

    func slimSubtitle(for entry: Entry) -> String {
        switch entry.type {
        case .text:
            let parts = entry.text.components(separatedBy: "\n")
            return parts.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        case .link:
            return entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            return ""
        }
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

// MARK: - Slim Map Thumbnail

struct SlimMapThumbnail: View {
    let latitude: Double
    let longitude: Double
    let size: CGFloat
    @State private var region: MKCoordinateRegion

    init(latitude: Double, longitude: Double, size: CGFloat) {
        self.latitude = latitude
        self.longitude = longitude
        self.size = size
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    var body: some View {
        Map(position: .constant(.region(region))) {
            Marker("", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                .tint(.red)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .disabled(true)
        .allowsHitTesting(false)
    }
}

// MARK: - Slim Waveform Thumbnail

struct SlimWaveformThumbnail: View {
    let entry: Entry
    let accent: Color
    let size: CGFloat

    private let barCount = 12

    var barHeights: [CGFloat] {
        var result: [CGFloat] = []
        var hash = abs(entry.id.uuidString.hashValue)
        for _ in 0..<barCount {
            hash = hash &* 1664525 &+ 1013904223
            let normalized = CGFloat(abs(hash) % 100) / 100.0
            let position = CGFloat(result.count) / CGFloat(barCount)
            let envelope = sin(position * .pi)
            result.append(4 + 20 * normalized * (0.4 + envelope * 0.6))
        }
        return result
    }

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(accent.opacity(0.8))
                    .frame(width: 2, height: barHeights[i])
            }
        }
        .frame(width: size, height: size)
    }
}
