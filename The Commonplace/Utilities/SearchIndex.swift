import Foundation
import GRDB

class SearchIndex {
    
    // MARK: - Setup
    
    static let shared = SearchIndex()
    private var db: DatabaseQueue?
    
    private init() {
        setup()
    }
    
    private let schemaVersion = 2

    private func setup() {
        do {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dbURL = docs.appendingPathComponent("search_index.db")
            db = try DatabaseQueue(path: dbURL.path)
            
            let currentVersion = UserDefaults.standard.integer(forKey: "searchIndexSchemaVersion")
            
            try db?.write { db in
                if currentVersion < schemaVersion {
                    // Schema changed — drop and recreate
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
                    t.column("media_artist")
                    t.column("media_album")
                    t.column("sticky_title")
                    t.column("sticky_items")
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
                         markdown_content, link_title, location_name, media_artist, media_album,
                         sticky_title, sticky_items)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        entry.id.uuidString,
                        entry.text,
                        entry.tags.joined(separator: " "),
                        entry.transcript ?? "",
                        entry.extractedText ?? "",
                        entry.markdownContent ?? "",
                        entry.linkTitle ?? "",
                        entry.locationName ?? "",
                        entry.mediaArtist ?? "",
                        entry.mediaAlbum ?? "",
                        entry.stickyTitle ?? "",                    // ADD THIS
                        entry.stickyItems.joined(separator: " ")   // ADD THIS
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
        let key = "searchIndexBackfilled"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        print("SearchIndex: starting backfill for \(entries.count) entries")
        for entry in entries {
            index(entry: entry)
        }
        UserDefaults.standard.set(true, forKey: key)
        print("SearchIndex: backfill complete")
    }
}
