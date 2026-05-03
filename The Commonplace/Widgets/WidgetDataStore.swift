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
    
    private static func icon(for type: String, mediaType: String? = nil, linkContentType: String? = nil) -> String {
        switch type {
        case "text":       return "text.alignleft"
        case "photo":      return "photo.fill"
        case "audio":      return "waveform"
        case "link":
            switch linkContentType {
            case "article":  return "doc.text.fill"
            case "video":    return "play.circle.fill"
            default:         return "link"
            }
        case "journal":    return "bookmark.fill"
        case "location":   return "mappin.circle.fill"
        case "sticky":     return "checklist"
        case "music":      return "music.note"
        case "media":
            switch mediaType {
            case "tv":       return "tv.fill"
            case "game":     return "gamecontroller.fill"
            case "book":     return "book.fill"
            case "podcast":  return "headphones"
            default:         return "film.fill"
            }
        case "attachment": return "paperclip"
        default:           return "square.fill"
        }
    }
    
    private static func accentHex(for type: String) -> String {
            guard let entryType = EntryType(rawValue: type) else { return "#B8A888" }
            return InkwellTheme.accentColor(for: entryType).toHex()
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
                icon: icon(for: entry.type.rawValue, mediaType: entry.mediaType, linkContentType: entry.linkContentType),
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
                print("DEBUG WidgetDataStore — snapshot written with \(snapshots.count) entries")
    }
}
