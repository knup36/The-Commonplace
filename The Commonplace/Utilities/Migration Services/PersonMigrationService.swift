// PersonMigrationService.swift
// Commonplace
//
// Seeds Person objects from existing @-prefixed tagNames on launch.
// Runs once on every launch — safe to call repeatedly, skips existing persons.
//
// Flow:
//   1. Scan all entry tagNames for strings starting with "@"
//   2. Collect unique person name strings (strip the "@" prefix)
//   3. For each name not already in the Person table, create a new Person object
//
// This ensures that any entries tagged with @Name before the Person model
// existed will automatically get a corresponding Person object created.
//
// Same pattern as TagMigrationService.

import SwiftData
import Foundation

struct PersonMigrationService {

    @MainActor
    static func migrateIfNeeded(context: ModelContext) {
        do {
            let entries = try context.fetch(FetchDescriptor<Entry>())
            let existingPersons = try context.fetch(FetchDescriptor<Person>())
            let existingNames = Set(existingPersons.map { $0.name })

            // Collect all unique @-prefixed tag strings across all entries
            let allPersonTagStrings = Set(
                entries.flatMap { $0.tagNames }
                    .filter { $0.hasPrefix("@") }
            )

            // Strip @ prefix and create Person objects for any missing names
            var created = 0
            for tagString in allPersonTagStrings {
                let name = String(tagString.dropFirst()) // strip "@"
                guard !name.isEmpty, !existingNames.contains(name) else { continue }
                let person = Person(name: name)
                context.insert(person)
                created += 1
            }

            if created > 0 {
                try context.save()
                print("PersonMigrationService: created \(created) Person objects from existing tags")
            } else {
                print("PersonMigrationService: no new persons to migrate")
            }
        } catch {
            print("PersonMigrationService failed: \(error)")
        }
    }
}
