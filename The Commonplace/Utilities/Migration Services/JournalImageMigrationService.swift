// JournalImageMigrationService.swift
// Commonplace
//
// One-time migration that moves journalImageData blobs out of SwiftData
// and into MediaFileManager flat files in the media/journal subfolder.
//
// Safe to call repeatedly — skips entries that have already been migrated
// (journalImagePath already set) or have no image data.
//
// After migration, journalImageData is cleared to nil to free SwiftData storage.
// The journalImageData field is retained in the schema but no longer used.
//
// Run as part of startupTasks() in The_CommonplaceApp.swift.

import Foundation
import SwiftData

class JournalImageMigrationService {

    static let shared = JournalImageMigrationService()

    @MainActor
    func migrateIfNeeded(entries: [Entry], context: ModelContext) {
        let toMigrate = entries.filter {
            $0.type == .journal &&
            $0.journalImageData != nil &&
            $0.journalImagePath == nil
        }

        guard !toMigrate.isEmpty else {
            print("JournalImageMigrationService: nothing to migrate")
            return
        }

        print("JournalImageMigrationService: migrating \(toMigrate.count) journal images")

        for entry in toMigrate {
            guard let data = entry.journalImageData else { continue }
            do {
                let path = try MediaFileManager.save(
                    data,
                    type: .journal,
                    id: entry.id.uuidString
                )
                entry.journalImagePath = path
                entry.journalImageData = nil
                print("JournalImageMigrationService: migrated entry \(entry.id)")
            } catch {
                print("JournalImageMigrationService: failed to migrate entry \(entry.id): \(error)")
            }
        }

        try? context.save()
        print("JournalImageMigrationService: migration complete")
    }
}
