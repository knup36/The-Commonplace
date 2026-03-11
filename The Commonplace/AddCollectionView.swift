import SwiftUI
import SwiftData

struct AddCollectionView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Query var entries: [Entry]
    @Query var collections: [Collection]
    
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
    @State private var newTagFilter: String = ""
    @State private var locationFilterEnabled: Bool = false
    @State private var favoritesOnly: Bool = false
    
    var allTags: [String] {
        Array(Set(entries.flatMap { $0.tags })).sorted()
    }
    
    var canSave: Bool { !name.isEmpty }
    
    var iconGrid: some View {
            IconPickerView(selectedIcon: $selectedIcon, accentColor: Color(hex: selectedColorHex))
        }
    
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
                    iconGrid
                }
                
                Section("Filter by Type") {
                    ForEach(EntryType.allCases, id: \.self) { type in
                        HStack {
                            Label(type.rawValue.capitalized, systemImage: iconForType(type))
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
                    // Selected tags
                    ForEach(Array(selectedTags), id: \.self) { tag in
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
                    
                    // Type a new tag
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
                                    .foregroundStyle(Color(hex: selectedColorHex))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Existing tags as suggestions
                    if !allTags.isEmpty {
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
            .navigationTitle("New Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveCollection() }
                        .bold()
                        .disabled(!canSave)
                }
            }
        }
    }
    
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
    
    func addTagFilter() {
        let trimmed = newTagFilter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return }
        selectedTags.insert(trimmed)
        newTagFilter = ""
    }
    
    func saveCollection() {
        let collection = Collection(name: name, icon: selectedIcon, colorHex: selectedColorHex, order: collections.count)
        collection.filterTypes = Array(selectedTypes)
        collection.filterTags = Array(selectedTags)
        collection.filterDateRange = selectedDateRange.rawValue
        collection.filterLocationName = filterLocationName
        collection.filterLocationLatitude = filterLocationLatitude
        collection.filterLocationLongitude = filterLocationLongitude
        collection.filterLocationRadius = filterLocationRadius
        collection.filterSearchText = favoritesOnly ? "__favorites__" : (filterSearchText.isEmpty ? nil : filterSearchText)
                        modelContext.insert(collection)
        dismiss()
    }
    
    func iconForType(_ type: EntryType) -> String {
        switch type {
        case .text:  return "text.alignleft"
        case .photo: return "photo"
        case .audio: return "waveform"
        case .link:  return "link"
        case .journal:  return "bookmark.fill"
        case .location: return "mappin.circle.fill"
        case .sticky:   return "checklist"
        }
    }
}
