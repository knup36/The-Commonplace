// CommonplaceTips.swift
// Commonplace
//
// Defines all TipKit tips used throughout the app.
// Each tip appears once and never resurfaces after being dismissed.
//
// Tips are organized by view:
//   - EntryDetailView:  EllipsisMenuTip
//   - FeedView:         CaptureBarTip, ViewModesTip, FilterStripTip
//   - HomeView:         BookmarkTip
//   - LibraryView:      OrganizationTip
//   - ChroniclesView:   ChroniclesTop

import TipKit

// MARK: - Entry Detail

struct EllipsisMenuTip: Tip {
    var title: Text {
        Text("Entry Options")
    }
    var message: Text? {
        Text("Tap ••• to edit, bookmark, or delete an entry. Bookmarked entries are pinned to your Home tab.")
    }
    var image: Image? {
        Image(systemName: "ellipsis.circle")
    }
}

// MARK: - Feed

struct SearchBarTip: Tip {
    @Parameter
    static var feedIsActive: Bool = false

    var title: Text {
        Text("Search Everything")
    }
    var message: Text? {
        Text("Tap the magnifying glass to search across all your entries — by title, tag, content, or type.")
    }
    var image: Image? {
        Image(systemName: "magnifyingglass")
    }
    var rules: [Rule] {
        [#Rule(Self.$feedIsActive) { $0 == true }]
    }
}

struct QuickCaptureTip: Tip {
    @Parameter
    static var searchTipDismissed: Bool = false

    var title: Text {
        Text("Quick Capture")
    }
    var message: Text? {
        Text("Type a thought directly into the bar and hit send. It becomes a note entry instantly — no extra steps.")
    }
    var image: Image? {
        Image(systemName: "text.bubble")
    }
    var rules: [Rule] {
        [#Rule(Self.$searchTipDismissed) { $0 == true }]
    }
}

struct CaptureBarTip: Tip {
    @Parameter
    static var quickCaptureTipDismissed: Bool = false

    var title: Text {
        Text("Add Any Entry Type")
    }
    var message: Text? {
        Text("Tap + to capture a note, photo, sound, link, location, and more. Long press + to use a template.")
    }
    var image: Image? {
        Image(systemName: "plus.circle")
    }
    var rules: [Rule] {
        [#Rule(Self.$quickCaptureTipDismissed) { $0 == true }]
    }
}

struct ViewModesTip: Tip {
    var title: Text {
        Text("Change How You Browse")
    }
    var message: Text? {
        Text("Switch between Feed, Scrapbook, and Chronicle views to see your entries in a whole new light.")
    }
    var image: Image? {
        Image(systemName: "rectangle.grid.1x2")
    }
    var rules: [Rule] {
        [#Rule(SearchBarTip.$feedIsActive) { $0 == true }]
    }
}

struct FilterStripTip: Tip {
    var title: Text {
        Text("Filter Your Feed")
    }
    var message: Text? {
        Text("Tap an icon in the filter strip to show only that type of entry — notes, photos, music, and more.")
    }
    var image: Image? {
        Image(systemName: "line.3.horizontal.decrease")
    }
}

// MARK: - Home

struct BookmarkTip: Tip {
    var title: Text {
        Text("Your Pinned Entries")
    }
    var message: Text? {
        Text("Bookmark any entry from its ••• menu and it will appear here on your Home tab for quick access.")
    }
    var image: Image? {
        Image(systemName: "bookmark.fill")
    }
}

// MARK: - Library

struct OrganizationTip: Tip {
    var title: Text {
        Text("How Commonplace is Organized")
    }
    var message: Text? {
        Text("Tags label your entries. Folios group related entries into a curated collection — like a topic, project, or place. Collections are smart filters that match entries automatically. People lets you associate entries with the people in your life.")
    }
    var image: Image? {
        Image(systemName: "tray.2")
    }
}

// MARK: - Today

struct TodayViewTip: Tip {
    var title: Text {
        Text("Your Daily Home Base")
    }
    var message: Text? {
        Text("Today is where your daily journal lives — it resets every morning. Recently captured entries appear here, along with anything you're currently watching, reading, or playing. Tap them to log a note or mark them as finished.")
    }
    var image: Image? {
        Image(systemName: "sun.horizon")
    }
}

// MARK: - Chronicles

struct ChroniclesTop: Tip {
    var title: Text {
        Text("Your Archive, Reflected")
    }
    var message: Text? {
        Text("Chronicles surfaces patterns from everything you've captured — memories from this day in past years, mood trends, habit streaks, and more. It gets richer the longer you use Commonplace.")
    }
    var image: Image? {
        Image(systemName: "calendar")
    }
}
