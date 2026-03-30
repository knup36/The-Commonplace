// Tag.swift
// Commonplace
//
// SwiftData model representing a user-defined tag or Subject.
//
// A plain tag (subjectType == nil) is a lightweight descriptor — a string
// with metadata like pinning and color.
//
// A Subject (subjectType != nil) is a promoted tag — a named entity that
// entries orbit around. Subjects have type-aware detail views and optional
// rich metadata. The Person model is merged into Tag as subjectType "person"
// in v1.10.1.
//
// Architecture note:
//   Tags connect to entries via name matching rather than SwiftData relationships.
//   Entry.tagNames: [String] is the source of truth. Person tags use "@" prefix
//   convention which carries forward unchanged — "@Sarah" in tagNames corresponds
//   to a Tag with name "Sarah" and subjectType "person".
//
//   To find entries for a tag:   filter entries where tagNames.contains(tag.name)
//   To find entries for a person: filter entries where tagNames.contains("@" + tag.name)
//   To find tags for an entry:   fetch Tags where name is in entry.tagNames
//
// Subject types (subjectType values):
//   nil        — plain tag, no rich metadata
//   "person"   — replaces Person model (v1.10.1)
//   "show"     — TV show Folio (v3.0)
//   "movie"    — Movie Folio (v3.0)
//   "book"     — Book Folio (v3.0)
//   "project"  — Project Folio (v3.0, uses isProject fields below)

import SwiftData
import Foundation

@Model
class Tag {
    var name: String = ""
    var isPinned: Bool = false
    var createdAt: Date = Date()

    // Project fields — stored now, activated in v3.0
    var isProject: Bool = false
    var isCompleted: Bool = false
    var completedAt: Date? = nil

    // Color support — optional
    var colorHex: String? = nil

    // Subject fields (v1.10.1+)
    // subjectType nil = plain tag. Non-nil = promoted Subject.
    var subjectType: String? = nil

    // Person subject fields — populated when subjectType == "person"
    var profilePhotoPath: String? = nil
    var bio: String? = nil
    var birthdate: Date? = nil

    // Subject emoji — shown in pill for all subject types
    var subjectEmoji: String? = nil

    init(name: String) {
        self.name = name
        self.isPinned = false
        self.createdAt = Date()
        self.isProject = false
        self.isCompleted = false
    }
}

// MARK: - Convenience

extension Tag {
    /// True if this tag is a promoted Subject
    var isSubject: Bool { subjectType != nil }

    /// True if this tag represents a person
    var isPerson: Bool { subjectType == "person" }

    /// The tag string used in entry.tagNames for person subjects
    /// Matches the existing @-prefix convention from the Person model
    var tagString: String {
        isPerson ? "@\(name)" : name
    }
}
