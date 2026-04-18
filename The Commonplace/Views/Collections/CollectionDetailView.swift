// CollectionDetailView.swift
// Commonplace
//
// Detail view for Collections and Folios.
// Routes to two layouts based on collection.isFolio:
//
//   Plain Collection — header with icon, filter chips, entry count,
//   searchable entry list, ThoughtCaptureBar at bottom.
//
//   Folio — rich layout with header image/gradient, emoji, name,
//   entry type counts, sticky grid, photo grid, slim feed.
//   Absorbed from FolioDetailView in v2.4.
//
// Screen: Library tab → tap any Collection or Folio

import SwiftUI
import SwiftData
import PhotosUI

struct CollectionDetailView: View {
    let collection: Collection
    @Query(sort: \Entry.createdAt, order: .reverse) var entries: [Entry]
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var searchText = ""
    @State private var showingAddEntry: Bool = false
    @State private var showingTemplatePicker: Bool = false
    @State private var showingDeleteConfirmation = false
    @State private var showingHeaderImagePicker = false
    @State private var showingEditFolio = false
    @State private var showingEditCollection = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var headerImage: UIImage? = nil
    @State private var imageToCrop: UIImage? = nil
    
    var style: any AppThemeStyle { themeManager.style }
    var accentColor: Color { Color(hex: collection.colorHex) }
    var folioColor: Color { Color(hex: collection.colorHex) }
    
    var hasActiveFilters: Bool {
        !collection.filterTypes.isEmpty ||
        !collection.filterTags.isEmpty ||
        !collection.filterMediaStatus.isEmpty ||
        !collection.filterLocationStatus.isEmpty ||
        collection.filterSearchText != nil ||
        collection.filterLocationName != nil ||
        (DateFilterRange(rawValue: collection.filterDateRange) ?? .allTime) != .allTime
    }
    
    var filteredEntries: [Entry] {
        let matched = entries
            .filter { collectionMatches(entry: $0, collection: collection) }
            .sorted { $0.createdAt > $1.createdAt }
        if searchText.isEmpty { return matched }
        return matched.filter { entryMatchesSearch($0, searchText: searchText) }
    }
    
    // MARK: - Folio Entry Groups
    
    var stickyEntries: [Entry] {
        filteredEntries.filter { $0.type == .sticky }
    }
    
    var photoEntries: [Entry] {
        filteredEntries.filter { $0.type == .photo }
    }
    
    var slimEntries: [Entry] {
        filteredEntries.filter { $0.type != .sticky && $0.type != .photo }
    }
    
    let typeOrder: [EntryType] = [.text, .photo, .audio, .link, .journal, .location, .sticky, .music, .media]
    
    func count(for type: EntryType) -> Int {
        filteredEntries.filter { $0.type == type }.count
    }
    
    var menuButton: some View {
        Menu {
            if collection.isFolio {
                Button {
                    showingEditFolio = true
                } label: {
                    Label("Edit Folio", systemImage: "pencil")
                }
                Divider()
            } else {
                Button {
                    showingEditCollection = true
                } label: {
                    Label("Edit Collection", systemImage: "pencil")
                }
                Divider()
            }
            Button {
                withAnimation { collection.isPinned.toggle() }
                try? modelContext.save()
            } label: {
                Label(collection.isPinned ? "Remove Bookmark" : "Bookmark",
                      systemImage: collection.isPinned ? "bookmark.fill" : "bookmark")
            }
            Divider()
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(style.accent)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if collection.isFolio {
                folioLayout
            } else {
                collectionLayout
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                menuButton
            }
        }
        .confirmationDialog(
            "Delete \"\(collection.name)\"?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(collection)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if collection.isFolio {
                Text("The Folio will be removed. Your entries will not be deleted.")
            } else {
                Text("The Collection will be removed. Your entries will not be deleted.")
            }
        }
        .photosPicker(isPresented: $showingHeaderImagePicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                guard let newItem,
                      let rawData = try? await newItem.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: rawData) else { return }
                await MainActor.run { imageToCrop = uiImage }
            }
        }
        .sheet(isPresented: Binding(
            get: { imageToCrop != nil },
            set: { if !$0 { imageToCrop = nil } }
        )) {
            if let image = imageToCrop {
                FolioHeaderCropView(image: image) { cropped in
                    imageToCrop = nil
                    Task { await saveHeaderImage(cropped) }
                } onCancel: {
                    imageToCrop = nil
                }
            }
        }
        .onAppear {
            loadHeaderImage()
            // Small delay to catch header images saved just before navigation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if headerImage == nil {
                    loadHeaderImage()
                }
            }
        }
        .onChange(of: showingEditFolio) { _, isShowing in
            if !isShowing {
                loadHeaderImage()
            }
        }
        .onChange(of: collection.folioHeaderImagePath) { _, _ in
            loadHeaderImage()
        }
        .sheet(isPresented: $showingEditCollection) {
            CollectionFormView(collection: collection)
        }
        .sheet(isPresented: $showingEditFolio) {
            CollectionFormView(collection: collection)
        }
    }
    
    // MARK: - Collection Layout
    
    var collectionLayout: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                collectionHeader
                if filteredEntries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(style.tertiaryText)
                        Text("Nothing matches these filters")
                            .font(style.typeBodySecondary)
                            .foregroundStyle(style.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    entryRows
                }
            }
        }
        .background(style.background)
        .searchable(text: $searchText, prompt: "Search collection...")
        .safeAreaInset(edge: .bottom) {
            ThoughtCaptureBar(
                showFullBar: false,
                showingAddEntry: $showingAddEntry,
                showingTemplatePicker: $showingTemplatePicker,
                contextTags: collection.filterTags
            )
        }
    }
    
    var collectionHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                    .overlay(Circle().strokeBorder(accentColor.opacity(0.3), lineWidth: 0.5))
                Image(systemName: collection.icon)
                    .font(.title2)
                    .foregroundStyle(accentColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name)
                    .font(style.typeTitle2)
                    .fontWeight(.bold)
                    .foregroundStyle(style.primaryText)
                if hasActiveFilters {
                    filterChips
                }
            }
            
            Spacer()
            
            Text("\(filteredEntries.count)")
                .font(style.typeLargeTitle)
                .fontWeight(.bold)
                .foregroundStyle(accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
    
    var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if !collection.filterTypes.isEmpty {
                    ForEach(collection.filterTypes, id: \.self) { type in
                        filterChip(icon: EntryType(rawValue: type)?.icon, label: EntryType(rawValue: type)?.displayName ?? type.capitalized)
                    }
                }
                if !collection.filterTags.isEmpty {
                    ForEach(collection.filterTags, id: \.self) { tag in
                        filterChip(icon: "number", label: tag)
                    }
                }
                if let range = DateFilterRange(rawValue: collection.filterDateRange), range != .allTime {
                    filterChip(icon: "calendar", label: range.rawValue)
                }
                if let locationName = collection.filterLocationName {
                    filterChip(icon: "location.fill", label: "near \(locationName)")
                }
                if let st = collection.filterSearchText, !st.isEmpty, st != "__favorites__" {
                    filterChip(icon: "magnifyingglass", label: st)
                }
                if collection.filterSearchText == "__favorites__" {
                    filterChip(icon: "star.fill", label: "Favorites")
                }
                if !collection.filterMediaStatus.isEmpty {
                    ForEach(collection.filterMediaStatus, id: \.self) { status in
                        filterChip(icon: "film.fill", label: mediaStatusLabel(for: status))
                    }
                }
                if !collection.filterLocationStatus.isEmpty {
                    ForEach(collection.filterLocationStatus, id: \.self) { status in
                        filterChip(icon: "mappin.circle.fill", label: status == "beenHere" ? "Been Here" : "Want to Visit")
                    }
                }
            }
        }
    }
    
    func filterChip(icon: String?, label: String) -> some View {
        HStack(spacing: 3) {
            if let icon { Image(systemName: icon).font(.caption) }
            Text(label).font(.caption)
        }
        .foregroundStyle(style.secondaryText)
    }
    
    @ViewBuilder
    var entryRows: some View {
        ForEach(filteredEntries) { entry in
            NavigationLink(destination: NavigationRouter.destination(for: entry)) {
                EntryRowView(entry: entry)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Folio Layout
    
    var folioLayout: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                folioHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                
                if !stickyEntries.isEmpty {
                    stickySection
                        .padding(.horizontal, 16)
                }
                
                if !photoEntries.isEmpty {
                    photoGrid
                        .padding(.horizontal, 16)
                }
                
                if !slimEntries.isEmpty {
                    SlimEntryFeed(entries: slimEntries, style: style)
                        .padding(.horizontal, 16)
                }
                
                Spacer().frame(height: 80)
            }
        }
        .background(style.background.ignoresSafeArea())
    }
    
    var folioHeader: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text(collection.folioEmoji ?? "◆")
                        .font(.system(size: 44))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(collection.name)
                            .font(style.typeLargeTitle)
                            .foregroundStyle(headerImage != nil ? .white : style.primaryText)
                        HStack(spacing: 6) {
                            if collection.isPinned {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(headerImage != nil ? .white : style.accent)
                            }
                            Text("\(filteredEntries.count) \(filteredEntries.count == 1 ? "entry" : "entries")")
                                .font(style.typeCaption)
                                .foregroundStyle(headerImage != nil ? .white.opacity(0.8) : style.secondaryText)
                            if hasActiveFilters {                                filterChips
                                .opacity(headerImage != nil ? 0.85 : 1.0)
                            }
                        }
                    }
                }
                
                // Entry type counts strip
                HStack(spacing: 0) {
                    ForEach(typeOrder, id: \.self) { type in
                        let c = count(for: type)
                        Text("\(c)")
                            .font(.system(size: 15, weight: c > 0 ? .semibold : .regular))
                            .foregroundStyle(
                                c > 0
                                ? type.detailAccentColor(for: themeManager.current)
                                : (headerImage != nil ? Color.white.opacity(0.2) : style.tertiaryText.opacity(0.3))
                            )
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .background(headerImage != nil ? Color.black.opacity(0.55) : style.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .background {
            if let image = headerImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.0), Color.black.opacity(0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                LinearGradient(
                    colors: [folioColor.opacity(0.6), folioColor.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    var stickySection: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
            spacing: 10
        ) {
            ForEach(stickyEntries) { entry in
                NavigationLink(destination: NavigationRouter.destination(for: entry)) {
                    CompactEntryCard(entry: entry, style: style)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    var photoGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 4),
            spacing: 3
        ) {
            ForEach(photoEntries) { entry in
                NavigationLink(destination: NavigationRouter.destination(for: entry)) {
                    photoThumb(entry: entry)
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    func photoThumb(entry: Entry) -> some View {
        GeometryReader { geo in
            Group {
                if let path = entry.imagePath,
                   let data = MediaFileManager.load(path: path),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(style.surface)
                        .frame(width: geo.size.width, height: geo.size.width)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(style.tertiaryText)
                        )
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    // MARK: - Header Image Helpers
    
    func loadHeaderImage() {
        guard let path = collection.folioHeaderImagePath,
              let data = MediaFileManager.load(path: path),
              let uiImage = UIImage(data: data) else { return }
        headerImage = uiImage
    }
    
    func saveHeaderImage(_ uiImage: UIImage) async {
        guard let processedData = ImageProcessor.resizeAndCompress(image: uiImage) else { return }
        let slug = collection.name.lowercased().replacingOccurrences(of: " ", with: "-")
        let path = try? MediaFileManager.save(processedData, type: .image, id: "\(slug)_folio_header")
        await MainActor.run {
            collection.folioHeaderImagePath = path
            headerImage = UIImage(data: processedData)
            try? modelContext.save()
        }
    }
}
