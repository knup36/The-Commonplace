// MemoryDataStore.swift
// Commonplace (main app target only)
//
// Selects a random past entry and writes it to the App Group container
// as a MemorySnapshot for the Memory widget to display.
//
// Refresh policy: once per day, checked on app launch via needsRefresh.
// Eligible entries: created more than 30 days ago, not journal type.
// Photo entries: first image is copied to App Group as a thumbnail.
//
// DO NOT add this file to the widget extension target.

import Foundation
import UIKit
import WidgetKit

struct MemoryDataStore {

    static func writeSnapshotIfNeeded(from entries: [Entry]) {
        guard MemorySnapshotStore.needsRefresh else { return }
        writeSnapshot(from: entries)
    }

    static func writeSnapshot(from entries: [Entry]) {
        let cutoff = Date().addingTimeInterval(-30 * 86400)
        let eligible = entries.filter {
            $0.createdAt <= cutoff && $0.type != .journal
        }
        guard let entry = eligible.randomElement() else { return }

        // Handle photo image
        var imagePath: String? = nil
        if entry.type == .photo, let path = entry.allImagePaths.first,
           let imageData = MediaFileManager.load(path: path),
           let uiImage = UIImage(data: imageData),
           let thumbData = uiImage.jpegData(compressionQuality: 0.7) {
            imagePath = MemorySnapshotStore.saveImage(thumbData, id: entry.id.uuidString)
        }

        let snapshot = MemorySnapshot(
            id: entry.id.uuidString,
            type: entry.type.rawValue,
            title: title(for: entry),
            text: entry.text,
            icon: entry.type.icon,
            accentHex: InkwellTheme.accentColor(for: entry.type).toHex(),
            createdAt: entry.createdAt,
            imagePath: imagePath
        )

        MemorySnapshotStore.save(snapshot)
        MemorySnapshotStore.markRefreshed()
        WidgetCenter.shared.reloadTimelines(ofKind: "MemoryWidget")
    }

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
}
