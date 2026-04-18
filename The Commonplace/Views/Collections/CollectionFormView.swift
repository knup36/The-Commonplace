// CollectionFormView.swift
// Commonplace
//
// Unified form for creating and editing collections and folios.
// Pass nil for collection to create a new one.
// Pass an existing collection to edit it.
//
// Collection/Folio toggle:
//   - Top segmented picker: Collection | Folio
//   - Folio tab shows an informational screen until toggled on
//   - Once promoted to Folio, name field is locked (manualTag depends on it)
//   - Folio fields: emoji picker, header image, color
// On save, Folio fields (emoji, header image, color) are applied
//
// Screen: Library tab → + button (new) or swipe Edit (existing)

import SwiftUI
import SwiftData
import PhotosUI

struct CollectionFormView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Query var entries: [Entry]
    @Query var collections: [Collection]
    
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
    @State private var selectedMediaStatuses: Set<String> = []
    @State private var selectedLocationStatuses: Set<String> = []
    
    // Folio state
    @State private var selectedFormTab = 0  // 0 = Collection, 1 = Folio
    @State private var isFolio = false
    @State private var folioEmoji = ""
    @State private var showingEmojiPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var headerImage: UIImage? = nil
    @State private var headerImageData: Data? = nil
    
    var isEditing: Bool { collection != nil }
    var canSave: Bool { !name.isEmpty }
    var isNameLocked: Bool { isEditing && isFolio }
    
    var allTags: [String] {
        Array(Set(entries.flatMap { $0.tagNames })).sorted()
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Collection / Folio picker
                Picker("", selection: $selectedFormTab) {
                    Text("Collection").tag(0)
                    Text("Folio").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .disabled(name.isEmpty && selectedFormTab == 0)
                
                if selectedFormTab == 0 {
                    collectionForm
                } else {
                    if isFolio {
                        folioForm
                    } else {
                        folioInfoScreen
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit" : "New")
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
                    selectedMediaStatuses = Set(collection.filterMediaStatus)
                    selectedLocationStatuses = Set(collection.filterLocationStatus)
                    filterSearchText = collection.filterSearchText == "__favorites__" ? "" : (collection.filterSearchText ?? "")
                    isFolio = collection.isFolio
                    folioEmoji = collection.folioEmoji ?? ""
                    if isFolio { selectedFormTab = 1 }
                    loadHeaderImage()
                }
            }
            .photosPicker(isPresented: $showingEmojiPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    guard let newItem,
                          let rawData = try? await newItem.loadTransferable(type: Data.self),
                          let uiImage = UIImage(data: rawData),
                          let processed = ImageProcessor.resizeAndCompress(image: uiImage) else { return }
                    await MainActor.run {
                        headerImageData = processed
                        headerImage = UIImage(data: processed)
                    }
                }
            }
        }
    }
    
    // MARK: - Collection Form
    
    var collectionForm: some View {
        Form {
            Section("Name") {
                TextField("Collection name", text: $name)
                    .disabled(isNameLocked)
                    .foregroundStyle(isNameLocked ? .secondary : .primary)
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
            
            if selectedTypes.contains("location") {
                Section("Filter by Visit Status") {
                    ForEach([("wantToVisit", "Want to Visit", "checkmark.seal"), ("beenHere", "Been Here", "checkmark.seal.fill")], id: \.0) { value, label, icon in
                        HStack {
                            Label(label, systemImage: selectedLocationStatuses.contains(value) ? (value == "beenHere" ? "checkmark.seal.fill" : "checkmark.seal") : icon)
                                .foregroundStyle(value == "beenHere" && selectedLocationStatuses.contains(value) ? .green : .primary)
                            Spacer()
                            if selectedLocationStatuses.contains(value) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color(hex: selectedColorHex))
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedLocationStatuses.contains(value) {
                                selectedLocationStatuses.remove(value)
                            } else {
                                selectedLocationStatuses.insert(value)
                            }
                        }
                    }
                }
            }
            
            if selectedTypes.contains("media") {
                Section("Filter by Watch Status") {
                    ForEach([("wantTo", "Want to Watch", "bookmark"), ("inProgress", "In Progress", "play.circle"), ("finished", "Finished", "checkmark.circle")], id: \.0) { value, label, icon in
                        HStack {
                            Label(label, systemImage: selectedMediaStatuses.contains(value) ? "\(icon).fill" : icon)
                            Spacer()
                            if selectedMediaStatuses.contains(value) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color(hex: selectedColorHex))
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedMediaStatuses.contains(value) {
                                selectedMediaStatuses.remove(value)
                            } else {
                                selectedMediaStatuses.insert(value)
                            }
                        }
                    }
                }
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
    }
    
    // MARK: - Folio Info Screen
    
    var folioInfoScreen: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer().frame(height: 20)
                
                VStack(spacing: 16) {
                    Text("📖")
                        .font(.system(size: 64))
                    
                    Text("What's a Folio?")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("A Folio gives this collection an identity. Add a cover image, emoji, and color to turn it into a named place in your archive — a show, a trip, a project, a person.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    
                    Text("Entries are still connected the same way — through your filter rules. A Folio just gives them a home.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 32)
                
                if name.isEmpty {
                    Text("Name your collection first to enable Folio.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            isFolio = true
                        }
                    } label: {
                        Text("Make this a Folio")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: selectedColorHex))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Folio Form
    
    var folioForm: some View {
        Form {
            Section {
                HStack {
                    Text("Name")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(name)
                        .foregroundStyle(isNameLocked ? .secondary : .primary)
                    if isNameLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                if isNameLocked {
                    Text("Folio name cannot be changed after creation.")
                        .font(.caption)
                }
            }
            
            Section("Identity") {
                // Emoji
                HStack {
                    Text("Emoji")
                    Spacer()
                    TextField("Pick an emoji", text: $folioEmoji)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
                
                // Color
                colorPickerGrid
            }
            
            Section("Header Image") {
                if let image = headerImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .clipped()
                    
                    Button("Change Image") {
                        showingEmojiPicker = true
                    }
                    .foregroundStyle(Color(hex: selectedColorHex))
                    
                    Button("Remove Image", role: .destructive) {
                        headerImage = nil
                        headerImageData = nil
                    }
                } else {
                    Button {
                        showingEmojiPicker = true
                    } label: {
                        Label("Add Header Image", systemImage: "photo")
                            .foregroundStyle(Color(hex: selectedColorHex))
                    }
                }
            }
            
            Section("Filter Rules") {
                Text("Filter rules still apply — entries matching your collection filters are automatically included in this Folio.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Edit Filter Rules") {
                    withAnimation {
                        selectedFormTab = 0
                    }
                }
                .foregroundStyle(Color(hex: selectedColorHex))
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
    
    func applyCommonFields(to c: Collection) {
        c.filterTypes = Array(selectedTypes)
        c.filterTags = Array(selectedTags)
        c.filterDateRange = selectedDateRange.rawValue
        c.filterLocationName = filterLocationName
        c.filterLocationLatitude = filterLocationLatitude
        c.filterLocationLongitude = filterLocationLongitude
        c.filterLocationRadius = filterLocationRadius
        c.filterSearchText = favoritesOnly ? "__favorites__" : (filterSearchText.isEmpty ? nil : filterSearchText)
        c.filterMediaStatus = Array(selectedMediaStatuses)
        c.filterLocationStatus = Array(selectedLocationStatuses)
        
        if isFolio {
            c.collectionType = "folio"
            c.folioEmoji = folioEmoji.isEmpty ? nil : folioEmoji
            c.colorHex = selectedColorHex
            
            // Save header image if new one selected
            if let data = headerImageData {
                let id = name.lowercased().replacingOccurrences(of: " ", with: "-")
                c.folioHeaderImagePath = try? MediaFileManager.save(
                    data, type: .image, id: "\(id)_folio_header"
                )
            }
        } else {
            c.collectionType = nil
        }
    }
    
    func backfillManualTag(slug: String, collection: Collection) {
        for entry in entries {
            if collectionMatches(entry: entry, collection: collection) {
                if !entry.tagNames.contains(slug) {
                    entry.tagNames.append(slug)
                }
            }
        }
    }
    
    func saveNew() {
        let c = Collection(
            name: name,
            icon: selectedIcon,
            colorHex: selectedColorHex,
            order: collections.count
        )
        applyCommonFields(to: c)
        modelContext.insert(c)
        try? modelContext.save()
    }
    
    func saveEdits() {
        guard let collection else { return }
        // Name locked for Folios — don't update
        if !isFolio { collection.name = name }
        collection.icon = selectedIcon
        collection.colorHex = selectedColorHex
        applyCommonFields(to: collection)
        try? modelContext.save()
    }
    
    func loadHeaderImage() {
        guard let path = collection?.folioHeaderImagePath,
              let data = MediaFileManager.load(path: path),
              let uiImage = UIImage(data: data) else { return }
        headerImage = uiImage
        headerImageData = data
    }
}
