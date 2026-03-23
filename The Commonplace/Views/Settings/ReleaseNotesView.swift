// ReleaseNotesView.swift
// Commonplace
//
// Displays app release notes accessible from Settings → About.
// Shows the latest version prominently with a full history below.
// Add new versions to the top of the `releases` array as they ship.

import SwiftUI

struct ReleaseNotesView: View {
    @EnvironmentObject var themeManager: ThemeManager
    var style: any AppThemeStyle { themeManager.style }
    var accent: Color { style.accent }

    struct Release: Identifiable {
        let id = UUID()
        let version: String
        let title: String
        let notes: [String]
    }

    let releases: [Release] = [
        Release(
            version: "1.4",
            title: "Share It",
            notes: [
                "Share Extension — save links, images, text, and music directly from any app",
                "Apple Music links captured automatically with full track metadata",
                "Screenshots and images shared from other apps save instantly",
                "Markdown archive export — download your entire journal as a ZIP",
                "Release notes — you're reading them right now"
            ]
        ),
        Release(
            version: "1.3",
            title: "The Big One",
            notes: [
                "New Home dashboard with horizontal quick-access cards",
                "Full Apple Music playback — tap to play without leaving the app",
                "Tag bookmarking — pin tags to your Home tab",
                "Inkwell theme now renders serif fonts correctly throughout",
                "Photos automatically optimized to save storage",
                "Faster feed with async image loading and smart caching",
                "Export now checks iCloud sync before saving your archive",
                "Search now indexes all entries automatically on launch"
            ]
        ),
        Release(
            version: "1.2",
            title: "Inkwell",
            notes: [
                "Inkwell — a warm dark theme inspired by leather-bound books",
                "Music entry type — save and preview Apple Music tracks",
                "Improved collection filtering and organization"
            ]
        ),
        Release(
            version: "1.1",
            title: "Collections",
            notes: [
                "Collections — organize entries with custom filters and icons",
                "Performance improvements throughout the app",
                "Faster launch and smoother scrolling"
            ]
        )
    ]

    var body: some View {
        List {
            // Latest version — prominent
            if let latest = releases.first {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Version \(latest.version)")
                                .font(style.usesSerifFonts
                                      ? .system(.title2, design: .serif)
                                      : .title2)
                                .fontWeight(.bold)
                                .foregroundStyle(style.primaryText)
                            Text("Latest")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(accent.opacity(0.15))
                                .foregroundStyle(accent)
                                .clipShape(Capsule())
                        }
                        Text(latest.title)
                            .font(style.usesSerifFonts
                                  ? .system(.subheadline, design: .serif)
                                  : .subheadline)
                            .foregroundStyle(style.secondaryText)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(latest.notes, id: \.self) { note in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "sparkle")
                                        .font(.system(size: 10))
                                        .foregroundStyle(accent)
                                        .padding(.top, 3)
                                    Text(note)
                                        .font(style.usesSerifFonts
                                              ? .system(.body, design: .serif)
                                              : .body)
                                        .foregroundStyle(style.primaryText)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(style.usesSerifFonts ? style.surface : nil)

            }

            // Previous versions
            Section {
                ForEach(releases.dropFirst()) { release in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(release.notes, id: \.self) { note in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(style.tertiaryText)
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 6)
                                    Text(note)
                                        .font(style.usesSerifFonts
                                              ? .system(.subheadline, design: .serif)
                                              : .subheadline)
                                        .foregroundStyle(style.secondaryText)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } label: {
                        HStack {
                            Text("Version \(release.version)")
                                .font(style.usesSerifFonts
                                      ? .system(.body, design: .serif)
                                      : .body)
                                .foregroundStyle(style.primaryText)
                            Spacer()
                            Text(release.title)
                                .font(.caption)
                                .foregroundStyle(style.tertiaryText)
                        }
                    }
                    .listRowBackground(style.usesSerifFonts ? style.surface : nil)
                }
            } header: {
                Text("Previous Versions")
                    .foregroundStyle(style.tertiaryText)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(style.usesSerifFonts ? .hidden : .visible)
        .background(style.usesSerifFonts ? style.background : Color(uiColor: .systemGroupedBackground))
        .navigationTitle("What's New")
        .navigationBarTitleDisplayMode(.inline)
    }
}
