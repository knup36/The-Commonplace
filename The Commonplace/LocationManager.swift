import Foundation
import CoreLocation
import Combine

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var currentPlaceName: String?
    
    private let manager = CLLocationManager()
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            self.currentLocation = location
            await self.reverseGeocode(location: location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    private func reverseGeocode(location: CLLocation) async {
        let geocoder = CLGeocoder()
        if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
           let placemark = placemarks.first {
            var parts: [String] = []
            
            // Most granular: subLocality (neighborhood) > areasOfInterest > thoroughfare (street)
            if let subLocality = placemark.subLocality {
                parts.append(subLocality)
            } else if let area = placemark.areasOfInterest?.first {
                parts.append(area)
            } else if let street = placemark.thoroughfare {
                parts.append(street)
            }
            
            // City
            if let city = placemark.locality {
                parts.append(city)
            }
            
            // State
            if let state = placemark.administrativeArea {
                parts.append(state)
            }
            
            currentPlaceName = parts.isEmpty ? placemark.name : parts.joined(separator: ", ")
        }
    }
}
