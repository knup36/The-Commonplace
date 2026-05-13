// NavigationRouter.swift
// Commonplace
//
// Central routing for entry and tag detail navigation.
// Upgraded from a static enum to a full ObservableObject in v2.15.
// iPad navigation state centralised here in v2.16 — replaces callback
// handler pattern in iPadRootView with @Published properties so all
// navigation state changes are atomic and SwiftUI-batched.
//
// The router lives in the SwiftUI environment, injected at the app root
// in ContentView. This enables programmatic navigation, deep linking via
// Widgets, Spotlight, and App Intents — all prerequisites for v3.0.
//
// Existing call sites use NavigationRouter.destination(for:) via the
// shared singleton and require no changes. New code should prefer
// @EnvironmentObject injection.
//
// iPhone safety: all @Published properties below are only read by
// iPadRootView and iPadLibraryView. iPhone never instantiates either
// view — these properties are silent on iPhone.
//
// Adding a new destination:
//   Add a new case to the switch statement in destination(for entry:)
//   and a matching case in navigate(to:). That's it.

import SwiftUI
import Combine

final class NavigationRouter: ObservableObject {

    // Shared singleton — preserves existing static call sites.
    // New code should use @EnvironmentObject instead.
    static let shared = NavigationRouter()

    // MARK: - iPad Navigation State
    //
    // Single source of truth for the iPad's navigation position.
    // iPadRootView and iPadLibraryView read these directly.
    // All three are set together in navigate(to:) so SwiftUI
    // processes them as one update cycle — no cascading re-renders.

    @Published var iPadSelectedTab: Int = 1
    @Published var iPadLibrarySegment: Int = 0
    @Published var iPadLibraryPath: NavigationPath = NavigationPath()
    @Published var iPadHomePath: NavigationPath = NavigationPath()

    // Per-tab selected entry state — owned here so the detail panel
    // can be driven from anywhere (feed cards, Chronicles, widgets).
    @Published var selectedFeedEntry: Entry? = nil
        @Published var iPadFeedResetToken: Int = 0
    @Published var selectedLibraryEntry: Entry? = nil
    @Published var selectedTodayEntry: Entry? = nil
    @Published var selectedHomeEntry: Entry? = nil
    @Published var selectedChroniclesEntry: Entry? = nil
    
    // MARK: - iPad Navigation

    /// Navigates the iPad content column to a destination.
    /// Sets tab, segment, and path atomically in one published update.
    /// No-op on iPhone — iPadRootView never exists there.
    func navigate(to destination: iPadContentDestination) {
        iPadSelectedTab = 2
        iPadLibraryPath = NavigationPath()
        switch destination {
        case .collection(let collection):
            iPadLibrarySegment = 0
            iPadLibraryPath.append(collection)
        case .folio(let folio):
            iPadLibrarySegment = 1
            iPadLibraryPath.append(folio)
        case .person(let person):
            iPadLibrarySegment = 2
            iPadLibraryPath.append(person)
        case .tag(let tagName):
            iPadLibrarySegment = 3
            iPadLibraryPath.append(tagName)
        }
    }

    /// Selects an entry into the detail panel for the current tab.
    func selectEntry(_ entry: Entry) {
        switch iPadSelectedTab {
        case 1: selectedFeedEntry = entry
        case 2: selectedLibraryEntry = entry
        case 3: selectedChroniclesEntry = entry
        case 4: selectedTodayEntry = entry
        default: selectedHomeEntry = entry
        }
    }

    // MARK: - Entry Routing

    /// Returns the appropriate detail view for a given entry.
    @ViewBuilder
    func destination(for entry: Entry) -> some View {
        if entry.tagNames.contains(WeeklyReviewTheme.weeklyReviewTag) {
            WeeklyReviewDetailView(entry: entry)
        } else {
            switch entry.type {
            case .location:   LocationDetailView(entry: entry)
            case .sticky:     StickyDetailView(entry: entry)
            case .media:      MediaDetailView(entry: entry)
            case .attachment: AttachmentDetailView(entry: entry)
            default:          EntryDetailView(entry: entry)
            }
        }
    }

    /// Returns the appropriate detail view for a given Tag.
    @ViewBuilder
    func destination(for tag: Tag) -> some View {
        if tag.isPerson {
            PersonDetailView(tag: tag)
        } else {
            TagFeedView(tag: tag.name)
        }
    }

    // MARK: - Static convenience wrappers

    @ViewBuilder
    static func destination(for entry: Entry) -> some View {
        shared.destination(for: entry)
    }

    @ViewBuilder
    static func destination(for tag: Tag) -> some View {
        shared.destination(for: tag)
    }
}

// MARK: - iPad Content Destination

enum iPadContentDestination {
    case collection(Collection)
    case folio(Collection)
    case tag(String)
    case person(Tag)
}
