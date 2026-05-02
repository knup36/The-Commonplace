// WidgetDataStore.swift
// Commonplace (main app target only)
//
// Writes a WidgetPayload to the App Group container whenever entries
// change, then reloads all widget timelines so iOS re-renders immediately.
//
// Call WidgetDataStore.writeSnapshot(from: entries) after any entry
// create, update, or delete. Entries should already be sorted by
// createdAt descending — we take the first 6.
//
// DO NOT add this file to the widget extension target.
// The widget reads via WidgetSnapshotStore (in WidgetSnapshot.swift).

import Foundation
import WidgetKit

struct WidgetDataStore {

    // MARK: - Icon mapping
    //
    // Maps EntryType rawValues to SF Symbol names.
    // Duplicates EntryType.icon to avoid importing the full model in future targets.

    private static func icon(for type: String) -> String {
            switch type {
            case "text":       return "text.alignleft"
            case "photo":      return "photo.fill"
            case "audio":      return "waveform"
            case "link":       return "link"
            case "journal":    return "bookmark.fill"
            case "location":   return "mappin.circle.fill"
            case "sticky":     return "checklist"
            case "music":      return "music.note"
            case "media":      return "film.fill"
            case "attachment": return "paperclip"
            default:           return "square.fill"
            }
        }

        private static func accentHex(for type: String) -> String {
            switch type {
            case "text":       return "#A0A0A0"
            case "photo":      return "#E57373"
            case "audio":      return "#FF9800"
            case "link":       return "#64B5F6"
            case "journal":    return "#BA68C8"
            case "location":   return "#66BB6A"
            case "sticky":     return "#FFD60A"
            case "music":      return "#E57373"
            case "media":      return "#FF7043"
            case "attachment": return "#C8C0A0"
            default:           return "#A0A0A0"
            }
        }

    // MARK: - Title extraction
    //
    // Pulls the most meaningful title field for each entry type.
    // Falls back to nil — the widget will use entry.text preview instead.

    private static func title(for entry: Entry) -> String? {
            switch entry.type {
            case .text:
                return entry.text.components(separatedBy: "\n").first.flatMap { $0.isEmpty ? nil : $0 }
            case .media:     return entry.mediaTitle
            case .link:      return entry.linkTitle
            case .location:  return entry.locationName
            case .sticky:    return entry.stickyTitle
            case .music:
                if let artist = entry.musicArtist, let album = entry.musicAlbum {
                    return "\(artist) — \(album)"
                }
                return entry.musicArtist
            default:         return nil
            }
        }

    // MARK: - Write

    /// Convert the most recent entries to snapshots and write to App Group.
    /// Call this after any entry create, update, or delete.
    /// - Parameter entries: All entries sorted by createdAt descending.
    static func writeSnapshot(from entries: [Entry]) {
        let snapshots = entries.prefix(6).map { entry in
                    WidgetEntrySnapshot(
                        id: entry.id.uuidString,
                        type: entry.type.rawValue,
                        text: entry.text,
                        title: title(for: entry),
                        createdAt: entry.createdAt,
                        icon: icon(for: entry.type.rawValue),
                        accentHex: accentHex(for: entry.type.rawValue)
                    )
                }

        let payload = WidgetPayload(
            snapshots: Array(snapshots),
            updatedAt: Date()
        )

        guard let url = WidgetSnapshotStore.fileURL else { return }

        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: url, options: .atomic)
        }

        // Tell iOS to re-render all Commonplace widgets immediately
        WidgetCenter.shared.reloadAllTimelines()
    }
}
