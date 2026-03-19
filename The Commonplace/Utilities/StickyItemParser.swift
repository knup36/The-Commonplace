import Foundation

// MARK: - StickyItem
// Shared model for parsed sticky checklist items.
// Used by both StickyEntryView (feed preview) and StickyDetailView (full edit).

struct StickyItem: Identifiable {
    let id: String
    let text: String
}

// MARK: - Sticky helpers

extension Entry {
    var parsedStickyItems: [StickyItem] {
        stickyItems.compactMap { raw in
            let parts = raw.components(separatedBy: "::")
            guard parts.count == 2 else { return nil }
            return StickyItem(id: parts[0], text: parts[1])
        }
    }

    func toggleStickyItem(_ id: String) {
        if stickyChecked.contains(id) {
            stickyChecked.removeAll { $0 == id }
        } else {
            stickyChecked.append(id)
        }
    }

    func deleteStickyItem(_ id: String) {
        stickyItems.removeAll { $0.hasPrefix(id) }
        stickyChecked.removeAll { $0 == id }
    }
}
