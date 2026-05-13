// iPadFeedView.swift
// Commonplace
//
// Center column of the iPad three-column feed layout.
//
// Structural differences from FeedView (iPhone):
//   - No NavigationStack — selection model replaces push navigation.
//     Tapping a card sets selectedEntry (binding to iPadRootView) instead
//     of pushing a NavigationLink. iPadFeedDetailPanel renders the detail.
//   - No ThoughtCaptureBar — lives in iPadSidebarView on iPad.
//   - No swipe-to-delete — deletion handled via detail view action menu.
//   - createEntry() sets selectedEntry instead of appending to navigationPath.
//   - Selected card receives a subtle accent tint overlay so the user always
//     knows which entry is open in the detail panel.
//
// All card components (EntryRowView, FullEntryCardView, Scrapbook cards) are
// shared with iPhone — no duplication. Feed modes (Standard, Full, Slim,
// Scrapbook) are fully supported.
//
// Feed column width is controlled by NavigationSplitView column sizing in
// iPadRootView. Cards render at whatever width the column provides.

import SwiftUI
import TipKit
import SwiftData
import CoreLocation

struct iPadFeedView: View {
    @Binding var selectedEntry: Entry?
    
    @Query(sort: \Entry.createdAt, order: .reverse) var entries: [Entry]
    @Query var allPersonTags: [Tag]
    @Query var allCollections: [Collection]
    @Environment(\.modelContext) var modelContext
    @StateObject private var locationManager = LocationManager()
    
    @State private var isBackdated = false
    @State private var backdatedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @Binding var showingAddEntry: Bool
    @Binding var showingTemplatePicker: Bool
    @State private var filterType: EntryType? = nil
    @State private var filteredEntries: [Entry] = []
    @State private var visibleCount: Int = 50
    @State private var comingSoonCard: ComingSoonCard? = nil
    @State private var navigationPath = NavigationPath()
    @State private var addEntryDetent: PresentationDetent = .height(425)
    private let collapsedDetent: PresentationDetent = .height(425)
    private let expandedDetent: PresentationDetent = .height(1000)
    
    @AppStorage("feedScrapbookMode") private var isScrapbookMode: Bool = false
    @AppStorage("feedSlimMode") private var isSlimMode: Bool = false
    @AppStorage("feedFullMode") private var isFullMode: Bool = false
    @AppStorage("feedShuffleSeed") private var shuffleSeed: Int = 0
    @State private var isShuffleMode: Bool = false
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var style: any AppThemeStyle { themeManager.style }
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .bottom) {
            scrollContent
        }
    }
    
    @ViewBuilder
    private var scrollBackground: some View {
        if isScrapbookMode {
            ScrapbookBackground().ignoresSafeArea()
        } else {
            style.background.ignoresSafeArea()
        }
    }
    
    private var scrollContent: some View {
        ScrollView {
            feedColumnContent
                .onAppear {
                    locationManager.requestLocation()
                    updateFilter()
                }
                .onChange(of: entries.count) { _, _ in updateFilter() }
                .onChange(of: entries.first?.modifiedAt) { _, _ in
                    WidgetDataStore.writeSnapshot(from: Array(entries.prefix(6)))
                }
                .onChange(of: filterType) { _, _ in
                    visibleCount = 50
                    updateFilter()
                }
                .task {
                    comingSoonCard = await ComingSoonService.runIfNeeded(
                        entries: Array(entries),
                        modelContext: modelContext
                    )
                }
                .onReceive(NotificationCenter.default.publisher(for: .openNewEntrySheet)) { _ in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showingAddEntry = true
                    }
                }
        }
        .background(scrollBackground)
        .overlay(alignment: .top) { fadeOverlay }
        .sheet(isPresented: $showingTemplatePicker) { TemplatePickerView(navigationPath: $navigationPath) }
        .sheet(isPresented: $showingAddEntry) { addEntrySheet }        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: showingAddEntry)
    }
    private var addEntrySheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("New Entry")
                .font(style.typeTitle3)
                .fontWeight(.semibold)
                .foregroundStyle(style.primaryText)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            entryTypeGrid
                .padding(.horizontal, 12)
            backdatedToggle
                .padding(.horizontal, 16)
                .padding(.top, 12)
            templateButton
                .padding(.horizontal, 12)
                .padding(.top, 10)
        }
        .padding(.top, 40)
        .padding(.bottom, 40)
        .background(style.background)
        .safeAreaPadding(.top, 24)
        .safeAreaPadding(.bottom, 24)
        .presentationDetents([collapsedDetent, expandedDetent], selection: $addEntryDetent)
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.visible)
        .onChange(of: isBackdated) { _, newValue in
            withAnimation {
                addEntryDetent = newValue ? expandedDetent : collapsedDetent
            }
        }
        .presentationCornerRadius(20)
    }
    
    @ViewBuilder
    private var fadeOverlay: some View {
        LinearGradient(
            colors: [
                (isScrapbookMode ? Color(red: 0.91, green: 0.86, blue: 0.76) : style.background).opacity(1),
                (isScrapbookMode ? Color(red: 0.91, green: 0.86, blue: 0.76) : style.background).opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 60)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    @ViewBuilder
    private var dimOverlay: some View {
        if showingAddEntry {
            RadialGradient(
                colors: [Color.black.opacity(0.95), Color.black.opacity(0.4)],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showingAddEntry = false
                }
            }
            .transition(.opacity)
        }
    }
    
    @ViewBuilder
    private var addEntryOverlay: some View {
        if showingAddEntry {
            addEntryCard
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.8, anchor: .topTrailing).combined(with: .opacity),
                        removal: .scale(scale: 0.8, anchor: .topTrailing).combined(with: .opacity)
                    )
                )
        }
    }
    
    @ViewBuilder
    private var feedColumnContent: some View {
        LazyVStack(spacing: 0) {
            feedHeader
            filterStripTipView
            entryFilterStrip
            if let card = comingSoonCard {
                ComingSoonCardView(card: card) {
                    comingSoonCard = nil
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            if isSlimMode {
                SlimEntryFeed(entries: filteredEntries, style: style) { entry in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedEntry = entry
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            } else {
                entryRows
            }
        }
    }
    
    // MARK: - Feed Header
    
    @ViewBuilder
    var feedHeader: some View {
        HStack {
            if isScrapbookMode {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShuffleMode.toggle()
                        shuffleSeed = isShuffleMode ? Int.random(in: 1...999999) : 0
                        updateFilter()
                    }
                } label: {
                    Image(systemName: "clock.arrow.trianglehead.2.counterclockwise.rotate.90")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isShuffleMode ? style.accent : style.secondaryText.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            viewModeToggle
        }
        .padding(.leading, 24)
        .padding(.trailing, 16)
        .padding(.top, 8)
        .id("feed-title")
    }
    
    // MARK: - View Mode Toggle
    
    private var viewModeToggle: some View {
        HStack(spacing: 0) {
            // Full
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isFullMode = true
                    isScrapbookMode = false
                    isSlimMode = false
                    isShuffleMode = false
                    shuffleSeed = 0
                    updateFilter()
                }
            } label: {
                Image(systemName: "text.rectangle.page")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isFullMode ? style.accent : style.secondaryText.opacity(0.4))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Standard
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isFullMode = false
                    isScrapbookMode = false
                    isSlimMode = false
                    isShuffleMode = false
                    shuffleSeed = 0
                    updateFilter()
                }
            } label: {
                Image(systemName: "rectangle.grid.1x2")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(!isFullMode && !isScrapbookMode && !isSlimMode ? style.accent : style.secondaryText.opacity(0.4))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Slim
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isFullMode = false
                    isScrapbookMode = false
                    isSlimMode = true
                    isShuffleMode = false
                    shuffleSeed = 0
                    updateFilter()
                }
            } label: {
                Image(systemName: "text.justify")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSlimMode ? style.accent : style.secondaryText.opacity(0.4))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Scrapbook
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isFullMode = false
                    isScrapbookMode = true
                    isSlimMode = false
                }
            } label: {
                Image(systemName: "rectangle.3.group.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isScrapbookMode ? Color(red: 0.5, green: 0.35, blue: 0.15) : style.secondaryText.opacity(0.4))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .background(isScrapbookMode ? Color(red: 0.91, green: 0.86, blue: 0.76).opacity(0.3) : style.surface.opacity(0.5))
        .clipShape(Capsule())
        .popoverTip(ViewModesTip())
    }
    
    // MARK: - Entry Rows
    
    @ViewBuilder
    var entryRows: some View {
        ForEach(filteredEntries) { entry in
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedEntry = entry
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    if isScrapbookMode {
                        scrapbookCard(for: entry)
                    } else if isFullMode {
                        FullEntryCardView(entry: entry, allPersonTags: allPersonTags, allCollections: allCollections)
                    } else {
                        EntryRowView(entry: entry, allPersonTags: allPersonTags, allCollections: allCollections)
                    }
                    
                    // Selected state overlay
                    if selectedEntry?.id == entry.id {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(entry.type.accentColor(for: themeManager.current).opacity(0.5), lineWidth: 2)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, isScrapbookMode ? 0 : 16)
            .padding(.vertical, isScrapbookMode ? -8 : 4)
            .frame(maxWidth: .infinity)
        }
        
        let totalCount = entries.count
        if visibleCount < totalCount {
            Button {
                withAnimation {
                    visibleCount += 50
                    updateFilter()
                }
            } label: {
                Text("Load More")
                    .font(.subheadline)
                    .foregroundStyle(style.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Entry Filter Strip
    
    @Namespace private var filterNamespace
    
    var entryFilterStrip: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let slotWidth = totalWidth / CGFloat(EntryType.allCases.count)
            ZStack(alignment: .leading) {
                if let selected = filterType {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selected.detailAccentColor(for: themeManager.current).opacity(0.15))
                        .frame(width: slotWidth, height: 36)
                        .offset(x: CGFloat(EntryType.allCases.firstIndex(of: selected) ?? 0) * slotWidth)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: filterType)
                }
                HStack(spacing: 0) {
                    ForEach(EntryType.allCases, id: \.self) { type in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                filterType = filterType == type ? nil : type
                            }
                        } label: {
                            Image(systemName: type.icon)
                                .font(.system(size: 14, weight: filterType == type ? .semibold : .regular))
                                .foregroundStyle(
                                    filterType == type
                                    ? type.detailAccentColor(for: themeManager.current)
                                    : style.secondaryText.opacity(0.6)
                                )
                                .frame(width: slotWidth)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(height: 40)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
    
    // MARK: - Filter Strip Tip
    
    @State private var filterStripTip = FilterStripTip()
    
    var filterStripTipView: some View {
        TipView(filterStripTip, arrowEdge: .bottom)
            .padding(.horizontal, 16)
            .padding(.top, 8)
    }
    
    // MARK: - Scrapbook Cards
    
    @ViewBuilder
    func scrapbookCard(for entry: Entry) -> some View {
        switch entry.type {
        case .text:       ScrapbookNoteCard(entry: entry)
        case .sticky:     ScrapbookStickyCard(entry: entry)
        case .photo:      ScrapbookShotCard(entry: entry)
        case .link:       ScrapbookLinkCard(entry: entry)
        case .location:   ScrapbookPlaceCard(entry: entry)
        case .music:      ScrapbookMusicCard(entry: entry)
        case .audio:      ScrapbookSoundCard(entry: entry)
        case .media:      ScrapbookMediaCard(entry: entry)
        case .journal:    ScrapbookJournalCard(entry: entry)
        case .attachment: ScrapbookAttachmentCard(entry: entry)
        }
    }
    
    // MARK: - Add Entry Card
    
    var addEntryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("New Entry")
                .font(style.typeTitle3)
                .fontWeight(.semibold)
                .foregroundStyle(style.primaryText)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            entryTypeGrid
                .padding(.horizontal, 12)
            backdatedToggle
                .padding(.horizontal, 16)
                .padding(.top, 12)
            templateButton
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 24)
        }
        .background(style.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(style.surface.opacity(0.5), lineWidth: 0.5)
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Backdated Toggle
    
    var backdatedToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $isBackdated.animation(.spring(duration: 0.25))) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 14))
                        .foregroundStyle(isBackdated ? style.accent : style.secondaryText)
                    Text("Backdated")
                        .font(style.typeBodySecondary)
                        .foregroundStyle(isBackdated ? style.primaryText : style.secondaryText)
                }
            }
            .tint(style.accent)
            
            if isBackdated {
                DatePicker(
                    "",
                    selection: $backdatedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .scaleEffect(0.8, anchor: .center)
                .frame(height: 260)
                .padding(.vertical, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Entry Type Grid
    
    let addTypes: [(type: EntryType, label: String, icon: String, color: Color)] = [
        (.text,       "Note",       "text.alignleft",    .gray),
        (.photo,      "Shot",       "camera.fill",       .pink),
        (.audio,      "Sound",      "waveform",          .orange),
        (.link,       "Link",       "link",              .blue),
        (.sticky,     "List",       "checklist",         Color(hex: "#FFD60A")),
        (.location,   "Place",      "mappin.circle.fill",.green),
        (.music,      "Music",      "music.note",        .red),
        (.media,      "Media",      "film.fill",         .red),
        (.attachment, "Attachment", "paperclip",         Color(hex: "#C8C0A0")),
    ]
    
    var entryTypeGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
            spacing: 8
        ) {
            ForEach(addTypes, id: \.type) { item in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showingAddEntry = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        createEntry(type: item.type, date: isBackdated ? backdatedDate : Date())
                    }
                } label: {
                    entryTypeButton(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    func entryTypeButton(item: (type: EntryType, label: String, icon: String, color: Color)) -> some View {
        let cardColor = item.type.cardColor(for: themeManager.current)
        let accentColor = item.type.detailAccentColor(for: themeManager.current)
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(cardColor)
                .frame(maxWidth: .infinity, minHeight: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style.cardBorder, lineWidth: 0.5)
                )
            VStack(spacing: 6) {
                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(accentColor)
                Text(item.label)
                    .font(style.typeBodySecondary)
                    .fontWeight(.medium)
                    .foregroundStyle(accentColor)
            }
        }
    }
    
    // MARK: - Template Button
    
    var templateButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showingAddEntry = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingTemplatePicker = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.badge.plus")
                    .font(.subheadline)
                Text("Use a Template")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(style.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(style.accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style.accent.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    
    func createEntry(type: EntryType, date: Date = Date()) {
        let entry = Entry(type: type, text: "", tags: [])
        entry.createdAt = date
        entry.modifiedAt = date
        if let location = locationManager.currentLocation {
            entry.captureLatitude = location.coordinate.latitude
            entry.captureLongitude = location.coordinate.longitude
            entry.captureLocationName = locationManager.currentPlaceName
        }
        modelContext.insert(entry)
        try? modelContext.save()
        SearchIndex.shared.index(entry: entry)
        WidgetDataStore.writeSnapshot(from: Array(entries.prefix(6)))
        // Show new entry immediately in detail panel
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedEntry = entry
        }
        isBackdated = false
        backdatedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }
    
    func updateFilter() {
        let snapshot = Array(entries)
        let type = filterType
        let shuffle = isShuffleMode
        let seed = shuffleSeed
        let count = visibleCount
        Task.detached(priority: .userInitiated) {
            var base = snapshot
            if let type {
                base = base.filter { $0.type == type }
            }
            if shuffle && seed > 0 {
                base = base.sorted {
                    let h1 = abs(($0.id.uuidString + "\(seed)").hashValue)
                    let h2 = abs(($1.id.uuidString + "\(seed)").hashValue)
                    return h1 < h2
                }
            }
            let result = Array(base.prefix(count))
            await MainActor.run {
                filteredEntries = result
            }
        }
    }
}
