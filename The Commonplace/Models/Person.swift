// Person.swift
// Commonplace
//
// SwiftData model representing a person — a first-class contact object.
// People are a richer version of tags, with metadata like photo, bio, and birthdate.
//
// Architecture note:
//   People connect to entries via name matching, same pattern as Tag.
//   Entry.tagNames stores "@Sarah" (with @ prefix as namespace).
//   Person.name stores "Sarah" (without @).
//
//   To find entries for a person: filter entries where tagNames.contains("@" + person.name)
//   To find people for an entry: fetch Person objects where "@" + name is in entry.tagNames
//
//   The @ prefix is an internal namespace — users never type or see it.
//   They interact with people via a dedicated PersonInputView section on entry detail views.
//
// Profile photos are stored via MediaFileManager, same pattern as media cover art.

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
