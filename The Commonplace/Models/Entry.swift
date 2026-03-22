// Entry.swift
// Commonplace
//
// SwiftData model representing a single captured entry (called a "page" in the UI).
// All 8 entry types share this one model, differentiated by the `type` field.
//
// Tag migration note (v1.3):
//   - `tags: [String]` has been renamed to `tagNames: [String]` to preserve
//     existing data during the Tag model migration
//   - `tags: [Tag]` is the new many-to-many relationship to Tag objects
//   - TagMigrationService reads tagNames and seeds Tag objects on first launch
//   - tagNames should be removed in a future cleanup once migration is stable
//
// UI language conventions (do not change these):
//   - Entries are called "pages" in the UI
//   - isPinned shows as "Bookmark" in the UI, not "Pin"
//   - Stickies are checklists, not to-dos

import SwiftData
import Foundation
import SwiftUI

@Model
class Entry {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var type: EntryType = EntryType.text
    var text: String = ""

    var tagNames: [String] = []
    
    var isFavorited: Bool = false
    var isPinned: Bool = false

    // Photo
    var imagePath: String? = nil
    var extractedText: String? = nil
    var visionTags: [String] = []

    // Audio
    var audioPath: String? = nil
    var transcript: String? = nil
    var duration: Double? = nil

    // Link
    var url: String? = nil
    var linkTitle: String? = nil
    var previewImagePath: String? = nil
    var markdownContent: String? = nil
    var faviconPath: String? = nil

    // Music
    var mediaArtist: String? = nil
    var mediaAlbum: String? = nil
    var previewURL: String? = nil
    var mediaArtworkPath: String? = nil
    var musicTrackID: String? = nil

    // Location entry fields
    var locationName: String? = nil
    var locationAddress: String? = nil
    var locationLatitude: Double? = nil
    var locationLongitude: Double? = nil
    var locationCategory: String? = nil

    // Capture location metadata
    var captureLatitude: Double? = nil
    var captureLongitude: Double? = nil
    var captureLocationName: String? = nil

    // Sticky / checklist
    var stickyTitle: String? = nil
    var stickyItems: [String] = []
    var stickyChecked: [String] = []

    // Journal
    var weatherEmoji: String = ""
    var moodEmoji: String = ""
    var vibeEmoji: String = ""
    var completedHabits: [String] = []
    var completedHabitSnapshots: [String] = []
    var totalHabitsAtTime: Int = 0
    var journalImageData: Data? = nil

    // Health data (fetched once for past days, live for today)
    var healthActiveCalories: Double? = nil
    var healthExerciseMinutes: Double? = nil
    var healthStandHours: Double? = nil
    var healthWorkoutName: String? = nil
    var healthWorkoutDuration: Int? = nil
    var healthWorkoutCalories: Double? = nil
    var healthDataFetched: Bool = false

    init(type: EntryType = .text, text: String = "", tags: [String] = []) {
        self.id = UUID()
        self.createdAt = Date()
        self.type = type
        self.text = text
        self.tagNames = tags
        self.isFavorited = false
        self.visionTags = []
    }
}

enum EntryType: String, Codable, CaseIterable {
    case text
    case photo
    case audio
    case link
    case journal
    case location
    case sticky
    case music

    var icon: String {
        switch self {
        case .text:     return "text.alignleft"
        case .photo:    return "photo.fill"
        case .audio:    return "waveform"
        case .link:     return "link"
        case .journal:  return "bookmark.fill"
        case .location: return "mappin.circle.fill"
        case .sticky:   return "checklist"
        case .music:    return "music.note"
        }
    }

    var displayName: String {
        switch self {
        case .text:     return "Note"
        case .photo:    return "Photo"
        case .audio:    return "Audio"
        case .link:     return "Link"
        case .journal:  return "Journal"
        case .location: return "Place"
        case .sticky:   return "List"
        case .music:    return "Music"
        }
    }

    var accentColor: Color {
        switch self {
        case .text:     return InkwellTheme.inkSecondary
        case .photo:    return InkwellTheme.collectionAccentColor(for: "#FF375F")
        case .audio:    return InkwellTheme.collectionAccentColor(for: "#FF9F0A")
        case .link:     return InkwellTheme.collectionAccentColor(for: "#0A84FF")
        case .journal:  return InkwellTheme.journalAccent
        case .location: return InkwellTheme.collectionAccentColor(for: "#30D158")
        case .sticky:   return InkwellTheme.amber
        case .music:    return InkwellTheme.accentColor(for: .music)
        }
    }

    var cardColor: Color {
        InkwellTheme.cardBackground(for: self)
    }
}
