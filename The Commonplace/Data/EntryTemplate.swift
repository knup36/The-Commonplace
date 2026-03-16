import Foundation

struct EntryTemplate: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let description: String
    let type: EntryType
    let defaultTags: [String]
    let defaultText: String
    let focusURL: Bool

    static let all: [EntryTemplate] = [
        EntryTemplate(
            name: "Watchlist",
            emoji: "🎬",
            description: "Save a movie, show, or video to watch later",
            type: .link,
            defaultTags: ["watchlist"],
            defaultText: "",
            focusURL: true
        ),
        EntryTemplate(
            name: "Book",
            emoji: "📚",
            description: "Log a book you're reading or want to read",
            type: .text,
            defaultTags: ["reading"],
            defaultText: "",
            focusURL: false
        ),
        EntryTemplate(
            name: "Shopping List",
            emoji: "🛒",
            description: "Create a checklist for shopping",
            type: .sticky,
            defaultTags: ["shopping"],
            defaultText: "",
            focusURL: false
        ),
        EntryTemplate(
            name: "Idea",
            emoji: "💡",
            description: "Capture a thought or idea quickly",
            type: .text,
            defaultTags: ["ideas"],
            defaultText: "",
            focusURL: false
        ),
        EntryTemplate(
            name: "Save for Later",
            emoji: "🔖",
            description: "Bookmark a link to read or revisit",
            type: .link,
            defaultTags: ["save-for-later"],
            defaultText: "",
            focusURL: true
        )
    ]
}
