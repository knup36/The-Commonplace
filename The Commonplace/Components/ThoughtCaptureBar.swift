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
// Parameters:
//   showFullBar         — when false, hides search and add buttons (CollectionDetailView mode)
//   showingAddEntry     — binding to FeedView's add entry card toggle
//   showingTemplatePicker — binding to FeedView's template picker toggle
//   onEntryCreated      — called after a thought is saved; caller appends to nav path if needed

import SwiftUI
import SwiftData
import CoreLocation

struct ThoughtCaptureBar: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var themeManager: ThemeManager

    var showFullBar: Bool = true
    @Binding var showingAddEntry: Bool
    @Binding var showingTemplatePicker: Bool

    @StateObject private var locationManager = LocationManager()
    @State private var thoughtText: String = ""
    @State private var isCapturingThought: Bool = false
    @FocusState private var thoughtFieldFocused: Bool
    @State private var currentPrompt: String = ""

    var style: any AppThemeStyle { themeManager.style }

    var body: some View {
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
            .animation(.spring(duration: 0.25), value: isCapturingThought)
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
            }

            // MARK: - Reset

            func resetCapture() {
                thoughtText = ""
                thoughtFieldFocused = false
                withAnimation(.spring(duration: 0.25)) {
                    isCapturingThought = false
                }
            }
        }
