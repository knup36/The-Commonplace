// ThoughtCaptureBar.swift
// Commonplace
//
// A reusable bottom bar component extracted from FeedView.
// Handles thought capture (quick text → Note entry), search navigation,
// and add entry button. Used in FeedView (full bar) and CollectionDetailView
// (capture field only, via showFullBar: false).
//
// Owns its own thought capture state (text, focus, capturing).
// The add entry card, its animation, and navigationPath all remain in FeedView —
// this component only toggles showingAddEntry/showingTemplatePicker via bindings.
//
// Tag interaction:
//   - While capturing, a tag button floats above the bar on the left
//   - Tapping it slides the suggestion strip out to the right from the button
//   - Selected tags appear inside the capture capsule above the text
//   - × cancel resets everything including tags
//
// Parameters:
//   showFullBar           — when false, hides search and add buttons (CollectionDetailView mode)
//   showingAddEntry       — binding to FeedView's add entry card toggle
//   showingTemplatePicker — binding to FeedView's template picker toggle
//   contextTags           — tags pinned to front of suggestions (e.g. collection's filterTags)

import SwiftUI
import SwiftData
import CoreLocation

struct ThoughtCaptureBar: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var themeManager: ThemeManager

    var showFullBar: Bool = true
    @Binding var showingAddEntry: Bool
    @Binding var showingTemplatePicker: Bool
    var contextTags: [String] = []

    @Query var allEntries: [Entry]
    @StateObject private var locationManager = LocationManager()
    @State private var thoughtText: String = ""
    @State private var isCapturingThought: Bool = false
    @FocusState private var thoughtFieldFocused: Bool
    @State private var currentPrompt: String = ""
    @State private var selectedTags: [String] = []
    @State private var showingTagStrip: Bool = false
        @State private var frozenSuggestions: [String] = []

    var style: any AppThemeStyle { themeManager.style }

    @Query var allCollections: [Collection]

    // Most-used tags across all entries, context tags pinned to front
        var suggestedTags: [String] {
            let soloFolioTags = Set(allCollections.filter { collection in
                guard collection.isFolio else { return false }
                guard collection.filterTags.count == 1 else { return false }
                return collection.filterTypes.isEmpty &&
                       collection.filterSearchText == nil &&
                       collection.filterLocationLatitude == nil &&
                       (DateFilterRange(rawValue: collection.filterDateRange) ?? .allTime) == .allTime
            }.flatMap { $0.filterTags })
            let allNames = allEntries.flatMap { $0.tagNames }
                .filter { !$0.hasPrefix("@") && !soloFolioTags.contains($0) }
            let counts = Dictionary(allNames.map { ($0, 1) }, uniquingKeysWith: +)
            let sorted = counts
                .sorted { $0.value > $1.value }
                .map { $0.key }
                .filter { !selectedTags.contains($0) }
            let pinned = contextTags.filter { !selectedTags.contains($0) }
            let rest = sorted.filter { !pinned.contains($0) }
            return pinned + rest
        }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Tag button row + sliding strip — visible while capturing
            if isCapturingThought {
                HStack(alignment: .center, spacing: 0) {

                    // Tag toggle button
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            showingTagStrip.toggle()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.001))
                                .frame(width: 36, height: 36)
                                .glassEffect(.regular.interactive(), in: Circle())
                            Image(systemName: selectedTags.isEmpty ? "tag" : "tag.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(selectedTags.isEmpty ? style.secondaryText : style.accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 16)

                    // Tag suggestion strip — slides out from tag button
                    if showingTagStrip {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(frozenSuggestions.prefix(20), id: \.self) { tag in
                                    Button {
                                        withAnimation(.spring(duration: 0.2)) {
                                            selectedTags.append(tag)
                                        }
                                    } label: {
                                        Text(tag)
                                            .font(style.typeCaption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(style.surface)
                                            .foregroundStyle(style.secondaryText)
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule().strokeBorder(style.cardBorder, lineWidth: 0.5)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                        }
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                        )
                    }

                    Spacer()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Main bar row
            HStack(spacing: 12) {

                // Search button — full bar only, hidden while capturing
                if showFullBar && !isCapturingThought {
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
                    .transition(.scale.combined(with: .opacity))
                }

                // Thought capture field
                VStack(alignment: .leading, spacing: 6) {

                    // Selected tags inside capsule
                    if !selectedTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(selectedTags, id: \.self) { tag in
                                    Button {
                                        withAnimation(.spring(duration: 0.2)) {
                                            selectedTags.removeAll { $0 == tag }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(tag)
                                                .font(style.typeCaption)
                                            Image(systemName: "xmark")
                                                .font(.system(size: 9, weight: .bold))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(style.accent.opacity(0.15))
                                        .foregroundStyle(style.accent)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Text input row
                    HStack(spacing: 8) {
                        ZStack(alignment: .leading) {
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
                                                                        if focused {
                                                                            frozenSuggestions = suggestedTags
                                                                        } else {
                                                                            showingTagStrip = false
                                                                        }
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
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22))

                // Right button — × when capturing, + when idle (full bar only)
                if showFullBar {
                    Button {
                        if isCapturingThought {
                            resetCapture()
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                showingAddEntry.toggle()
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.001))
                                .frame(width: 44, height: 44)
                                .glassEffect(.regular.interactive(), in: Circle())
                            Image(systemName: isCapturingThought ? "xmark" : "plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(style.accent)
                                .rotationEffect(.degrees(showingAddEntry && !isCapturingThought ? 45 : 0))
                                .animation(.spring(response: 0.4, dampingFraction: 0.65), value: isCapturingThought)
                                .animation(.spring(response: 0.4, dampingFraction: 0.65), value: showingAddEntry)
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                            if !isCapturingThought {
                                showingTemplatePicker = true
                            }
                        }
                    )
                } else if isCapturingThought {
                    // Slim bar (CollectionDetailView) — × button when capturing
                    Button {
                        resetCapture()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.001))
                                .frame(width: 44, height: 44)
                                .glassEffect(.regular.interactive(), in: Circle())
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(style.accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .animation(.spring(duration: 0.25), value: isCapturingThought)
        .animation(.spring(duration: 0.25), value: showingTagStrip)
        .animation(.spring(duration: 0.25), value: selectedTags.count)
        .onAppear {
            locationManager.requestLocation()
            currentPrompt = ThoughtPrompts.random()
        }
    }

    // MARK: - Create Thought

    func createThought() {
        let trimmed = thoughtText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            thoughtFieldFocused = false
            isCapturingThought = false
            showingTagStrip = false
            return
        }

        let entry = Entry(type: .text, text: trimmed, tags: [])
        entry.tagNames = selectedTags
        if let location = locationManager.currentLocation {
            entry.captureLatitude = location.coordinate.latitude
            entry.captureLongitude = location.coordinate.longitude
            entry.captureLocationName = locationManager.currentPlaceName
        }
        modelContext.insert(entry)
        try? modelContext.save()
        SearchIndex.shared.index(entry: entry)

        thoughtText = ""
        selectedTags = []
        showingTagStrip = false
        thoughtFieldFocused = false
        isCapturingThought = false
    }

    // MARK: - Reset

    func resetCapture() {
        thoughtText = ""
        selectedTags = []
        showingTagStrip = false
        thoughtFieldFocused = false
        withAnimation(.spring(duration: 0.25)) {
            isCapturingThought = false
        }
    }
}
