import SwiftUI
import MapKit
import Contacts
import Combine

struct LocationSearchView: View {
    @Binding var selectedName: String?
    @Binding var selectedAddress: String?
    @Binding var selectedLatitude: Double?
    @Binding var selectedLongitude: Double?
    @Binding var selectedCategory: String?
    
    @StateObject private var completer = LocationCompleter()
    @State private var searchText = ""
    @State private var isResolving = false
    @FocusState private var searchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.green)
                TextField("Search places...", text: $searchText)
                    .autocorrectionDisabled()
                    .focused($searchFocused)
                    .tint(.green)
                    .onChange(of: searchText) { _, newValue in
                        completer.search(query: newValue)
                    }
                if isResolving {
                    ProgressView().tint(.green)
                } else if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        completer.results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.green.opacity(0.6))
                    }
                }
            }
            .padding(10)
            .background(Color(uiColor: .systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.green.opacity(0.4), lineWidth: 1.5)
            }
            .padding(.bottom, 8)
            
            // Selected location confirmation
            if let name = selectedName {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        if let address = selectedAddress {
                            Text(address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        clearSelection()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.bottom, 8)
            }
            
            // Results
            if !completer.results.isEmpty && selectedName == nil {
                VStack(spacing: 0) {
                    ForEach(completer.results, id: \.self) { result in
                        Button {
                            resolve(result)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                searchFocused = true
            }
        }
    }
    
    // Resolve a completion result to coordinates
    func resolve(_ result: MKLocalSearchCompletion) {
        isResolving = true
        let request = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: request)
        Task {
            if let response = try? await search.start(),
               let item = response.mapItems.first {
                await MainActor.run {
                    selectedName = item.name ?? result.title
                    selectedAddress = result.subtitle.isEmpty ? nil : result.subtitle
                    selectedLatitude = item.placemark.coordinate.latitude
                    selectedLongitude = item.placemark.coordinate.longitude
                    if let rawCategory = item.pointOfInterestCategory?.rawValue
                        .replacingOccurrences(of: "MKPOICategory", with: "") {
                        // Insert spaces before capital letters e.g. "FoodMarket" → "Food Market"
                        selectedCategory = rawCategory.unicodeScalars.reduce("") { result, scalar in
                            let char = Character(scalar)
                            if char.isUppercase && !result.isEmpty {
                                return result + " " + String(char)
                            }
                            return result + String(char)
                        }
                    } else {
                        selectedCategory = nil
                    }
                    searchText = ""
                    completer.results = []
                    isResolving = false
                }
            } else {
                await MainActor.run { isResolving = false }
            }
        }
    }
    
    func clearSelection() {
        selectedName = nil
        selectedAddress = nil
        selectedLatitude = nil
        selectedLongitude = nil
        selectedCategory = nil
    }
}

// MARK: - Location Completer
class LocationCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
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
