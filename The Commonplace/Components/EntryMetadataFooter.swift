import SwiftUI
import MapKit

// MARK: - EntryMetadataFooter
// Reusable metadata footer shown at the bottom of all entry detail views.
// Displays created date, time, capture location, and entry type badge.
// Used by EntryDetailView, LocationDetailView, and StickyDetailView.

struct EntryMetadataFooter: View {
    let entry: Entry
    var style: any AppThemeStyle
    var accentColor: Color

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.createdAt.formatted(date: .long, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(style.secondaryText)
                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(style.secondaryText)
                if let lat = entry.captureLatitude, let lon = entry.captureLongitude {
                    Button {
                        openInMaps(lat: lat, lon: lon, name: entry.captureLocationName)
                    } label: {
                        Label(
                            entry.captureLocationName ?? "\(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))",
                            systemImage: "location.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(style.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 20, height: 20)
                        Image(systemName: entry.type.icon)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(style.background)
                    }
                    Text(entry.type.displayName)
                        .font(.caption)
                        .foregroundStyle(accentColor)
                }
                .padding(.leading, -5)
                .padding(.top, 3)
            }
            Spacer()
        }
    }

    func openInMaps(lat: Double, lon: Double, name: String?) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = name ?? "Entry Location"
        mapItem.openInMaps()
    }
}
