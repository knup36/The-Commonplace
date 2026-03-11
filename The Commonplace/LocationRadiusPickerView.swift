import SwiftUI
import MapKit
import CoreLocation
import Combine

struct LocationRadiusPickerView: View {
    @Binding var locationName: String?
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var radiusMiles: Double?
    @Binding var isExpandedExternal: Bool

    @StateObject private var completer = RadiusLocationCompleter()
    @StateObject private var currentLocationManager = CurrentLocationFetcher()
    @State private var searchText = ""
    @State private var localRadius: Double = 5
    @State private var isResolvingLocation = false

    var isSet: Bool { latitude != nil && longitude != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle(isOn: $isExpandedExternal) {
                    Label("Filter by Location", systemImage: "location.circle.fill")
                        .font(.subheadline)
                }
                .onChange(of: isExpandedExternal) { _, enabled in
                    if !enabled {
                        clearAll()
                    }
                }
            }

            if isExpandedExternal {
                VStack(alignment: .leading, spacing: 10) {
                    if isSet {
                        // Selected location card
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(locationName ?? "Selected Location")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Within \(Int(localRadius)) mile\(localRadius == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                clearAll()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        // Radius slider 1–50 miles
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Radius: \(Int(localRadius)) mile\(localRadius == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Slider(value: $localRadius, in: 1...50, step: 1)
                                .tint(.green)
                                .onChange(of: localRadius) { _, newValue in
                                    radiusMiles = newValue
                                }
                        }

                    } else {
                        // Use current location button
                        Button {
                            useCurrentLocation()
                        } label: {
                            HStack(spacing: 8) {
                                if isResolvingLocation {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "location.fill")
                                        .foregroundStyle(.green)
                                }
                                Text(isResolvingLocation ? "Getting location..." : "Use Current Location")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)

                        // Search bar
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search for a place...", text: $searchText)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onChange(of: searchText) { _, newValue in
                                    completer.search(query: newValue)
                                }
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                    completer.results = []
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color(uiColor: .systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        // Search results
                        if !completer.results.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(completer.results, id: \.self) { result in
                                    Button {
                                        resolveResult(result)
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundStyle(.green)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(result.title)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.primary)
                                                if !result.subtitle.isEmpty {
                                                    Text(result.subtitle)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 4)
                                    }
                                    .buttonStyle(.plain)
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .onAppear {
                    localRadius = radiusMiles ?? 5
                }
            }
        }
    }

    func resolveResult(_ result: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: result)
        Task {
            if let response = try? await MKLocalSearch(request: request).start(),
               let item = response.mapItems.first {
                await MainActor.run {
                    locationName = item.name ?? result.title
                    latitude = item.placemark.coordinate.latitude
                    longitude = item.placemark.coordinate.longitude
                    radiusMiles = localRadius
                    searchText = ""
                    completer.results = []
                }
            }
        }
    }

    func useCurrentLocation() {
        isResolvingLocation = true
        currentLocationManager.requestLocation { location, name in
            DispatchQueue.main.async {
                if let location {
                    latitude = location.coordinate.latitude
                    longitude = location.coordinate.longitude
                    locationName = name ?? "Current Location"
                    radiusMiles = localRadius
                }
                isResolvingLocation = false
            }
        }
    }

    func clearAll() {
        locationName = nil
        latitude = nil
        longitude = nil
        radiusMiles = nil
        searchText = ""
        completer.results = []
        isExpandedExternal = false
    }
}

// MARK: - Completer
class RadiusLocationCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    @Published var results: [MKLocalSearchCompletion] = []

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest, .query]
    }

    func search(query: String) {
        if query.isEmpty {
            results = []
            completer.cancel()
        } else {
            completer.queryFragment = query
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = Array(completer.results.prefix(8))
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}

// MARK: - Current Location Fetcher
class CurrentLocationFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var completion: ((CLLocation?, String?) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation(completion: @escaping (CLLocation?, String?) -> Void) {
        self.completion = completion
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            let name = placemarks?.first?.locality ?? placemarks?.first?.name
            self.completion?(location, name)
            self.completion = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completion?(nil, nil)
        completion = nil
    }
}
