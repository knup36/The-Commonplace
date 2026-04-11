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
//   nil             — plain tag, no rich metadata
//   "person"        — replaces Person model (v1.10.1)
//   "folioGeneric"  — generic Folio (v2.0) — promoted tag with type-aware layout
//   "folioMovie"    — Movie Folio (v3.0)
//   "folioShow"     — TV Show Folio (v3.0)
//   "folioBook"     — Book Folio (v3.0)
//   "folioPlace"    — Place Folio (v3.0)
//   "folioBand"     — Band/Artist Folio (v3.0)

// ============================================================
// SCHEMA VERSION: 2
// Last updated: v1.10.1
//
// Schema change policy: same as Entry.swift — optional fields safe to add
// at any time. Never remove fields without deprecating first.
//
// Field version history:
//   v1.3  — name, isPinned, createdAt
//   v1.3  — colorHex
//   v1.7  — isProject, isCompleted, completedAt (stored now, activated v3.0)
//   v1.10.1 — subjectType, profilePhotoPath, bio, birthdate, subjectEmoji
//
// Architecture rules:
//   - NEVER use SwiftData relationships between Tag and Entry —
//     ModelContainer crashes. Always use name matching.
//   - "@" prefix in tagNames is an internal namespace for person tags —
//     never expose in UI, filter from all tag display
//   - Query persons via allTags.filter { $0.isPerson } —
//     do NOT query the dormant Person model
//
// Deprecated models:
//   Person — dormant since v1.10.1, merged into Tag via subjectType.
//            Safe to remove after SubjectMigrationService confirmed stable.
// ============================================================

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

    /// True if this tag has been promoted to any Folio type
    var isFolio: Bool { subjectType?.hasPrefix("folio") == true }

    /// True if this tag is a generic Folio (v2.0)
    var isGenericFolio: Bool { subjectType == "folioGeneric" }

    /// Display name for Folio — capitalizes words and replaces hyphens/underscores with spaces
    /// e.g. "warped-2026" → "Warped 2026"
    var folioDisplayName: String {
        name
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// The tag string used in entry.tagNames for person subjects
    /// Matches the existing @-prefix convention from the Person model
    var tagString: String {
        isPerson ? "@\(name)" : name
    }
}
