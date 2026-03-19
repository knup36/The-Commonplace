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
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showingAddEntry = false
    @State private var showingTemplatePicker = false
    @State private var navigationPath = NavigationPath()
    @State private var deletedEntry: Entry? = nil
    @State private var showingUndoToast = false
    @EnvironmentObject var themeManager: ThemeManager
    @FocusState private var searchFocused: Bool

    let addTypes: [(type: EntryType, label: String, icon: String, color: Color)] = [
        (.text,     "Note",   "text.alignleft",    .gray),
        (.photo,    "Photo",  "camera.fill",        .pink),
        (.audio,    "Audio",  "waveform",           .orange),
        (.link,     "Link",   "link",               .blue),
        (.sticky,   "List",   "checklist",          Color(hex: "#FFD60A")),
        (.location, "Place",  "mappin.circle.fill", .green),
        (.music,    "Music",  "music.note",         .red),
    ]

    var style: any AppThemeStyle { themeManager.style }

    var filteredEntries: [Entry] {
        let base = searchText.isEmpty ? entries : entries.filter { entryMatchesSearch($0, searchText: searchText) }
        return base.filter { $0.id != deletedEntry?.id }
    }

    // MARK: - Feed Header

    @ViewBuilder
    var feedHeader: some View {
        if !isSearching && style.usesSerifFonts {
            Text("Feed")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(style.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .id("feed-title")
        }
    }

    // MARK: - Entry Rows

    @ViewBuilder
    var entryRows: some View {
        ForEach(filteredEntries) { entry in
            ZStack {
                NavigationLink(destination: destinationView(for: entry)) {
                    EmptyView()
                }
                .opacity(0)
                EntryRowView(entry: entry)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    withAnimation { entry.isFavorited.toggle() }
                } label: {
                    Label(entry.isFavorited ? "Unfavorite" : "Favorite",
                          systemImage: entry.isFavorited ? "star.slash.fill" : "star.fill")
                }
                .tint(.yellow)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    deletedEntry = entry
                    showingUndoToast = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .onDelete(perform: deleteEntries)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack(path: $navigationPath) {
                List {
                    feedHeader
                    entryRows
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(style.background)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if isSearching {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Search entries...", text: $searchText)
                                    .focused($searchFocused)
                                    .autocorrectionDisabled()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(uiColor: .systemGray6))
                            .clipShape(Capsule())
                            .frame(width: 260)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            if !showingAddEntry {
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        isSearching.toggle()
                                        if isSearching {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                searchFocused = true
                                            }
                                        } else {
                                            searchText = ""
                                            searchFocused = false
                                            UIApplication.shared.sendAction(
                                                #selector(UIResponder.resignFirstResponder),
                                                to: nil, from: nil, for: nil
                                            )
                                        }
                                    }
                                } label: {
                                    Image(systemName: isSearching ? "xmark.circle.fill" : "magnifyingglass")
                                        .foregroundStyle(isSearching ? .secondary : .primary)
                                }
                            }
                            if !isSearching {
                                Button {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                        showingAddEntry.toggle()
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .fontWeight(.medium)
                                        .rotationEffect(.degrees(showingAddEntry ? 45 : 0))
                                        .animation(.spring(response: 0.4, dampingFraction: 0.65), value: showingAddEntry)
                                }
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                                        showingTemplatePicker = true
                                    }
                                )
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingTemplatePicker) {
                    TemplatePickerView(navigationPath: $navigationPath)
                }
                .navigationDestination(for: Entry.self) { entry in
                    destinationView(for: entry)
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
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
    }

    // MARK: - Add Entry Card

    var addEntryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("New Entry")
                .font(.system(.subheadline, design: style.usesSerifFonts ? .serif : .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(style.primaryText)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            entryTypeGrid
                .padding(.horizontal, 12)
            templateButton
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 16)
        }
        .background(style.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
        .overlay(
            style.usesSerifFonts
            ? RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [InkwellTheme.cardBorderTop, InkwellTheme.cardBorderTop.opacity(0.3)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            : nil
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
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
                        createEntry(type: item.type)
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
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(style.usesSerifFonts
                      ? InkwellTheme.cardBackground(for: item.type)
                      : item.color.opacity(0.12))
                .frame(maxWidth: .infinity, minHeight: 80)
                .overlay(
                    style.usesSerifFonts
                    ? AnyView(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [InkwellTheme.cardBorderTop, InkwellTheme.cardBorderColor(for: item.type)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
                    : AnyView(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(item.color.opacity(0.5), lineWidth: 0.5)
                    )
                )
                .shadow(color: style.usesSerifFonts ? .black.opacity(0.4) : .black.opacity(0.08), radius: 6, x: 0, y: 3)
            VStack(spacing: 6) {
                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(style.usesSerifFonts
                                     ? InkwellTheme.accentColor(for: item.type)
                                     : item.color)
                Text(item.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(style.usesSerifFonts
                                     ? InkwellTheme.accentColor(for: item.type)
                                     : .primary)
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

    func createEntry(type: EntryType) {
        let entry = Entry(type: type, text: "", tags: [])
        if let location = locationManager.currentLocation {
            entry.captureLatitude = location.coordinate.latitude
            entry.captureLongitude = location.coordinate.longitude
            entry.captureLocationName = locationManager.currentPlaceName
        }
        modelContext.insert(entry)
        SearchIndex.shared.index(entry: entry)
        navigationPath.append(entry)
    }

    func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            SearchIndex.shared.remove(entryID: filteredEntries[index].id)
            modelContext.delete(filteredEntries[index])
        }
    }
}
