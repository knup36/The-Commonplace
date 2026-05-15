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
            version: "3.0.1",
            title: "Begging for Scraps",
            notes: [
                "A focused polish pass on the iPad experience, with particular attentionto Scrapbook mode — which now feels like it was born on the big screen.",
                "Scrapbook mode on iPad now collapses the sidebar entirely, giving the feed the canvas space it deserves. The detail panel sits alongside at 40% width.",
                "Media ticket cards are properly sized on iPad — a ticket stub, not a banner.",
                "Attachment cards — PDF manila folders and video thumbnails — now use deliberate fixed sizing on iPad rather than stretching to fill the column.",
                "The selection outline is hidden in Scrapbook mode. The cards speak for themselves.",
                "Shot detail photos now resize dynamically when the split view divider is dragged. No more hardcoded width approximations.",
                "The weekly review card no longer disappears mid-day if left incomplete. It stays until you finish the review — as it should."
            ]
        ),
        Release(
            version: "3.0",
            title: "Koyaanisqatsi",
            notes: [
                "Koyaanisqatsi — a Hopi word meaning 'life out of balance.' This release lets you see the shape of your archive for the first time.",
                "3.0 brings 3 major new features: native iPad support, a Knowledge Graph, and Bi-Directional Linked Entries.",
                "Knowledge Graph — a new Node view in the feed toggle renders your entire archive as a living network. Entry dots, tag hubs, and person rings connected by the threads between them.",
                "Tap any tag or person hub to highlight its cluster — everything else dims, and the connections come forward.",
                "Tap a person's ring to reveal their full name, anchored to their node as you pan and zoom.",
                "Tap any entry node to open it in the detail panel — browse a cluster's entries one by one without losing your place in the graph.",
                "The graph exceeds the screen — pan and zoom to explore. Your archive has more shape than a list can show.",
                "Linked Entries — connect any two entries from their detail views. A Connected Pages section appears at the bottom of every entry, with a search sheet to find and link related captures.",
                "Links are bidirectional by default — connecting A to B also connects B to A.",
                "Full iPad-native layout across all five tabs — Feed, Library, Today, Home, and Chronicles each have a dedicated two-panel layout built for the larger screen."
            ]
        ),
        Release(
            version: "2.16",
            title: "The Snow Leopard Release",
            notes: [
            "A focused health pass across the app's most important layers before 3.0. No new features — just a faster, more reliable foundation.",
            "Share extension fully audited and cleaned up — captures feel more reliable",
            "Feed performance: tags and collections now fetched once instead of once per card",
            "Media covers and person avatars now load asynchronously — smoother feed scrolling",
            "Today tab, Journal, and Media Log now query only the entries they need instead of the entire archive",
            "Map thumbnails in the feed are now static images instead of live interactive maps",
            "Filter strip on the Feed now aligns perfectly on iPad and iPhone",
            "Ticket cards in Scrapbook mode now render correctly on iPad",
            "Readwise sync no longer blocks the main thread while downloading cover images",
            "Schema v15: typeRawValue field added to Entry for efficient type-based filtering"
            ]
        ),
        Release(
            version: "2.15",
            title: "Dot Matrix",
            notes: [
                "The Entry Calendar is a new Chronicles card that shows your entire month at a glance. Each day contains a small grid of colored dots — one for each type of thing you captured. Tap any day to see what you saved.",
                "Search now slides up as a bottom sheet, rising to meet the search button at the bottom of the screen.",
                "The Today tab is now split into three sections — Journal, Entries, and Media Log — so each part of your day has its own space.",
                "Tag pills and person avatars now navigate correctly when tapped from the Today, Home, and Chronicles tabs.",
                "Several internal improvements and tech debt items cleared ahead of v3.0."
            ]
        ),
        Release(
            version: "2.14.1",
            title: "Coming Soon",
            notes: [
                "Commonplace now tracks release dates for movies and TV series you've saved. When something you're anticipating is less than two weeks away, a card surfaces in your feed.",
                "Release dates refresh quietly in the background each week so the information stays current.",
                "The Today tab is now split into three sections — Journal, Entries, and Media Log — so each part of your day has its own space.",
                "Fixed a bug where the Weekly Review card could be suppressed by non-journal entries that shared its tag.",
                "Sound entries now show the full tags row, including people and Folio pills, matching the rest of the feed.",
                "Fixed a bug in People entry where the suggestion picker dismissed after adding the first person.",
                "Sticky title editing is now debounced — the app writes to storage after you pause, not on every keystroke."
            ]
        ),
        Release(
            version: "2.14",
            title: "Short Circuit",
            notes: [
                "Commonplace is now wired into iOS in ways it never has been before. Three new widgets live on your home screen: Recent Entries shows your latest captures at a glance, Gift Card surfaces your most recent nudge, and Memory reaches back into your archive and pulls something out for you to rediscover.",
                "Siri and Shortcuts now know about Commonplace. Ask Siri to add a note and it lands silently in your feed — no app required. You can also build automations that jump straight to your Home or Today tab.",
                "The status pickers on movie, TV, book, and game entries got a quiet upgrade. The native segmented control is gone, replaced with a sliding pill that feels like a physical switch. Small thing, but it makes editing feel more considered.",
                "Tag and person suggestions now load faster across all entry types. A bug that was causing suggestions to disappear on media entries has been fixed, and people suggestions now stay open so you can tag multiple people in one go."
            ]
        ),
        Release(
            version: "2.13",
            title: "The Gift",
            notes: [
                "Gift Cards are here. Commonplace now notices things worth surfacing — a show you started months ago, a place you saved and never visited — and offers them as small, joyful nudges when you're already in the right context.",
                "Gift Cards appear in media and location collections when something qualifies. Each card has a warm silver shimmer border so it feels special. Dismiss one and it snoozes for 30 days. Everything that fires gets archived in Chronicles under a new Gift Cards card.",
                "Three cards in this first batch: Still Watching (in-progress media gone quiet), Still On Your List (watchlist entries over 90 days old), and Still Want to Go (unvisited places over 90 days old). More cards coming in future releases.",
                "Collections filtering by sticky type can now hide fully completed lists."
            ]
        ),
        Release(
            version: "2.12",
            title: "The Sound of Music",
            notes: [
                "Your Shazamed tracks now sync automatically into Commonplace as music entries.",
                "Enable Shazam sync in Settings and Commonplace records a baseline of your existing Shazam library — only new tracks added after that point will be imported. No duplicates, no noise.",
                "Each imported track comes in with full metadata — title, artist, album, artwork, and a direct Apple Music link for playback. Entries are automatically tagged 'shazam' so you can find them instantly.",
                "Tap Sync Shazam Tracks anytime to pull in new discoveries."
            ]
        ),
        Release(
            version: "2.11",
            title: "Mr. Pink Doesn't Tip",
            notes: [
            "Commonplace now guides new users with contextual tips throughout the app.",
            "Tips appear exactly where you need them — pointing at the capture bar, the entry menu, the filter strip, the view modes toggle, and more. Each tip appears once and gets out of the way. The app explains itself without a manual.",
            "One new shortcut added - New Entry. Add to your home screen or the action button to quickly add an entry to Commonplace."
            ]
        ),
        Release(
            version: "2.10",
            title: "The Bookhouse Boys",
            notes: [
            "Books are now a first-class entry type in Commonplace.",
            "Search for any book by title via OpenLibrary — cover art, author, publish year, and page count are pulled in automatically. Track your reading with three statuses: Reading List, Reading, and Finished. Log your thoughts as you read, chapter by chapter if you like.",
            "The last major missing piece of the media collection is now complete.",
            "Attachments look nicer in Scrapbook view. PDFs live in a folder and videos are paperclipped to the background."
            ]
        ),
        Release(
            version: "2.9",
            title: "The Big Picture",
            notes: [
                "Shot entries now support up to 4 photos — capture a moment, not just a frame",
                "Photos display as a smart collage in the feed — layout adapts based on portrait or landscape orientation",
                "In the detail view, all photos appear side by side in a horizontal strip — tap any one to view full screen",
                "Scrapbook view shows multi-image shots as a stack of individual Polaroids",
                "Compact cards show a mini photo grid for multi-image shots",
                "Videos remain single-image only — clean and intentional"
            ]
        ),
        Release(
            version: "2.8",
            title: "The Rockford Files",
            notes: [
                "New entry type: Attachment — archive PDFs and videos directly in Commonplace",
                "PDFs open in a full-screen reader with pinch-to-zoom and scroll",
                "Videos play with native controls — scrub, go full screen, rotate",
                "Video attachments generate a thumbnail at import for the feed and cards",
                "Attachments are copied in to your iCloud archive — no broken references if the original moves",
                "Attachments are included in both the JSON and Markdown weekly exports",
                "Attachment filenames are fully searchable",
                "Search field now auto-focuses when opened — keyboard appears immediately"
            ]
        ),
        Release(
            version: "2.7",
            title: "Watch This",
            notes: [
                "Tag pills in detail views are now tappable — navigates to the tag feed or Folio",
                "Person avatars in detail views are now tappable — navigates to the person profile",
                "Mood Timeline rebuilt as a continuous horizontal scroll — drag through your history like a film strip; 6-month default window with Load Earlier button for older data",
                "Watch Timeline week now runs Monday–Sunday; day labels (M,T,W,Th,F,Sa,Su) added to the right edge",
                "Fix: Readwise hero images no longer overflow the screen edges",
                "Fix: Readwise highlight text no longer overflows the screen edges",
                "Fix: Weekly review now correctly includes media logged during the week regardless of when the entry was created",
                "Fix: Weekly review media list no longer capped at 5 items",
                "Fix: Media status subfilter chips in Collections now show the correct icon instead of always showing a film strip",
                "Fix: One Month Ago entry rows are now fully tappable"
            ]
        ),
        Release(
            version: "2.6",
            title: "Be Kind, Please Rewind",
            notes: [
                "Rewind — new Chronicles card; pick any date range to browse everything captured in that period with photo grid on top and slim entry rows below",
                "Chronicles cards now collapse to their header row — tap anywhere on the amber title to expand or collapse; state persists across launches",
                "Drag-to-reorder Chronicles cards via the ≡ button in the header",
                "One Month Ago redesigned — tightened to a 30–32 day window, photo grid on top, slim entry rows below, tappable overflow expands inline",
                "Tag Groups in Library — organise tags into named, collapsible groups",
                "Swipe left on any tag to move it to a group",
                "Tap Edit in the Tags toolbar to drag-reorder your groups",
                "New Group button at the bottom of the Tags list",
                "Tags segment extracted to LibraryTagsView for maintainability",
                "Sort button removed from the Tags tab — manual group order replaces sorting",
                "Fix: Habit Patterns sliding segment pill now reaches both edges cleanly",
                "Fix: Tag filter input now clears after tapping a suggestion in the Collection form",
                "Fix: Readwise entries now use today's date for createdAt instead of the Reader saved date"
            ]
        ),
        Release(
            version: "2.5",
            title: "Prydain Chronicles",
            notes: [
                "Chronicles tab fully redesigned — charcoal/silver card theme with physical bevel and drop shadow",
                "On This Day renamed to One Month Ago with a 30-day window and entry type accent colors",
                "Dog-Ears card rebuilt with compact card strips, separate Lists and Later sections, and peek affordance",
                "Stats card gains colored entry type breakdown with accent color icons",
                "Mood Timeline replaced with a 7-day line graph with color-coded mood dots",
                "Habit Patterns adds a sliding window picker — 7 days, 4 weeks, 3 months — persisted between launches",
                "Watch Timeline rebuilt as a contribution graph — tap any square to see cover art, tap the eyeball to spotlight a single title across the full year",
                "Chronicles performance pass — all card filtering pre-computed once on tab appear instead of on every render",
                "Movie and TV detail views redesigned — centered poster hero with accent color glow, overview text, metadata as free-floating text",
                "Status strip hidden in view mode and replaced with a colored inline icon and label",
                "TV gains Re-Watch and Games gain Re-Play as a fourth status",
                "Movie status simplified to Watchlist and Watched — Watching removed",
                "Podcast status removed entirely — notes and bookmarking only",
                "Journal entries can now have a photo added or changed from the Feed detail view after the day is over",
                "Audio entries now support a title field, split from body notes using the same pattern as note entries",
                "Audio player card is now themed to the entry accent color with border and shadow",
                "Library tab reordered — Collections, Folios, People, Tags",
                "Feed tag row now scrolls horizontally instead of wrapping to two lines",
                "Note titles in the feed now show up to 3 lines",
                "EntryTagRow extracted as a shared component across detail views",
                "AudioEntryView fully theme-aware, replacing all hardcoded orange",
                "Legacy tag-based folio rendering removed from feed cards"
            ]
        ),
        Release(
            version: "2.4",
            title: "Dog Day Afternoon",
            notes: [
                "Folios rebuilt on Collections — more powerful filter rules, same rich presentation",
                "Collection builder gains Collection | Folio picker — create Folios directly from scratch",
                "Folio name locked after creation, tag hiding logic updated to match new architecture",
                "Folio pills render wherever a tag matches a Folio's sole filter tag",
                "Dog-Ears Chronicles card — surfaces incomplete stickies and 'later' tagged entries",
                "Tag delete from tag feed view — removes tag from all entries with confirmation",
                "Filter chips now show all active conditions: type, tag, date, location, status",
                "Edit Collection and Edit Folio options added to detail view ··· menu",
                "FolioDetailView retired — CollectionDetailView handles all layouts",
                "Promote to Folio removed from tag feed — lives in Collection builder instead"
            ]
        ),
        Release(
            version: "2.3",
            title: "For Love of the Game",
            notes: [
                "Game support — search for any game via RAWG, with 16:9 hero art, title, release year, all platforms, and developer pulled in automatically",
                "Game status picker uses Someday / Playing / Finished instead of watch-focused labels",
                "Feed cards show GAME type label and portrait thumbnail for game entries",
                "New mediaPlatform field on Entry model — dedicated storage for game platform information",
                "Slim feed now shows square thumbnails for Shot entries with capture location when no note text is present",
                "Slim feed sticky entries show list title, inline progress bar, and completion count",
                "Slim feed journal, note, and sticky entries have improved left margin breathing room",
                "Notes section in all media detail views now correctly left-aligned"
            ]
        ),
        Release(
            version: "2.2.1",
            title: "Clean Up on Aisle Three",
            notes: [
                "Readwise highlights now render as clean paragraphs with breathing room — bullet points and quote marks removed",
                "Readwise article detail view now shows a full-bleed hero image with editorial title and action button layout",
                "Pull Quotes section header added above highlight text in Readwise entries",
                "Journal detail activity rings no longer boxed — float freely with bottom-aligned row",
                "Sticky entry input field now word wraps up to 4 lines instead of scrolling off screen",
                "Weekly Review Media Watched section now only shows entries with log activity during that specific week"
            ]
        ),
        Release(
            version: "2.2",
            title: "Is This Thing On?",
            notes: [
                "Podcast support — search for any podcast via iTunes, saved as a media entry with square artwork, publisher, genre, and listen status (Want to Listen / Listening / Finished)",
                "Feed cards show PODCAST type label and square artwork thumbnail for podcast entries",
                "Media detail view refactored into type-specific components — Movie, TV Show, and Podcast each get their own layout and metadata section",
                "New markdown export option in Settings — pick a custom date range, see a readable summary, and export. ZIP filename includes the date range",
                "Feed entry filter strip no longer has a bounding box — icons float freely on the background",
                "isScreenshot and linkedEntryIDs were missing from export/import — both now correctly included in .commonplace archives",
                "Markdown export now correctly labels Podcasts with type, status labels, and icon",
                "Star ratings in markdown export now correctly show out of 5 instead of 10",
                "Shot entries in markdown export now distinguish between Photo, Screenshot, and Video"
            ]
        ),
        Release(
            version: "2.1",
            title: "Full Frontal",
            notes: [
                "Full reading mode — a new feed view that removes all text line limits so you can read entries in their entirety while scrolling. Toggle with the page icon in the feed header",
                "Capture location now appears on feed cards in Full mode, beneath the date and time",
                "ThoughtCaptureBar is now a reusable component — it lives in the Feed as always, and now also appears at the bottom of every Collection detail view for in-context capture",
                "Tag quick-select while capturing — tap the tag button above the bar to slide out a suggestion strip of your most-used tags. Collection detail view surfaces that collection's tags first",
                "Selected tags appear as removable pills inside the capture capsule before you submit",
                "Cancel button (×) resets the entire capture state including any selected tags",
                "Media log split into two actions — + stamps a one-tap Watched entry with today's date, speech bubble opens text input for a typed thought. Tapping Watched twice in one day is silently ignored",
                "Log text input now auto-focuses the cursor when opened"
            ]
        ),
        Release(
            version: "2.0.1",
            title: "Shot. Chaser.",
            notes: [
                "Shot entries now distinguish between photos and screenshots — the feed card shows SHOT · SCREENSHOT or SHOT · PHOTO based on automatic EXIF detection",
                "Manual override in Shot detail view — tap the Photo / Screenshot toggle in edit mode to correct the detection if needed",
                "Today tab streamlined — On This Day and Stats moved exclusively to Chronicles where they belong",
                "MediaDetailView dead code removed — duplicate rating and status button implementations cleaned up",
                "Weekly Review skips weeks with no entries — no more empty review cards for weeks before you started using the app",
                "People tab now sortable by name or entry count"
            ]
        ),
        Release(
            version: "2.0",
            title: "Twin Peaks",
            notes: [
                "Scrapbook Feed — toggle from the Feed header to transform your entries into handcrafted cards. Notes float as Georgia serif, shots become Polaroids with tape strips, stickies go yellow, links clip into newspaper columns, places go full-bleed map, music becomes a DIY gig flyer, journal entries open like notebook pages",
                "Shuffle button in Scrapbook mode randomizes your archive with a stable seeded sort — same order until you shuffle again",
                "Folios — promote any tag to a named entity with its own emoji, color, and header image. Folios have a type-aware detail view with entry type counts, a photo grid, sticky cards, and a slim feed",
                "Folio header images support pan-and-pinch crop to get exactly the right framing",
                "Folios appear as silver-bordered pills in the feed, on the Home dashboard, and in a dedicated Library segment",
                "Chronicles — a new fourth tab dedicated to your past. On This Day, Mood Timeline, Your Archive stats, Watch Timeline, and Habit Patterns cards surface patterns from everything you've captured",
                "Tab bar restructured — Chronicles takes the fourth position, Search moves to the Feed capture bar",
                "Every detail view now has a clean view mode and an intentional edit mode — tap ··· to edit, no more accidental changes",
                "Bookmark indicator, person avatars, and tag pills sit inline in a single row in view mode across all detail views",
                "Music detail view redesigned — large centered artwork, track title and artist beneath, circular play and Apple Music buttons side by side",
                "Weekly Review now stacks cards for up to 8 unfinished weeks — the card persists until you complete it. Week runs Sunday through Saturday",
                "Tag and people suggestions now sort by frequency — your most-used tags surface first",
                "People can now be tagged on sticky entries",
                "HealthKit backfill no longer re-runs on every launch"
            ]
        ),
        Release(
            version: "1.16",
            title: "Jekyll and Hyde",
            notes: [
                "Detail views now default to read-only view mode — tap ··· to enter edit mode, Done to exit",
                "EditModeManager coordinates view and edit state across all detail views and shared input components",
                "Tags and people hide all editing affordances in view mode and display inline as a single horizontal row",
                "New entries automatically open in edit mode — existing entries always open in view mode",
                "Persistent thought capture bar in the Feed — a glass capsule field with rotating prompts, filter button, and add button",
                "48 curated thought prompts across six categories: Observational, Reflective, Opinionated, Curious, Creative, and Connective",
                "Weekly Review card now persists until completed — no more accidental dismissals"
            ]
        ),
        Release(
            version: "1.15",
            title: "Tight! tighttighttight",
            notes: [
                "MigrationCoordinator — a single versioned coordinator replaces five individual migration service calls at launch; migrations are tracked by version number, crash-safe, and impossible to double-run",
                "NavigationRouter — central routing replaces the global destinationView() free function; all 13 call sites now use NavigationRouter.destination(for:), pre-wired for v3.0 Folio upgrade",
                "AppLogger — structured console logging with domain prefixes across API, SwiftData, Media, and Migration paths; info logs stripped from release builds",
                "All five SwiftData models now have full schema documentation — version history, field inventory, deprecation policy, and hard rules",
                "Person model formally marked dormant with a documented safe removal process"
            ]
        ),
        Release(
            version: "1.14.1",
            title: "Been There, Done That",
            notes: [
                "Location entries now have a visited status — tap the seal badge to mark a place as Been Here",
                "The seal badge appears on every location card in the feed and in the detail view alongside your star rating",
                "All location entries default to Want to Visit — the most common reason to save a place is to remember to go",
                "Collections can now filter by visit status — build a Want to Visit list or a places archive",
                "Export and import now correctly round-trips all location and Readwise fields"
            ]
        ),
        Release(
            version: "1.14",
            title: "The Post",
            notes: [
                "Commonplace now connects to Readwise Reader — tag any article with \"commonplace\" and it appears in your feed",
                "Imported articles arrive as link entries with a rich preview, your highlights as a bullet list in the body, and the original Reader saved date",
                "New highlights are appended automatically on subsequent syncs — nothing is ever overwritten",
                "Deduplication ensures re-syncing never creates duplicate entries",
                "Add your Readwise API token in Settings → Readwise, then tap Sync Readwise whenever you want to pull in new articles",
                "API token stored securely in the iOS Keychain"
            ]
        ),
        Release(
            version: "1.13.1",
            title: "The Housemaid",
            notes: [
                "People now show as a grid of avatars — four across, with a gold ring and entry count badge on each",
                "Tag pills throughout the app now pick up the color of the entry they live on — green for places, blue for links, and so on",
                "Entry type labels are subtler now — dimmed to half opacity so they inform without dominating",
                "Tab titles got bolder — proper New York Black weight for Feed, Home, Today, Search and Collections",
                "Location detail view got a full redesign — rounded map, smaller Open in Maps button, people tagging, and a star rating right under the place name",
                "Media detail view cleaned up — status is now a slim tab bar under the poster, rating moved inline with the metadata",
                "The plus button for adding tags and people now picks up the entry color instead of a generic brown",
                "Added modifiedAt, wordCount and readingTime to every entry — groundwork for sorting, filtering and future insights",
                "Star ratings now available on Place entries",
                "Lots of small fixes and color corrections throughout"
            ]
        ),
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
