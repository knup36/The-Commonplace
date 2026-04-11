// ScrapbookPlaceCard.swift
// Commonplace
//
// Scrapbook feed card for .location entries.
// Renders as a postcard — real MapKit map filling the top portion,
// place name and address below on a cream strip.
// A pushpin through the top-left corner pins it to the page.
//
// Layout:
//   - Pushpin at top-left corner (overlaid, above card)
//   - Map view filling top 2/3, no rounded corners
//   - Cream strip at bottom with place name + address + date
//
// No rotation — postcards sit flat and deliberate on the page.
// Map uses same region/span as LocationDetailView.

import SwiftUI
import MapKit

struct ScrapbookPlaceCard: View {
    let entry: Entry

    private let cardWidth: CGFloat = 300
    private let mapHeight: CGFloat = 160
    private let chinHeight: CGFloat = 72

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = entry.captureLatitude,
              let lon = entry.captureLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Postcard body
            VStack(spacing: 0) {
                // Map
                if let coordinate {
                    Map(position: .constant(.region(MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )))) {
                        Marker(entry.locationName ?? "", coordinate: coordinate)
                            .tint(.red)
                    }
                    .frame(width: cardWidth, height: mapHeight)
                    .disabled(true)
                } else {
                    Rectangle()
                        .fill(ScrapbookTheme.inkDecorative.opacity(0.15))
                        .frame(width: cardWidth, height: mapHeight)
                        .overlay(
                            Image(systemName: "map")
                                .font(.system(size: 32))
                                .foregroundStyle(ScrapbookTheme.inkTertiary)
                        )
                }

                // Thin rule
                Rectangle()
                    .fill(ScrapbookTheme.inkDecorative.opacity(0.4))
                    .frame(height: 0.5)

                // Chin — place info
                VStack(alignment: .leading, spacing: 3) {
                    if let name = entry.locationName {
                        Text(name)
                            .font(ScrapbookTheme.bodyFont(size: 15))
                            .fontWeight(.semibold)
                            .foregroundStyle(ScrapbookTheme.inkPrimary)
                            .lineLimit(1)
                    }
                    if let address = entry.locationAddress {
                        Text(address)
                            .font(ScrapbookTheme.captionFont(size: 10))
                            .foregroundStyle(ScrapbookTheme.inkSecondary)
                            .lineLimit(1)
                    }
                    Text(entry.createdAt.formatted(.dateTime.month(.wide).day().year()))
                        .font(ScrapbookTheme.captionFont(size: 9))
                        .kerning(0.8)
                        .foregroundStyle(ScrapbookTheme.inkTertiary)
                }
                .frame(width: cardWidth, height: chinHeight, alignment: .leading)
                .padding(.horizontal, 14)
                .background(Color(red: 0.95, green: 0.93, blue: 0.87))
            }
            .frame(width: cardWidth)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .shadow(color: ScrapbookTheme.cardShadowColor, radius: ScrapbookTheme.cardShadowRadius, x: 0, y: ScrapbookTheme.cardShadowY)

            // Pushpin
            PushpinView()
                .offset(x: 16, y: -14)
        }
        .padding(.top, 20)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pushpin

struct PushpinView: View {
    var body: some View {
        ZStack {
            // Pin head — round circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.85, green: 0.2, blue: 0.15),
                            Color(red: 0.6, green: 0.1, blue: 0.08)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 1,
                        endRadius: 10
                    )
                )
                .frame(width: 18, height: 18)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 2)

            // Pin highlight
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 6, height: 6)
                .offset(x: -3, y: -3)

            // Pin shaft
            Rectangle()
                .fill(Color(white: 0.6))
                .frame(width: 2, height: 10)
                .offset(y: 12)
        }
        .frame(width: 18, height: 28)
    }
}
