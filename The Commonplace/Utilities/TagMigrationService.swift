// TagMigrationService.swift
// Commonplace
//
// Seeds Tag SwiftData objects from the tagNames [String] arrays on Entry.
// Called once at app launch from startupTasks() in The_CommonplaceApp.
//
// How it works:
//   1. Collects all unique tag name strings across all entries
//   2. Fetches existing Tag objects to avoid creating duplicates
//   3. Creates a new Tag object for any name that doesn't have one yet
//
// Safe to run multiple times — duplicate detection prevents double creation.
//
// Architecture note:
//   Tags use name-matching rather than SwiftData relationships.
//   Entry.tagNames: [String] remains the source of truth.
//   Tag objects provide metadata (isPinned, isProject, etc.) looked up by name.

import SwiftData
import Foundation

struct TagMigrationService {

    /// Seeds Tag objects from all unique tagNames across all entries.
    /// Should be called once at app launch on the main context.
    @MainActor
    static func migrateIfNeeded(context: ModelContext) {
        do {
            // Collect all unique tag names from all entries
            let entries = try context.fetch(FetchDescriptor<Entry>())
            let allTagNames = Set(entries.flatMap { $0.tagNames })

            guard !allTagNames.isEmpty else {
                print("TagMigrationService: no tags to migrate")
                return
            }

            // Fetch existing Tag objects so we don't create duplicates
            let existingTags = try context.fetch(FetchDescriptor<Tag>())
            let existingTagNames = Set(existingTags.map { $0.name })

            // Create Tag objects for any name that doesn't have one yet
            var created = 0
            for name in allTagNames {
                guard !existingTagNames.contains(name) else { continue }
                let tag = Tag(name: name)
                context.insert(tag)
                created += 1
            }

            if created > 0 {
                try context.save()
                print("TagMigrationService: created \(created) Tag objects from \(allTagNames.count) unique tag names")
            } else {
                print("TagMigrationService: all \(allTagNames.count) tags already exist, nothing to create")
            }

        } catch {
            print("TagMigrationService: migration failed — \(error)")
        }
    }
}
