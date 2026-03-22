import SwiftUI
import SwiftData

// MARK: - CollectionFormView
// Unified form for creating and editing collections.
// Pass nil for collection to create a new one.
// Pass an existing collection to edit it.
// Screen: Collections tab → + button (new) or swipe Edit (existing)

struct CollectionFormView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Query var entries: [Entry]
    @Query var collections: [Collection]

    // If nil, we're creating. If set, we're editing.
    var collection: Collection? = nil

    // Form state
    @State private var name = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColorHex = "#007AFF"
    @State private var selectedTypes: Set<String> = []
    @State private var selectedTags: Set<String> = []
    @State private var selectedDateRange: DateFilterRange = .allTime
    @State private var filterLocationName: String? = nil
    @State private var filterLocationLatitude: Double? = nil
    @State private var filterLocationLongitude: Double? = nil
    @State private var filterLocationRadius: Double? = nil
    @State private var filterSearchText = ""
    @State private var newTagFilter = ""
    @State private var locationFilterEnabled = false
    @State private var favoritesOnly = false

    var isEditing: Bool { collection != nil }
    var canSave: Bool { !name.isEmpty }

    var allTags: [String] {
        Array(Set(entries.flatMap { $0.tagNames })).sorted()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Collection name", text: $name)
                }

                Section("Color") {
                    colorPickerGrid
                }

                Section("Icon") {
                    IconPickerView(selectedIcon: $selectedIcon, accentColor: Color(hex: selectedColorHex))
                }

                Section("Filter by Type") {
                    ForEach(EntryType.allCases, id: \.self) { type in
                        HStack {
                            Label(type.rawValue.capitalized, systemImage: type.icon)
                            Spacer()
                            if selectedTypes.contains(type.rawValue) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color(hex: selectedColorHex))
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

                Section("Filter by Tag") {
                    ForEach(Array(selectedTags).sorted(), id: \.self) { tag in
                        HStack {
                            Text(tag)
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color(hex: selectedColorHex))
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
                            Button { addTagFilter() } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color(hex: selectedColorHex))
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
                                            .background(Color(hex: selectedColorHex).opacity(0.15))
                                            .foregroundStyle(Color(hex: selectedColorHex))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
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

                Section("Filter by Text") {
                    TextField("e.g. .bsky, recipe, @username", text: $filterSearchText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !filterSearchText.isEmpty {
                        Text("Entries containing \"\(filterSearchText)\" in any text field will match")
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
                    .pickerStyle(.navigationLink)
                }
            }
            .navigationTitle(isEditing ? "Edit Collection" : "New Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isEditing {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Done" : "Save") {
                        isEditing ? saveEdits() : saveNew()
                        dismiss()
                    }
                    .bold()
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if let collection {
                    // Populate state from existing collection
                    name = collection.name
                    selectedIcon = collection.icon
                    selectedColorHex = collection.colorHex
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
                }
            }
        }
    }

    // MARK: - Color Picker

    var colorPickerGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 10), spacing: 10) {
            ForEach(CuratedColors.all, id: \.hex) { color in
                Circle()
                    .fill(Color(hex: color.hex))
                    .frame(width: 28, height: 28)
                    .overlay {
                        if selectedColorHex == color.hex {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .onTapGesture { selectedColorHex = color.hex }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    func addTagFilter() {
        let trimmed = newTagFilter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return }
        selectedTags.insert(trimmed)
        newTagFilter = ""
    }

    func saveNew() {
        let c = Collection(
            name: name,
            icon: selectedIcon,
            colorHex: selectedColorHex,
            order: collections.count
        )
        c.filterTypes = Array(selectedTypes)
        c.filterTags = Array(selectedTags)
        c.filterDateRange = selectedDateRange.rawValue
        c.filterLocationName = filterLocationName
        c.filterLocationLatitude = filterLocationLatitude
        c.filterLocationLongitude = filterLocationLongitude
        c.filterLocationRadius = filterLocationRadius
        c.filterSearchText = favoritesOnly ? "__favorites__" : (filterSearchText.isEmpty ? nil : filterSearchText)
        modelContext.insert(c)
    }

    func saveEdits() {
        guard let collection else { return }
        collection.name = name
        collection.icon = selectedIcon
        collection.colorHex = selectedColorHex
        collection.filterTypes = Array(selectedTypes)
        collection.filterTags = Array(selectedTags)
        collection.filterDateRange = selectedDateRange.rawValue
        collection.filterLocationName = filterLocationName
        collection.filterLocationLatitude = filterLocationLatitude
        collection.filterLocationLongitude = filterLocationLongitude
        collection.filterLocationRadius = filterLocationRadius
        collection.filterSearchText = favoritesOnly ? "__favorites__" : (filterSearchText.isEmpty ? nil : filterSearchText)
    }
}
