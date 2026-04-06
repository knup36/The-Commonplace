// Person.swift
// Commonplace
//
// DEPRECATED — dormant since v1.10.1.
//
// ============================================================
// SCHEMA VERSION: 1
// Last updated: v1.10.1 (deprecated)
//
// STATUS: DORMANT — do not use, do not remove yet.
//
// History:
//   v1.7   — Person model introduced for first-class contact support
//   v1.10.1 — Person merged into Tag via subjectType = "person"
//             SubjectMigrationService copies all Person objects into
//             typed Tag objects at launch. Person is no longer written to.
//
// Why it still exists:
//   SwiftData requires all models in the schema to remain present until
//   a formal migration removes them. Removing Person from the schema
//   without a migration would corrupt the ModelContainer on launch.
//
// Safe removal process (future):
//   1. Confirm SubjectMigrationService has run on all active installs
//   2. Verify no Person records remain in production data
//   3. Add a MigrationCoordinator step that deletes all Person records
//   4. Remove Person from the ModelContainer schema declaration
//   5. Delete this file
//
// DO NOT:
//   - Query this model for people — use allTags.filter { $0.isPerson }
//   - Write new Person objects — use Tag with subjectType = "person"
//   - Remove this file without following the safe removal process above
// ============================================================

import SwiftData
import Foundation

@Model
class Person {
    var id: UUID = UUID()
    var name: String = ""
    var profilePhotoPath: String? = nil
    var bio: String? = nil
    var birthdate: Date? = nil
    var createdAt: Date = Date()
    var isPinned: Bool = false

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }

    /// The tag string used in entry.tagNames to reference this person
    var tagString: String { "@\(name)" }
}
