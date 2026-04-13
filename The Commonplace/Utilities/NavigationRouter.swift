// NavigationRouter.swift
// Commonplace
//
// Central routing for entry detail navigation.
// Replaces the global NavigationRouter.destination(for:) free function from EntryNavigation.swift.
//
// Current implementation is a static struct — all routing logic lives in one place.
//
// Usage:
//   NavigationLink(value: entry) {
//       EntryRowView(entry: entry)
//   }
//   .navigationDestination(for: Entry.self) { entry in
//       NavigationRouter.destination(for: entry)
//   }
//
// Pre-Folio upgrade note (v3.0):
//   Before building Folios, upgrade NavigationRouter from a static struct to a
//   full ObservableObject in the SwiftUI environment. This enables type-safe
//   routing to Folio detail views by subject type, deep linking via Spotlight,
//   App Intents, and Widgets. The 13 call sites are already using
//   NavigationRouter.destination(for:) — upgrading the router itself won't
//   require touching any views.
//
// Adding a new destination:
//   Add a new case to the switch statement below. That's it.

import SwiftUI

enum NavigationRouter {

    /// Returns the appropriate detail view for a given entry.
    /// Handles special cases (weekly review) before falling through to type-based routing.
    @ViewBuilder
    static func destination(for entry: Entry) -> some View {
        if entry.tagNames.contains(WeeklyReviewTheme.weeklyReviewTag) {
            WeeklyReviewDetailView(entry: entry)
        } else {
            switch entry.type {
            case .location: LocationDetailView(entry: entry)
            case .sticky:   StickyDetailView(entry: entry)
            case .media:    MediaDetailView(entry: entry)
            default:        EntryDetailView(entry: entry)
            }
        }
    }
    /// Returns the appropriate detail view for a given Tag.
        /// Folios route to FolioDetailView, Persons route to PersonDetailView,
        /// plain tags route to TagFeedView.
        @ViewBuilder
        static func destination(for tag: Tag) -> some View {
            if tag.isFolio {
                FolioDetailView(tag: tag)
                    .environmentObject(EditModeManager())
            } else if tag.isPerson {
                PersonDetailView(tag: tag)
            } else {
                TagFeedView(tag: tag.name)
            }
        }
    }
