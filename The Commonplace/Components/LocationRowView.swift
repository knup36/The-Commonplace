import SwiftUI
import MapKit

struct LocationRowView: View {
    let entry: Entry
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = entry.locationLatitude,
              let lon = entry.locationLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            
            // Map thumbnail
            if let coordinate {
                Map(position: .constant(.region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )))) {
                    Marker("", coordinate: coordinate)
                        .tint(.green)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(true)
                .allowsHitTesting(false)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.green)
                    }
            }
            
            // Name + address
            VStack(alignment: .leading, spacing: 4) {
                if let name = entry.locationName {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let address = entry.locationAddress {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let category = entry.locationCategory {
                    Text(category)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            
            Spacer()
        }
        .padding(10)
        .background(Color(uiColor: .systemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
