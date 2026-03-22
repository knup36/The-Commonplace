// Tag.swift
// Commonplace
//
// SwiftData model representing a user-defined tag.
// Tags are first-class objects enabling pinning to Home,
// future Project conversion (v1.4), and color support.
//
// Architecture note:
//   Tags connect to entries via name matching rather than a SwiftData
//   relationship. Entry.tagNames: [String] is the source of truth for
//   which tags an entry has. Tag objects are looked up by name when
//   needed. This avoids SwiftData relationship complexity while giving
//   us all the metadata we need on tags.
//
//   To find entries for a tag: filter entries where tagNames.contains(tag.name)
//   To find tags for an entry: fetch Tags where name is in entry.tagNames
//
// Future fields (designed here, activated in later versions):
//   colorHex — user-assigned tag colors (v1.4+)
//   isProject, isCompleted, completedAt — Project conversion (v1.4)

import SwiftData
import Foundation

@Model
class Tag {
    var name: String = ""
    var isPinned: Bool = false
    var createdAt: Date = Date()

    // v1.4 Project fields — stored now, activated later
    var isProject: Bool = false
    var isCompleted: Bool = false
    var completedAt: Date? = nil

    // v1.4+ color support — optional, not used in UI yet
    var colorHex: String? = nil

    init(name: String) {
        self.name = name
        self.isPinned = false
        self.createdAt = Date()
        self.isProject = false
        self.isCompleted = false
    }
}
