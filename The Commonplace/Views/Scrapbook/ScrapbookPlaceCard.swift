// ScrapbookPlaceCard.swift
// Commonplace
//
// Scrapbook feed card for .location entries.
// Renders as a postcard — full bleed map with frosted glass info label
// overlaid at the bottom left. No chin, no pushpin.
//
// Layout:
//   - Map fills entire card edge to edge
//   - Frosted glass label bottom-left with place name, address, date
//
// No rotation — postcards sit flat and deliberate on the page.
// Map uses same region/span as LocationDetailView.

import SwiftUI
import MapKit

struct ScrapbookPlaceCard: View {
    let entry: Entry

    private let cardWidth: CGFloat = 340

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = entry.captureLatitude,
              let lon = entry.captureLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Map — full card
            if let coordinate {
                Map(position: .constant(.region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )))) {
                    Marker(entry.locationName ?? "", coordinate: coordinate)
                        .tint(.red)
                }
                .frame(width: cardWidth, height: cardWidth * 0.72)
                .disabled(true)
            } else {
                Rectangle()
                    .fill(ScrapbookTheme.inkDecorative.opacity(0.15))
                    .frame(width: cardWidth, height: cardWidth * 0.72)
                    .overlay(
                        Image(systemName: "map")
                            .font(.system(size: 32))
                            .foregroundStyle(ScrapbookTheme.inkTertiary)
                    )
            }

            // Frosted glass info label
            VStack(alignment: .leading, spacing: 2) {
                if let name = entry.locationName {
                    Text(name)
                        .font(ScrapbookTheme.bodyFont(size: 13))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                if let address = entry.locationAddress {
                    Text(address)
                        .font(ScrapbookTheme.captionFont(size: 9))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
                Text(entry.createdAt.formatted(.dateTime.month(.wide).day().year()))
                    .font(ScrapbookTheme.captionFont(size: 9))
                    .kerning(0.6)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(10)
        }
        .frame(width: cardWidth)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
    }
}
