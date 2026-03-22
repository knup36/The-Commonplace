import SwiftUI
import MapKit

// MARK: - LocationDetailView
// Detail view for location entries.
// Shows a map, place info, Open in Maps button, note editor, and tags.
// If no location is set yet, shows LocationSearchView to pick one.
// Screen: Entry Detail (tap any location entry in the Feed or Collections tab)

struct LocationDetailView: View {
    @Bindable var entry: Entry
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    @State private var editText = ""
    @State private var isEditing = false
    @FocusState private var textFieldFocused: Bool

    var style: any AppThemeStyle { themeManager.style }
    var accentColor: Color { InkwellTheme.collectionAccentColor(for: "#30D158") }
    var bgColor: Color { InkwellTheme.locationCard }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = entry.locationLatitude,
              let lon = entry.locationLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Location picker — shown when no location set yet
                if entry.locationLatitude == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        LocationSearchView(
                            selectedName: Binding(get: { entry.locationName }, set: { entry.locationName = $0 }),
                            selectedAddress: Binding(get: { entry.locationAddress }, set: { entry.locationAddress = $0 }),
                            selectedLatitude: Binding(get: { entry.locationLatitude }, set: { entry.locationLatitude = $0 }),
                            selectedLongitude: Binding(get: { entry.locationLongitude }, set: { entry.locationLongitude = $0 }),
                            selectedCategory: Binding(get: { entry.locationCategory }, set: { entry.locationCategory = $0 })
                        )
                    }
                    .padding()
                }

                // Map
                if let coordinate {
                    Map(position: .constant(.region(MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )))) {
                        Marker(entry.locationName ?? "", coordinate: coordinate)
                            .tint(accentColor)
                    }
                    .frame(height: 280)
                    .onTapGesture { openInMaps() }
                }

                VStack(alignment: .leading, spacing: 16) {

                    // Place info
                    if entry.locationLatitude != nil {
                        VStack(alignment: .leading, spacing: 6) {
                            if let name = entry.locationName {
                                Text(name)
                                    .font(style.title)
                                    .fontWeight(.bold)
                                    .foregroundStyle(style.primaryText)
                            }
                            if let address = entry.locationAddress {
                                Text(address)
                                    .font(style.subheadline)
                                    .foregroundStyle(style.secondaryText)
                            }
                            if let category = entry.locationCategory {
                                Text(category)
                                    .font(style.caption)
                                    .foregroundStyle(accentColor)
                            }
                        }

                        Button { openInMaps() } label: {
                            Label("Open in Maps", systemImage: "map.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accentColor)
                    }

                    Divider()
                        .overlay(style.surface)

                    // Note
                    if isEditing {
                        TextField("Add a note...", text: $editText, axis: .vertical)
                            .font(style.body)
                            .foregroundStyle(style.primaryText)
                            .focused($textFieldFocused)
                    } else {
                        Text(entry.text.isEmpty ? "Tap to add a note..." : entry.text)
                            .font(style.body)
                            .italic(entry.text.isEmpty ? false : true)
                            .foregroundStyle(entry.text.isEmpty ? style.tertiaryText : style.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editText = entry.text
                                isEditing = true
                                textFieldFocused = true
                            }
                    }

                    TagInputView(tags: $entry.tagNames, accentColor: accentColor, style: style)

                    Divider()
                        .overlay(style.surface)
                    EntryMetadataFooter(entry: entry, style: style, accentColor: accentColor)
                }
                .padding()
            }
        }
        .background(bgColor.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 50)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Done") {
                        entry.text = editText
                        isEditing = false
                        textFieldFocused = false
                    }
                    .bold()
                    .foregroundStyle(style.accent)
                }
            }
        }
        .onDisappear {
            SearchIndex.shared.index(entry: entry)
        }
    }

    func openInMaps() {
        guard let coordinate else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = entry.locationName ?? ""
        request.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        Task {
            let search = MKLocalSearch(request: request)
            if let response = try? await search.start(),
               let match = response.mapItems.first {
                await MainActor.run {
                    match.openInMaps(launchOptions: [
                        MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinate),
                        MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                    ])
                }
            } else {
                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                mapItem.name = entry.locationName
                await MainActor.run { mapItem.openInMaps() }
            }
        }
    }
}
