import SwiftUI
import MapKit

struct LocationDetailView: View {
    @Bindable var entry: Entry
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    @State private var editText = ""
    @State private var isEditing = false
    @FocusState private var textFieldFocused: Bool

    var isInkwell: Bool { themeManager.current == .inkwell }
    var accentColor: Color { isInkwell ? InkwellTheme.collectionAccentColor(for: "#30D158") : .green }
    var bgColor: Color { isInkwell ? InkwellTheme.locationCard : Color.green.opacity(0.15) }
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
                                    .font(isInkwell ? .system(.title2, design: .serif) : .title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(isInkwell ? InkwellTheme.inkPrimary : .primary)
                            }
                            if let address = entry.locationAddress {
                                Text(address)
                                    .font(.subheadline)
                                    .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
                            }
                            if let category = entry.locationCategory {
                                Text(category)
                                    .font(.caption)
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
                        .overlay(isInkwell ? InkwellTheme.surface : Color.clear)

                    // Note
                    if isEditing {
                        TextField("Add a note...", text: $editText, axis: .vertical)
                            .font(isInkwell ? .system(.body, design: .serif) : .body)
                            .foregroundStyle(isInkwell ? InkwellTheme.inkPrimary : .primary)
                            .focused($textFieldFocused)
                    } else {
                        Text(entry.text.isEmpty ? "Tap to add a note..." : entry.text)
                            .font(isInkwell ? .system(.body, design: .serif) : .body)
                            .italic(entry.text.isEmpty ? false : true)
                            .foregroundStyle(entry.text.isEmpty
                                ? (isInkwell ? InkwellTheme.inkTertiary : Color(uiColor: .tertiaryLabel))
                                : (isInkwell ? InkwellTheme.inkSecondary : .secondary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editText = entry.text
                                isEditing = true
                                textFieldFocused = true
                            }
                    }

                    TagInputView(tags: $entry.tags, accentColor: accentColor)

                    Divider()
                        .overlay(isInkwell ? InkwellTheme.surface : Color.clear)

                    // Metadata footer
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.createdAt.formatted(date: .long, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
                            Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
                            if let lat = entry.captureLatitude, let lon = entry.captureLongitude {
                                Button {
                                    openInMaps(lat: lat, lon: lon, name: entry.captureLocationName)
                                } label: {
                                    Label(entry.captureLocationName ?? "\(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))", systemImage: "location.fill")
                                        .font(.caption)
                                        .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            HStack(spacing: 6) {
                                ZStack {
                                    Circle().fill(accentColor).frame(width: 20, height: 20)
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(isInkwell ? InkwellTheme.background : .white)
                                }
                                Text("Location")
                                    .font(.caption)
                                    .foregroundStyle(accentColor)
                            }
                        }
                        Spacer()
                    }
                }
                .padding()
            }
        }
        .background(bgColor.ignoresSafeArea())
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
                    .foregroundStyle(isInkwell ? InkwellTheme.amber : .primary)
                }
            }
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

    func openInMaps(lat: Double, lon: Double, name: String?) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = name ?? "Entry Location"
        mapItem.openInMaps()
    }
}
