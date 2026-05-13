// GraphDataService.swift
// Commonplace
//
// Serializes Entry and Tag data into a JSON payload for the Knowledge Graph.
// Called by KnowledgeGraphView before injecting data into the D3 WebView.
//
// Output shape:
//   {
//     "entries": [{ "id", "type", "color", "label", "tagNames", "linkedEntryIDs" }],
//     "tags":    [{ "id", "label", "entryCount" }]
//   }
//
// Colors are derived from DuskTheme accent colors (hex strings) — no SwiftUI
// Color conversion needed since DuskTheme stores hex constants directly.
// toHex() is used as a safety net for theme-aware color resolution.

import Foundation
import SwiftUI

struct GraphDataService {
    
    static func buildJSON(entries: [Entry], tags: [Tag], theme: AppTheme) -> String {
        let entryNodes = entries.map { entry -> [String: Any] in
            [
                "id":             entry.id.uuidString,
                "type":           entry.type.rawValue,
                "color":          entry.type.accentColor(for: theme).toHex(),
                "label":          graphLabel(for: entry),
                "tagNames":       entry.tagNames,
                "linkedEntryIDs": entry.linkedEntryIDs,
                "isPerson":       false
            ]
        }
        
        // Build tag hub nodes — exclude person tags and folio tags (handled separately)
        let personTagStrings = Set(tags.filter { $0.isPerson }.map { "@\($0.name)" })
        let folioTagStrings: Set<String> = []
        var tagCounts: [String: Int] = [:]
        for entry in entries {
            for tag in entry.tagNames {
                guard !personTagStrings.contains(tag) && !folioTagStrings.contains(tag) else { continue }
                tagCounts[tag, default: 0] += 1
            }
        }
        
        let tagNodes = tagCounts.map { name, count -> [String: Any] in
            [
                "id":         "tag-\(name)",
                "label":      name,
                "entryCount": count,
                "kind":       "tag"
            ]
        }
        
        // Person nodes
        let personNodes = tags.filter { $0.isPerson }.map { tag -> [String: Any] in
            let entryCount = entries.filter { $0.tagNames.contains("@\(tag.name)") }.count
            return [
                "id":         "person-\(tag.name)",
                "label":      tag.name,
                "entryCount": entryCount,
                "kind":       "person"
            ]
        }
        
        let payload: [String: Any] = [
                    "entries": entryNodes,
                    "tags":    tagNodes,
                    "persons": personNodes
                ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"entries\":[], \"tags\":[]}"
        }
        return json
    }
    
    private static func graphLabel(for entry: Entry) -> String {
        switch entry.type {
        case .text:       return entry.text.components(separatedBy: "\n").first ?? "Note"
        case .photo:      return entry.text.isEmpty ? "Shot" : entry.text.components(separatedBy: "\n").first ?? "Shot"
        case .audio:      return entry.text.components(separatedBy: "\n").first ?? "Sound"
        case .link:       return entry.linkTitle ?? entry.url ?? "Link"
        case .journal:
            let f = DateFormatter(); f.dateFormat = "MMM d"
            return f.string(from: entry.createdAt)
        case .location:   return entry.locationName ?? "Place"
        case .sticky:     return entry.stickyTitle ?? "List"
        case .music:      return entry.text.isEmpty ? "Music" : entry.text
        case .media:      return entry.mediaTitle ?? "Media"
        case .attachment: return entry.attachmentFilename ?? "Attachment"
        }
    }
}
