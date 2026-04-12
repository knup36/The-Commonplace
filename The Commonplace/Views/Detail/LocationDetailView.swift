import SwiftUI
import MapKit
import SwiftData

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
    
    @StateObject private var editMode = EditModeManager()
        @State private var showingDeleteConfirmation = false
        @State private var editText = ""
        @FocusState private var textFieldFocused: Bool
    
    var style: any AppThemeStyle { themeManager.style }
    var accentColor: Color { entry.type.detailAccentColor(for: themeManager.current) }
    var bgColor: Color { entry.type.cardColor(for: themeManager.current) }
    
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
                    .frame(height: 196)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .onTapGesture { openInMaps() }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Place info
                    if entry.locationLatitude != nil {
                        VStack(alignment: .leading, spacing: 6) {
                            if let name = entry.locationName {
                                Text(name)
                                    .font(style.typeLargeTitle)
                                    .foregroundStyle(style.cardPrimaryText)
                            }
                            // Star rating + visited toggle
                            HStack {
                                HStack(spacing: 4) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: (entry.locationRating ?? 0) >= star ? "star.fill" : "star")
                                            .font(.system(size: 16))
                                            .foregroundStyle((entry.locationRating ?? 0) >= star ? .yellow : style.cardMetadataText)
                                            .onTapGesture {
                                                entry.locationRating = (entry.locationRating == star) ? nil : star
                                                entry.touch()
                                            }
                                    }
                                }
                                .transaction { $0.animation = nil }
                                Spacer()
                                Button {
                                    withAnimation(.spring(duration: 0.2)) {
                                        entry.locationVisited.toggle()
                                        entry.touch()
                                    }
                                } label: {
                                    Image(systemName: entry.locationVisited ? "checkmark.seal.fill" : "checkmark.seal")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(entry.locationVisited ? .green : style.cardMetadataText)
                                }
                                .buttonStyle(.plain)
                            }
                            if let address = entry.locationAddress {
                                Text(address)
                                    .font(style.typeBodySecondary)
                                    .foregroundStyle(style.cardSecondaryText)
                            }
                            if let category = entry.locationCategory {
                                Text(category)
                                    .font(style.typeCaption)
                                    .foregroundStyle(accentColor)
                            }
                        }
                        
                        HStack {
                            Button { openInMaps() } label: {
                                Label("Maps", systemImage: "map.fill")
                                    .font(style.typeLabel)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(accentColor)
                            Spacer()
                        }
                    }
                    
                    Divider()
                        .overlay(style.surface)
                    
                    // Note
                                        if editMode.isEditing {
                                            TextField("Add a note...", text: $editText, axis: .vertical)
                                                .font(style.typeBody)
                                                .foregroundStyle(style.cardPrimaryText)
                                                .focused($textFieldFocused)
                                        } else {
                                            Text(entry.text.isEmpty ? "Tap to add a note..." : entry.text)
                                                .font(style.typeBody)
                                                .italic(entry.text.isEmpty ? false : true)
                                                .foregroundStyle(entry.text.isEmpty ? style.cardMetadataText : style.cardSecondaryText)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    editText = entry.text
                                                    editMode.enter()
                                                    textFieldFocused = true
                                                }
                                        }
                    
                    TagInputView(tags: $entry.tagNames, accentColor: accentColor, style: style)
                    PersonInputView(tags: $entry.tagNames, accentColor: accentColor, style: style)
                    
                    Divider()
                        .overlay(style.cardDivider)
                    EntryMetadataFooter(entry: entry, style: style, accentColor: accentColor)
                }
                .padding()
            }
        }
        .environmentObject(editMode)
                .background(bgColor.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 50)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            if editMode.isEditing {
                                Button("Done") {
                                    entry.text = editText
                                    textFieldFocused = false
                                    entry.touch()
                                    editMode.exit()
                                }
                                .bold()
                                .foregroundStyle(accentColor)
                            } else {
                                Button {
                                    editMode.enter()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        editText = entry.text
                                        textFieldFocused = true
                                    }
                                } label: {
                                    Image(systemName: "rectangle.and.pencil.and.ellipsis")
                                        .foregroundStyle(accentColor)
                                        .offset(y: -2)
                                }
                                Menu {
                                    Button {
                                        withAnimation { entry.isPinned.toggle() }
                                    } label: {
                                        Label(entry.isPinned ? "Remove Bookmark" : "Bookmark",
                                              systemImage: entry.isPinned ? "bookmark.fill" : "bookmark")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundStyle(accentColor)
                                }
                            }
                        }
                    }
                }
        .onDisappear {
            SearchIndex.shared.index(entry: entry)
        }
        .confirmationDialog("Delete this entry?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(entry)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
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
