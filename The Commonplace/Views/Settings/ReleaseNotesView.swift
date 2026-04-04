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
            version: "1.13",
            title: "Dressed for Success",
            notes: [
                "The entire visual system was rebuilt from the ground up — every color, font, and spacing value now flows through a single theme system",
                "Nothing is hardcoded anywhere in the app. Tweaking a color or font size now happens in one place and ripples everywhere automatically",
                "A new type scale brings more intentional typography — New York serif for titles and hero text, SF Rounded for body and UI, with proper sizing at every level",
                "The Dusk theme is available to try in Settings — early form, with more polish coming",
                "Every entry type card color now derives from a single source of truth per type, per theme — switching themes is instant and correct on every screen",
                "New collections now appear immediately in the Library without needing a restart",
                "Note entries open in view mode when revisiting — the keyboard no longer jumps up uninvited",
                "This one was all under the hood. The app deserved it."
            ]
        ),
        Release(
            version: "1.12.1",
            title: "Un-Stuck",
            notes: [
                "Stickies are completely redesigned — input and list are fully separated, eliminating the doubled-text glitch that's been there since the beginning",
                "Tap any item to edit it, or tap the input bar at the bottom to add — the keyboard appears instantly with no delay",
                "Long-press any unchecked item to drag and reorder",
                "Checked items sink to the bottom with strikethrough, swipe to delete any item",
                "Weekly Review data now lives in dedicated fields instead of being hidden inside your note text — a rule that applies to all future entry types",
                "Adding a new person to an entry now appears in the People list immediately, no restart needed",
                "Renaming a person no longer detaches them from their entries — all connections update automatically"
            ]
        ),
        Release(
            version: "1.12",
            title: "Vidiots",
            notes: [
                "Sound entries are completely reimagined — ambient capture with animated waveforms and a persistent mini player that floats above the tab bar",
                "Playback persists while you scroll the feed or switch tabs — your birds keep singing",
                "Shot entries now support video clips from your camera roll — vertical video, correct aspect ratio, audio included",
                "Video shots show a thumbnail with play button in the feed and play inline in the detail view",
                "Links now show their content type — Article and Video subtypes appear in the entry label at reduced opacity",
                "Shot entries show Photo or Video subtype in the entry label the same way"
            ]
        ),
        Release(
            version: "1.11",
            title: "A Link to the Past",
            notes: [
                "Links are now smarter — articles and videos are automatically detected when you save a URL",
                "A new content type selector on every link entry lets you switch between Generic, Article and Video",
                "Article mode shows an excerpt of the saved content right in the detail view",
                "YouTube links shared from the YouTube app now save correctly as links instead of notes",
                "Photos are now called Shots",
                "Audio is now called Sound"
            ]
        ),
        Release(
            version: "1.10.1",
            title: "Ordinary People",
            notes: [
                "People now show their real photos in entry cards — tap any entry tagged with a person and you'll see their avatar with the gold ring",
                "People are now part of the same system as tags — a cleaner architecture that sets up future features",
                "Your existing people and all their photos, bios and birthdays carried over automatically"
            ]
        ),
        Release(
            version: "1.10",
            title: "On Any Sunday",
            notes: [
                "Weekly Review is here — every Sunday, a prompt card appears in Today inviting you to reflect on your week",
                "See everything you captured: entries by type, habits with colour-coded completion, health summary, people, tags, music and media",
                "Three reflection prompts guide you through your highlight, what to carry forward, and what you're grateful for",
                "Export your week as a Markdown archive before finishing — a permanent plain-text record of your life",
                "Completed reviews appear in the feed as a distinct purple and gold card, and open into a beautiful read-only summary view"
            ]
        ),
        Release(
            version: "1.9.1",
            title: "A Quiet Place",
            notes: [
                "Journal photos now sync properly to iCloud — they were previously stored in the database which was slow and unreliable",
                "The share sheet now appears instantly — no more waiting while it tries to fetch metadata",
                "You now choose what type of entry to save when sharing — Link, Note, Music, Photo, Place and more",
                "Bookmarks, health data, and journal photos now survive a full backup and restore",
                "Fixed a bug where deleting a sticky list would show a confirmation but not actually delete it"
            ]
        ),
        Release(
            version: "1.9",
            title: "The Moody Blues",
            notes: [
                "Your journal entries now show your activity rings and workout for that day — populated automatically from Apple Health",
                "Mood gets a serious upgrade — 18 options, each with a vibe label that shows in the journal header when set",
                "New mood timeline in Today — a 14-day chart of your emotional highs and lows, tap any emoji to jump to that journal entry",
                "Search now surfaces entries where someone is tagged above entries that just mention them — much more relevant results",
                "Tap 'See all results' in search to see the full ranked list",
                "Added windy weather 🌬️"
            ]
        ),
        Release(
            version: "1.8.1",
            title: "The Silk Spectre",
            notes: [
                "Scrolling through the feed is noticeably smoother",
                "Swipe to delete is gone — entries are too precious to delete by accident. Find delete in the ··· menu on any entry.",
                "Every entry now has a ··· menu with a bookmark button sitting right alongside it in the toolbar",
                "Bookmarking a collection in the Library and dragging to reorder now sticks correctly",
                "Card shadows on the Home dashboard are back where they belong"
            ]
        ),
        Release(
            version: "1.8",
            title: "Search Party",
            notes: [
                "Search is now its own tab — find anything across the entire app instantly",
                "Results grouped by People, Tags, Collections, and Entries",
                "Live results appear as you type",
                "Recent searches saved and shown when you open Search",
                "Tap any result to jump directly to that person, tag, collection, or entry"
            ]
        ),
        Release(
            version: "1.7.1",
            title: "The Wolf, The Fixer",
            notes: [
                "Typing in Inkwell theme now correctly shows the serif font in real time",
                "Keyboard no longer covers text fields — content stays comfortably visible while typing",
                "Home tab redesigned as a bookmarks dashboard — Collections, Entries, People, and Tags each get their own section",
                "Favorites retired — everything is now a Bookmark for simplicity",
                "Person detail page redesigned with centered avatar, gold ring, and elegant formal layout",
                "Profile photos can now be cropped when setting a person's avatar",
                "Media detail view now shows proper rectangular movie and TV posters",
                "Sticky entries improved — new items animate in at the top, title field jumps straight to Add Item, return key clears correctly"
            ]
        ),
        Release(
            version: "1.7",
            title: "Power to the People",
            notes: [
                "Tag people on any entry using the new People section on entry detail views",
                "People appear in the Library tab alongside Collections and Tags",
                "Each person gets a full detail view with a photo background, bio, and birthday",
                "Tap Edit to update a person's photo, name, bio, and birthday",
                "All entries tagged with a person are collected on their detail page",
                "People are automatically created the first time you tag someone"
            ]
        ),
        Release(
            version: "1.6.1",
            title: "Under the Hood",
            notes: [
                "Search is now dramatically more complete — location, habits, journal emojis, link URLs, and media descriptions are all searchable",
                "Photos shared via the share extension now get text extracted automatically",
                "Location now appears correctly on entries saved via the share extension",
                "Importing an archive now makes entries immediately searchable",
                "Importing an archive now correctly restores all tags",
                "Bookmark and favorite buttons added to all entry detail views",
                "Media entry status and star rating now respond instantly with no lag"
            ]
        ),
        Release(
            version: "1.6",
            title: "Good Morning. How are you?",
            notes: [
                "Daily journaling prompts — set your weather, mood, and vibe to unlock two personalized prompts each morning",
                "Prompts are generated by Claude based on your emoji combination — completely private, only three characters are ever sent",
                "One prompt to reflect, one prompt to act — dismiss for the day if you're not feeling it",
                "Settings moved to the Home tab for easier access",
                "Settings is now a full page instead of a sheet — export and import work much more reliably",
                "Habits get their own dedicated page with drag-to-reorder"
            ]
        ),
        Release(
            version: "1.5",
            title: "I'll Have What She's Having",
            notes: [
                "Media entry type — track movies and TV shows you're watching",
                "Search any title and pull in cover art, genre, runtime, and more automatically",
                "Mark anything as Want to Watch, In Progress, or Finished",
                "Rate what you've watched with a five star rating",
                "Keep a running log of thoughts as you watch",
                "Filter collections by watch status to build your perfect watchlist",
                "Share extension entries now appear in search immediately"
            ]
        ),
        Release(
            version: "1.4",
            title: "Sharing is Caring",
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
            title: "Big Kahuna Burger",
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
            title: "Music To My Ears",
            notes: [
                "Inkwell — a warm dark theme inspired by leather-bound books",
                "Music entry type — save and preview Apple Music tracks",
                "Improved collection filtering and organization"
            ]
        ),
        Release(
            version: "1.1",
            title: "Gotta Catch 'em All",
            notes: [
                "Collections — organize entries with custom filters and icons",
                "Performance improvements throughout the app",
                "Faster launch and smoother scrolling"
            ]
        ),
        Release(
            version: "1.0",
            title: "Now Presenting!",
            notes: [
                "Initial Release"
            ]
        ),
    ]
    
    var body: some View {
        List {
            // Latest version — prominent
            if let latest = releases.first {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Version \(latest.version)")
                                .font(style.typeTitle2)
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
                            .font(style.typeBodySecondary)
                            .foregroundStyle(style.secondaryText)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(latest.notes, id: \.self) { note in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "sparkle")
                                        .font(.system(size: 10))
                                        .foregroundStyle(accent)
                                        .padding(.top, 3)
                                    Text(note)
                                        .font(style.typeBody)
                                        .foregroundStyle(style.primaryText)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(style.surface)
                
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
                                        .font(style.typeBodySecondary)
                                        .foregroundStyle(style.secondaryText)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } label: {
                        HStack {
                            Text("Version \(release.version)")
                                .font(style.typeBody)
                                .foregroundStyle(style.primaryText)
                            Spacer()
                            Text(release.title)
                                .font(.caption)
                                .foregroundStyle(style.tertiaryText)
                        }
                    }
                    .listRowBackground(style.surface)
                }
            } header: {
                Text("Previous Versions")
                    .foregroundStyle(style.tertiaryText)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(style.background)
        .navigationTitle("What's New")
        .navigationBarTitleDisplayMode(.inline)
    }
}
