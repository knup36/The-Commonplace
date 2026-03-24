// SearchIndex.swift
// Commonplace
//
// Full-text search index powered by GRDB/SQLite FTS5.
// Maintains a separate search database alongside SwiftData.
//
// Indexed fields per entry:
//   text, tags, transcript, extracted_text, markdown_content,
//   link_title, location_name, music_artist, music_album,
//   sticky_title, sticky_items, media_title, media_genre
//
// Schema versioning: bump schemaVersion any time columns are added or removed.
// A version change drops and recreates the table and triggers a full backfill.
//
// Backfill strategy:
//   - On every launch, any entry with no index record gets indexed (catches missed entries)
//   - Additionally, all entries created or modified in the last 24 hours are re-indexed
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
    private let schemaVersion = 4
    
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
                    t.column("text")
                    t.column("tags")
                    t.column("transcript")
                    t.column("extracted_text")
                    t.column("markdown_content")
                    t.column("link_title")
                    t.column("location_name")
                    t.column("music_artist")
                    t.column("music_album")
                    t.column("sticky_title")
                    t.column("sticky_items")
                    t.column("media_title")
                    t.column("media_genre")
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
        do {
            try db.write { db in
                try db.execute(
                    sql: "DELETE FROM entry_search WHERE entry_id = ?",
                    arguments: [entry.id.uuidString]
                )
                try db.execute(
                    sql: """
                        INSERT INTO entry_search
                        (entry_id, text, tags, transcript, extracted_text,
                         markdown_content, link_title, location_name, music_artist, music_album,
                         sticky_title, sticky_items, media_title, media_genre)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        entry.id.uuidString,
                        entry.text,
                        entry.tagNames.joined(separator: " "),
                        entry.transcript ?? "",
                        entry.extractedText ?? "",
                        entry.markdownContent ?? "",
                        entry.linkTitle ?? "",
                        entry.locationName ?? "",
                        entry.musicArtist ?? "",
                        entry.musicAlbum ?? "",
                        entry.stickyTitle ?? "",
                        entry.stickyItems.joined(separator: " "),
                        entry.mediaTitle ?? "",
                        entry.mediaGenre ?? ""
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
