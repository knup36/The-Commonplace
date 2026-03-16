import SwiftUI
import SwiftData

struct EditCollectionView: View {
    @Environment(\.dismiss) var dismiss
    @Query var entries: [Entry]
    @Bindable var collection: Collection

    @State private var selectedTypes: Set<String> = []
    @State private var selectedTags: Set<String> = []
    @State private var selectedDateRange: DateFilterRange = .allTime
    @State private var filterLocationName: String? = nil
    @State private var filterLocationLatitude: Double? = nil
    @State private var filterLocationLongitude: Double? = nil
    @State private var filterLocationRadius: Double? = nil
    @State private var filterSearchText = ""
    @State private var selectedIcon = "folder.fill"
    @State private var locationFilterEnabled: Bool = false
    @State private var newTagFilter = ""
    @State private var favoritesOnly: Bool = false

    var allTags: [String] {
        Array(Set(entries.flatMap { $0.tags })).sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Collection name", text: $collection.name)
                }

                Section("Color") {
                    colorPicker
                }

                Section("Icon") {
                    iconGrid
                }

                Section("Filter by Type") {
                    typePicker
                }

                Section("Filter by Tag") {
                    tagSection
                }

                Section("Filter by Location") {
                    LocationRadiusPickerView(
                        locationName: $filterLocationName,
                        latitude: $filterLocationLatitude,
                        longitude: $filterLocationLongitude,
                        radiusMiles: $filterLocationRadius,
                        isExpandedExternal: $locationFilterEnabled
                    )
                }

                Section("Filter by Favorites") {
                                    Toggle(isOn: $favoritesOnly) {
                                        Label("Favorites Only", systemImage: "star.fill")
                                            .foregroundStyle(.yellow)
                                    }
                                }

                                Section("Filter by Text") {                    TextField("e.g. recipe, @username", text: $filterSearchText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !filterSearchText.isEmpty {
                        Text("Entries containing \"\(filterSearchText)\" will match")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Filter by Date") {
                    Picker("Date Range", selection: $selectedDateRange) {
                        Text("All Time").tag(DateFilterRange.allTime)
                        Text("Today").tag(DateFilterRange.today)
                        Text("Last 7 Days").tag(DateFilterRange.last7Days)
                        Text("Last 30 Days").tag(DateFilterRange.last30Days)
                        Text("Last 90 Days").tag(DateFilterRange.last90Days)
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Edit Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveEdits()
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                            selectedTypes = Set(collection.filterTypes)
                            selectedTags = Set(collection.filterTags)
                            selectedDateRange = DateFilterRange(rawValue: collection.filterDateRange) ?? .allTime
                            filterLocationName = collection.filterLocationName
                            filterLocationLatitude = collection.filterLocationLatitude
                            filterLocationLongitude = collection.filterLocationLongitude
                            filterLocationRadius = collection.filterLocationRadius
                            locationFilterEnabled = collection.filterLocationLatitude != nil
                favoritesOnly = collection.filterSearchText == "__favorites__"
                filterSearchText = collection.filterSearchText == "__favorites__" ? "" : (collection.filterSearchText ?? "")
                                            selectedIcon = collection.icon

                        }
        }
    }

    // MARK: - Subviews

    var colorPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 10), spacing: 10) {
            ForEach(CuratedColors.all, id: \.hex) { color in
                Circle()
                    .fill(Color(hex: color.hex))
                    .frame(width: 28, height: 28)
                    .overlay {
                        if collection.colorHex == color.hex {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .onTapGesture { collection.colorHex = color.hex }
            }
        }
        .padding(.vertical, 4)
    }

    var iconGrid: some View {
            IconPickerView(selectedIcon: $selectedIcon, accentColor: Color(hex: collection.colorHex))
        }

    var typePicker: some View {
        ForEach(EntryType.allCases, id: \.self) { type in
            HStack {
                Label(type.rawValue.capitalized, systemImage: iconForType(type))
                Spacer()
                if selectedTypes.contains(type.rawValue) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color(hex: collection.colorHex))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if selectedTypes.contains(type.rawValue) {
                    selectedTypes.remove(type.rawValue)
                } else {
                    selectedTypes.insert(type.rawValue)
                }
            }
        }
    }

    var tagSection: some View {
        Group {
            ForEach(Array(selectedTags), id: \.self) { tag in
                HStack {
                    Text(tag)
                    Spacer()
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color(hex: collection.colorHex))
                    Button {
                        selectedTags.remove(tag)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("Add tag filter...", text: $newTagFilter)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { addTagFilter() }
                if !newTagFilter.isEmpty {
                    Button {
                        addTagFilter()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color(hex: collection.colorHex))
                    }
                    .buttonStyle(.plain)
                }
            }

            let suggestions = allTags.filter {
                !selectedTags.contains($0) &&
                (newTagFilter.isEmpty || $0.localizedCaseInsensitiveContains(newTagFilter))
            }
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { tag in
                            Button {
                                selectedTags.insert(tag)
                            } label: {
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(hex: collection.colorHex).opacity(0.15))
                                    .foregroundStyle(Color(hex: collection.colorHex))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    func addTagFilter() {
        let trimmed = newTagFilter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return }
        selectedTags.insert(trimmed)
        newTagFilter = ""
    }

    func saveEdits() {
        collection.filterTypes = Array(selectedTypes)
        collection.filterTags = Array(selectedTags)
        collection.filterDateRange = selectedDateRange.rawValue
        collection.filterLocationName = filterLocationName
        collection.filterLocationLatitude = filterLocationLatitude
        collection.filterLocationLongitude = filterLocationLongitude
        collection.filterLocationRadius = filterLocationRadius
        collection.filterSearchText = favoritesOnly ? "__favorites__" : (filterSearchText.isEmpty ? nil : filterSearchText)
                collection.icon = selectedIcon
    }

    func iconForType(_ type: EntryType) -> String {
        switch type {
        case .text:     return "text.alignleft"
        case .photo:    return "photo"
        case .audio:    return "waveform"
        case .link:     return "link"
        case .journal:  return "bookmark.fill"
        case .location: return "mappin.circle.fill"
        case .sticky:   return "checklist"
        case .music:    return "Music.note"
        }
    }
}
