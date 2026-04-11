import SwiftUI
import SwiftData
import CoreLocation


// MARK: - FeedView
// Main feed view showing all entries in reverse chronological order.
// Handles search, add entry card, swipe actions, and undo toast.
// Stats are hidden above the Feed title — pull down to reveal.
// Screen: Feed tab (bottom navigation)

struct FeedView: View {
    @Query(sort: \Entry.createdAt, order: .reverse) var entries: [Entry]
    @Environment(\.modelContext) var modelContext
    @StateObject private var locationManager = LocationManager()
    @State private var showingAddEntry = false
    @State private var showingTemplatePicker = false
    @State private var isBackdated = false
    @State private var backdatedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var navigationPath = NavigationPath()
    @State private var deletedEntry: Entry? = nil
    @State private var showingUndoToast = false
    @State private var filterType: EntryType? = nil
    @State private var filteredEntries: [Entry] = []
    @State private var visibleCount: Int = 50
    @State private var thoughtText: String = ""
    @State private var isCapturingThought: Bool = false
    @FocusState private var thoughtFieldFocused: Bool
    @State private var currentPrompt: String = ""
    @AppStorage("feedScrapbookMode") private var isScrapbookMode: Bool = false
    @AppStorage("feedShuffleSeed") private var shuffleSeed: Int = 0
    @State private var isShuffleMode: Bool = false
    
    var currentPromptText: String { currentPrompt.isEmpty ? ThoughtPrompts.random() : currentPrompt }
    @EnvironmentObject var themeManager: ThemeManager
    
    let addTypes: [(type: EntryType, label: String, icon: String, color: Color)] = [
        (.text,     "Note",   "text.alignleft",    .gray),
        (.photo,    "Shot",  "camera.fill",        .pink),
        (.audio,    "Sound",  "waveform",           .orange),
        (.link,     "Link",   "link",               .blue),
        (.sticky,   "List",   "checklist",          Color(hex: "#FFD60A")),
        (.location, "Place",  "mappin.circle.fill", .green),
        (.music,    "Music",  "music.note",         .red),
        (.media, "Media", "film.fill", .red),
    ]
    
    var style: any AppThemeStyle { themeManager.style }
    
    // MARK: - Feed Header
    
    @ViewBuilder
    var feedHeader: some View {
        HStack {
            Text("Feed")
                .font(style.typeLargeTitle)
                .foregroundStyle(isScrapbookMode ? Color(red: 0.3, green: 0.25, blue: 0.18) : style.primaryText)
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
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isScrapbookMode.toggle()
                    if !isScrapbookMode {
                        isShuffleMode = false
                        shuffleSeed = 0
                        updateFilter()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(!isScrapbookMode ? style.accent : style.secondaryText.opacity(0.4))
                    Image(systemName: "rectangle.3.group.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isScrapbookMode ? Color(red: 0.5, green: 0.35, blue: 0.15) : style.secondaryText.opacity(0.4))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isScrapbookMode ? Color(red: 0.91, green: 0.86, blue: 0.76).opacity(0.3) : style.surface.opacity(0.5))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 24)
        .padding(.trailing, 16)
        .padding(.top, 8)
        .id("feed-title")
    }
    
    // MARK: - Entry Rows
    
    @ViewBuilder
    var entryRows: some View {
        ForEach(filteredEntries) { entry in
            NavigationLink(destination: NavigationRouter.destination(for: entry)) {
                if isScrapbookMode {
                    scrapbookCard(for: entry)
                } else {
                    EntryRowView(entry: entry)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, isScrapbookMode ? 0 : 16)
            .padding(.vertical, isScrapbookMode ? -8 : 4)
            .frame(maxWidth: .infinity)
        }
        let totalCount = entries.filter { $0.id != deletedEntry?.id }.count
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
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack(path: $navigationPath) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        feedHeader
                        entryFilterStrip
                        entryRows
                    }
                }
                .background(isScrapbookMode ? AnyView(ScrapbookBackground().ignoresSafeArea()) : AnyView(style.background.ignoresSafeArea()))
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $showingTemplatePicker) {
                    TemplatePickerView(navigationPath: $navigationPath)
                }
                .navigationDestination(for: Entry.self) { entry in
                    NavigationRouter.destination(for: entry)
                }
                .overlay(alignment: .topTrailing) {
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
                .overlay {
                    if showingAddEntry {
                        addEntryCard
                            .transition(
                                .asymmetric(
                                    insertion: .scale(scale: 0.8, anchor: .topTrailing)
                                        .combined(with: .opacity),
                                    removal: .scale(scale: 0.8, anchor: .topTrailing)
                                        .combined(with: .opacity)
                                )
                            )
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.78), value: showingAddEntry)
                .onAppear {
                    locationManager.requestLocation()
                    updateFilter()
                }
                .onChange(of: entries) { _, _ in updateFilter() }
                .onChange(of: filterType) { _, _ in visibleCount = 50; updateFilter() }
                .onChange(of: deletedEntry) { _, _ in updateFilter() }
                .onAppear {
                    currentPrompt = ThoughtPrompts.random()
                }
                .safeAreaInset(edge: .bottom) {
                    thoughtCaptureBar
                }
            }
            
            // Undo toast
            if showingUndoToast, let entry = deletedEntry {
                UndoToast(
                    message: "Entry deleted",
                    duration: 5.0,
                    onUndo: {
                        deletedEntry = nil
                        showingUndoToast = false
                    },
                    onExpire: {
                        if let entry = deletedEntry {
                            SearchIndex.shared.remove(entryID: entry.id)
                            withAnimation { modelContext.delete(entry) }
                        }
                        deletedEntry = nil
                        showingUndoToast = false
                    }
                )
                .id(deletedEntry?.id)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
    }
    
    // MARK: - Entry Filter Strip
    
    @Namespace private var filterNamespace
    
    var entryFilterStrip: some View {
        ZStack(alignment: .leading) {
            // Background pill — hidden in scrapbook mode
            if !isScrapbookMode {
                RoundedRectangle(cornerRadius: 10)
                    .fill(style.surface.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(style.cardBorder, lineWidth: 0.5)
                    )
            }
            
            // Sliding selection indicator
            if let selected = filterType {
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected.detailAccentColor(for: themeManager.current).opacity(0.15))
                    .matchedGeometryEffect(id: "filterSelector", in: filterNamespace)
                    .frame(width: (UIScreen.main.bounds.width - 32) / CGFloat(EntryType.allCases.count))
                    .offset(x: CGFloat(EntryType.allCases.firstIndex(of: selected) ?? 0) * (UIScreen.main.bounds.width - 32) / CGFloat(EntryType.allCases.count))
                    .padding(2)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: filterType)
            }
            
            // Icons row
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
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 40)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
    
    // MARK: - Scrapbook Cards
    
    @ViewBuilder
    func scrapbookCard(for entry: Entry) -> some View {
        switch entry.type {
        case .text:
            ScrapbookNoteCard(entry: entry)
        case .sticky:
            ScrapbookStickyCard(entry: entry)
        case .photo:
            ScrapbookShotCard(entry: entry)
        case .link:
            ScrapbookLinkCard(entry: entry)
        case .location:
            ScrapbookPlaceCard(entry: entry)
        case .music:
            ScrapbookMusicCard(entry: entry)
        case .audio:
            ScrapbookSoundCard(entry: entry)
        case .media:
            ScrapbookMediaCard(entry: entry)
        case .journal:
            ScrapbookJournalCard(entry: entry)
        }
    }
    
    // MARK: - Thought Capture Bar
    
    var thoughtCaptureBar: some View {
        HStack(spacing: 12) {
            
            // Search button — glass circle
            NavigationLink(destination: SearchView()) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.001))
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular.interactive(), in: Circle())
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(style.accent)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            // Thought capture field — glass capsule
            HStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    // Rotating prompt as placeholder — only shown when not capturing
                    if !isCapturingThought && thoughtText.isEmpty {
                        MarqueeText(
                            text: currentPrompt,
                            font: style.typeBody,
                            color: Color(uiColor: .placeholderText)
                        )
                        .allowsHitTesting(false)
                    }
                    TextField("", text: $thoughtText, axis: .vertical)
                        .font(style.typeBody)
                        .foregroundStyle(style.primaryText)
                        .focused($thoughtFieldFocused)
                        .lineLimit(1...6)
                        .onSubmit {
                            createThought()
                        }
                        .onChange(of: thoughtFieldFocused) { _, focused in
                            withAnimation(.spring(duration: 0.25)) {
                                isCapturingThought = focused
                            }
                        }
                }
                
                if isCapturingThought {
                    Button {
                        createThought()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(style.accent)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22))
            
            // Add button — glass circle
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    showingAddEntry.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.001))
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular.interactive(), in: Circle())
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(style.accent)
                        .rotationEffect(.degrees(showingAddEntry ? 45 : 0))
                        .animation(.spring(response: 0.4, dampingFraction: 0.65), value: showingAddEntry)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                    showingTemplatePicker = true
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .animation(.spring(duration: 0.25), value: isCapturingThought)
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
                .padding(.bottom, 80)
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
                .scaleEffect(0.9, anchor: .center)
                .frame(height: 320)
                .padding(.vertical, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Entry Type Grid
    
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
    
    // MARK: - Entry Type Button
    
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
        navigationPath.append(entry)
        // Reset backdated state for next entry
        isBackdated = false
        backdatedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }
    
    func createThought() {
        let trimmed = thoughtText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            thoughtFieldFocused = false
            isCapturingThought = false
            return
        }
        
        let entry = Entry(type: .text, text: trimmed, tags: [])
        if let location = locationManager.currentLocation {
            entry.captureLatitude = location.coordinate.latitude
            entry.captureLongitude = location.coordinate.longitude
            entry.captureLocationName = locationManager.currentPlaceName
        }
        modelContext.insert(entry)
        try? modelContext.save()
        SearchIndex.shared.index(entry: entry)
        
        thoughtText = ""
        thoughtFieldFocused = false
        isCapturingThought = false
        updateFilter()
    }
    
    func updateFilter() {
        var base = entries.filter { $0.id != deletedEntry?.id }
        if let type = filterType {
            base = base.filter { $0.type == type }
        }
        if isShuffleMode && shuffleSeed > 0 {
            base = base.sorted {
                let h1 = abs(($0.id.uuidString + "\(shuffleSeed)").hashValue)
                let h2 = abs(($1.id.uuidString + "\(shuffleSeed)").hashValue)
                return h1 < h2
            }
        }
        filteredEntries = Array(base.prefix(visibleCount))
    }
}
