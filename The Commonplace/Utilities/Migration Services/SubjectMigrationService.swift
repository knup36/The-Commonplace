// SubjectMigrationService.swift
// Commonplace
//
// One-time migration that promotes existing Person objects into
// typed Tag objects with subjectType == "person".
//
// For each Person:
//   1. Find the matching Tag by name (should already exist via TagMigrationService)
//   2. If no Tag exists, create one
//   3. Copy all Person fields onto the Tag
//   4. Set subjectType = "person"
//
// Safe to call repeatedly — skips Tags that already have subjectType set.
// Person objects are NOT deleted — retained in schema for safety.
// Once migration is confirmed stable, Person objects can be cleared.
//
// Run as part of startupTasks() in The_CommonplaceApp.swift,
// after TagMigrationService.

import Foundation
import SwiftData

class SubjectMigrationService {

    static let shared = SubjectMigrationService()

    @MainActor
    func migrateIfNeeded(context: ModelContext) {
        guard let persons = try? context.fetch(FetchDescriptor<Person>()),
              !persons.isEmpty else {
            print("SubjectMigrationService: no persons to migrate")
            return
        }

        let tags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        let tagsByName = Dictionary(uniqueKeysWithValues: tags.map { ($0.name, $0) })

        var migrated = 0
        var skipped = 0

        for person in persons {
            // Find or create matching Tag
            let tag: Tag
            if let existing = tagsByName[person.name] {
                // Skip if already migrated
                if existing.subjectType == "person" {
                    skipped += 1
                    continue
                }
                tag = existing
            } else {
                // Create new Tag for this person
                tag = Tag(name: person.name)
                context.insert(tag)
            }

            // Copy Person fields onto Tag
            tag.subjectType = "person"
            tag.profilePhotoPath = person.profilePhotoPath
            tag.bio = person.bio
            tag.birthdate = person.birthdate
            tag.isPinned = person.isPinned
            tag.createdAt = person.createdAt

            migrated += 1
        }

        if migrated > 0 {
            try? context.save()
            print("SubjectMigrationService: migrated \(migrated) persons to typed Tags")
        }
        if skipped > 0 {
            print("SubjectMigrationService: skipped \(skipped) already-migrated persons")
        }
        if migrated == 0 && skipped == persons.count {
            print("SubjectMigrationService: all persons already migrated")
        }
    }
}
