// SearchIndex.swift
// Commonplace
//
// Full-text search index powered by GRDB/SQLite FTS5.
// Maintains a separate search database alongside SwiftData.
//
// Indexed fields per entry type:
//   All types:   text, tags, capture_location_name
//   Photo:       extracted_text
//   Audio:       transcript
//   Link:        link_title, markdown_content, url
//   Journal:     habit_snapshots, weather_emoji, mood_emoji, vibe_emoji
//   Location:    location_name, location_address
//   Sticky:      sticky_title, sticky_items (parsed — id:: prefix stripped)
//   Music:       music_artist, music_album
//   Media:       media_title, media_genre, media_overview
//
// Schema versioning: bump schemaVersion any time columns are added or removed.
// A version change drops and recreates the table and triggers a full backfill.
//
// Backfill strategy:
//   - On every launch, any entry with no index record gets indexed (catches missed entries)
//   - Additionally, all entries created in the last 24 hours are re-indexed
//     to catch timing issues where indexing ran before metadata was fully fetched
//     (e.g. share extension entries where link/music metadata arrives asynchronously)

import Foundation
import GRDB

class SearchIndex {
    
    // MARK: - Setup
    
    static let shared = SearchIndex()
    private var db: DatabaseQueue?
    
    private init() {
        setup()
    }
    
    // Bump this any time columns are added or removed from entry_search
    private let schemaVersion = 6
    
    private func setup() {
        do {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dbURL = docs.appendingPathComponent("search_index.db")
            db = try DatabaseQueue(path: dbURL.path)
            
            let currentVersion = UserDefaults.standard.integer(forKey: "searchIndexSchemaVersion")
            
            try db?.write { db in
                if currentVersion < schemaVersion {
                    // Schema changed — drop and recreate, backfill will re-index everything
                    try db.execute(sql: "DROP TABLE IF EXISTS entry_search")
                    UserDefaults.standard.removeObject(forKey: "searchIndexBackfilled")
                }
                try db.create(virtualTable: "entry_search", ifNotExists: true, using: FTS5()) { t in
                    t.column("entry_id")
                    // Universal fields
                    t.column("text")
                    t.column("tags")
                    t.column("capture_location_name")
                    // Photo
                    t.column("extracted_text")
                    // Audio
                    t.column("transcript")
                    // Link
                    t.column("link_title")
                    t.column("markdown_content")
                    t.column("url")
                    // Journal
                    t.column("habit_snapshots")
                    t.column("journal_emojis")
                    // Location
                    t.column("location_name")
                    t.column("location_address")
                    // Sticky
                    t.column("sticky_title")
                    t.column("sticky_items")
                    // Music
                    t.column("music_artist")
                    t.column("music_album")
                    // Media
                    t.column("media_title")
                    t.column("media_genre")
                    t.column("media_overview")
                    t.column("media_log")
                }
            }
            UserDefaults.standard.set(schemaVersion, forKey: "searchIndexSchemaVersion")
        } catch {
            print("SearchIndex setup failed: \(error)")
        }
    }
    
    // MARK: - Indexing
    
    func index(entry: Entry) {
        guard let db else { return }

        // Parse sticky items — strip the "id::" prefix so item text is searchable
                let parsedStickyItems = entry.stickyItems
                    .compactMap { item -> String? in
                        let parts = item.components(separatedBy: "::")
                        return parts.count == 2 ? parts[1] : item
                    }
                    .joined(separator: " ")

                // Parse media log — strip the "ISO8601date::" prefix so note text is searchable
                let parsedMediaLog = entry.mediaLog
                    .compactMap { item -> String? in
                        let parts = item.components(separatedBy: "::")
                        return parts.count == 2 ? parts[1] : item
                    }
                    .joined(separator: " ")

        // Journal emojis — combine weather, mood, vibe into one searchable field
        let journalEmojis = [entry.weatherEmoji, entry.moodEmoji, entry.vibeEmoji]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        do {
            try db.write { db in
                try db.execute(
                    sql: "DELETE FROM entry_search WHERE entry_id = ?",
                    arguments: [entry.id.uuidString]
                )
                try db.execute(
                    sql: """
                        INSERT INTO entry_search
                        (entry_id, text, tags, capture_location_name,
                         extracted_text, transcript,
                         link_title, markdown_content, url,
                         habit_snapshots, journal_emojis,
                         location_name, location_address,
                         sticky_title, sticky_items,
                         music_artist, music_album,
                         media_title, media_genre, media_overview, media_log)
                                                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        entry.id.uuidString,
                        // Universal
                        entry.text,
                        entry.tagNames.joined(separator: " "),
                        entry.captureLocationName ?? "",
                        // Photo
                        entry.extractedText ?? "",
                        // Audio
                        entry.transcript ?? "",
                        // Link
                        entry.linkTitle ?? "",
                        entry.markdownContent ?? "",
                        entry.url ?? "",
                        // Journal
                        entry.completedHabitSnapshots.joined(separator: " "),
                        journalEmojis,
                        // Location
                        entry.locationName ?? "",
                        entry.locationAddress ?? "",
                        // Sticky
                        entry.stickyTitle ?? "",
                        parsedStickyItems,
                        // Music
                        entry.musicArtist ?? "",
                        entry.musicAlbum ?? "",
                        // Media
                        entry.mediaTitle ?? "",
                        entry.mediaGenre ?? "",
                        entry.mediaOverview ?? "",
                        parsedMediaLog
                    ]
                )
            }
        } catch {
            print("SearchIndex index(entry:) failed: \(error)")
        }
    }
    
    func remove(entryID: UUID) {
        guard let db else { return }
        do {
            try db.write { db in
                try db.execute(
                    sql: "DELETE FROM entry_search WHERE entry_id = ?",
                    arguments: [entryID.uuidString]
                )
            }
        } catch {
            print("SearchIndex remove(entryID:) failed: \(error)")
        }
    }
    
    // MARK: - Searching
    
    func search(query: String) -> Set<UUID> {
        guard let db, !query.isEmpty else { return [] }
        do {
            // Append * so "run" matches "running", "runner" etc
            let ftsQuery = query.trimmingCharacters(in: .whitespaces) + "*"
            let rows = try db.read { db in
                try Row.fetchAll(db,
                                 sql: "SELECT entry_id FROM entry_search WHERE entry_search MATCH ?",
                                 arguments: [ftsQuery]
                )
            }
            let ids = rows.compactMap { row -> UUID? in
                guard let idString = row["entry_id"] as? String else { return nil }
                return UUID(uuidString: idString)
            }
            return Set(ids)
        } catch {
            print("SearchIndex search(query:) failed: \(error)")
            return []
        }
    }
    
    // MARK: - Backfill
    
    func backfillIfNeeded(entries: [Entry]) {
        guard let db else { return }
        do {
            // Get all entry IDs currently in the index
            let indexedIDs: Set<String> = try db.read { db in
                let rows = try Row.fetchAll(db, sql: "SELECT entry_id FROM entry_search")
                return Set(rows.compactMap { $0["entry_id"] as? String })
            }
            
            // 1. Index any entries completely missing from the index
            let missing = entries.filter { !indexedIDs.contains($0.id.uuidString) }
            if !missing.isEmpty {
                print("SearchIndex: indexing \(missing.count) missing entries")
                for entry in missing { index(entry: entry) }
            }
            
            // 2. Re-index all entries from the last 24 hours
            // This catches entries where indexing ran before async metadata
            // (link previews, music artwork etc.) had finished fetching
            let cutoff = Date().addingTimeInterval(-86400)
            let recent = entries.filter { $0.createdAt >= cutoff }
            if !recent.isEmpty {
                print("SearchIndex: re-indexing \(recent.count) recent entries to catch async metadata")
                for entry in recent { index(entry: entry) }
            }

            let total = Set(missing + recent).count
            if total == 0 {
                print("SearchIndex: all \(entries.count) entries already indexed and up to date")
            } else {
                print("SearchIndex: backfill complete — processed \(total) entries")
            }
        } catch {
            print("SearchIndex backfill failed: \(error)")
        }
    }
}
