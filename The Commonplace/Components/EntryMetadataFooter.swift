import SwiftUI
import MapKit

// MARK: - EntryMetadataFooter
// Reusable metadata footer shown at the bottom of all entry detail views.
// Two column layout: location + type badge on left, date + time on right.
// Used by EntryDetailView, LocationDetailView, and StickyDetailView.

struct EntryMetadataFooter: View {
    let entry: Entry
    var style: any AppThemeStyle
    var accentColor: Color
    
    var body: some View {
        HStack(alignment: .top) {
            // Left column — location
            if let lat = entry.captureLatitude, let lon = entry.captureLongitude {
                Button {
                    openInMaps(lat: lat, lon: lon, name: entry.captureLocationName)
                } label: {
                    Label(
                        entry.captureLocationName ?? "\(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))",
                        systemImage: "location.fill"
                    )
                    .font(style.typeLabel)
                    .foregroundStyle(style.cardMetadataText)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Right column — date + time
            VStack(alignment: .trailing, spacing: 4) {
                Text(entry.createdAt.formatted(date: .long, time: .omitted))
                    .font(style.typeLabel)
                    .foregroundStyle(style.cardMetadataText)
                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(style.typeLabel)
                    .foregroundStyle(style.cardMetadataText)
            }
        }
    }
    
    func openInMaps(lat: Double, lon: Double, name: String?) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = name ?? "Entry Location"
        mapItem.openInMaps()
    }
}
