// NavigationRouter.swift
// Commonplace
//
// Central routing for entry and tag detail navigation.
// Upgraded from a static enum to a full ObservableObject in v2.15.
//
// The router lives in the SwiftUI environment, injected at the app root in ContentView.
// This enables programmatic navigation, deep linking via Widgets, Spotlight, and App
// Intents, and typed Collection routing — all prerequisites for v3.0.
//
// Existing call sites use NavigationRouter.destination(for:) via the shared singleton
// and require no changes. New code should prefer @EnvironmentObject injection.
//
// Usage (existing — no change needed):
//   NavigationLink(destination: NavigationRouter.destination(for: entry)) { ... }
//   .navigationDestination(for: Entry.self) { NavigationRouter.destination(for: $0) }
//
// Usage (future — programmatic navigation):
//   @EnvironmentObject var router: NavigationRouter
//   router.navigate(to: entry)
//
// Adding a new destination:
//   Add a new case to the switch statement in destination(for entry:). That's it.

import SwiftUI
import Combine

final class NavigationRouter: ObservableObject {

    // Explicit publisher required — the compiler's automatic ObservableObject synthesis
    // gets confused by @ViewBuilder methods and fails to generate it. Declaring it
    // directly satisfies the protocol cleanly. No @Published properties are needed yet;
    // they'll be added in v3.0 when programmatic navigation state is introduced.
    let objectWillChange = PassthroughSubject<Void, Never>()

    // Shared singleton — allows existing static-style call sites to keep working
    // without any view changes. New code should use @EnvironmentObject instead.
    static let shared = NavigationRouter()

    // MARK: - Routing

    /// Returns the appropriate detail view for a given entry.
    /// Handles special cases (weekly review) before falling through to type-based routing.
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
    /// Persons route to PersonDetailView, plain tags route to TagFeedView.
    /// Folios are now Collections — use CollectionDetailView directly.
    @ViewBuilder
    func destination(for tag: Tag) -> some View {
        if tag.isPerson {
            PersonDetailView(tag: tag)
        } else {
            TagFeedView(tag: tag.name)
        }
    }

    // MARK: - Static convenience wrappers
    //
    // These preserve the NavigationRouter.destination(for:) call syntax used across
    // all existing call sites. They delegate to the shared instance so behaviour is
    // identical — no view changes required.

    @ViewBuilder
    static func destination(for entry: Entry) -> some View {
        shared.destination(for: entry)
    }

    @ViewBuilder
    static func destination(for tag: Tag) -> some View {
        shared.destination(for: tag)
    }
}
