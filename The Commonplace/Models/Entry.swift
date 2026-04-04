// Entry.swift
// Commonplace
//
// SwiftData model representing a single captured entry (called a "page" in the UI).
// All 9 entry types share this one model, differentiated by the `type` field.
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
//
// Media entry note (v1.5):
//   - Music fields use `musicArtist`, `musicAlbum`, `musicArtworkPath` naming
//     (renamed from `mediaArtist` etc. to avoid collision with the new .media type)
//   - New .media fields use `tmdb*` prefix for API-sourced data and `mediaTitle`,
//     `mediaType`, `mediaStatus`, `mediaRating`, `mediaLog` for user-facing fields

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

    // Photo / Shot (v1.12 — extended to support video clips)
    var imagePath: String? = nil
    var extractedText: String? = nil
    var visionTags: [String] = []
    var videoPath: String? = nil
    var videoDuration: Double? = nil
    var videoThumbnailPath: String? = nil

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
    var linkContentType: String? = nil  // "article", "video", nil = generic

    // Music (renamed from media* prefix in v1.5 to avoid collision with .media entry type)
    var musicArtist: String? = nil
    var musicAlbum: String? = nil
    var previewURL: String? = nil
    var musicArtworkPath: String? = nil
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
    var journalImagePath: String? = nil

    // Health data (fetched once for past days, live for today)
    var healthActiveCalories: Double? = nil
    var healthExerciseMinutes: Double? = nil
    var healthStandHours: Double? = nil
    var healthWorkoutName: String? = nil
    var healthWorkoutDuration: Int? = nil
    var healthWorkoutCalories: Double? = nil
    var healthDataFetched: Bool = false

    // Media (movies & TV — v1.5)
    // mediaType: "movie" or "tv"
    // mediaStatus: "wantTo", "inProgress", or "finished"
    // mediaLog: timestamped notes, stored as "ISO8601date::note text" strings
    var mediaTitle: String? = nil
    var mediaType: String? = nil
    var mediaYear: String? = nil
    var mediaGenre: String? = nil
    var mediaOverview: String? = nil
    var mediaCoverPath: String? = nil
    var mediaStatus: String? = nil
    var mediaRating: Int? = nil
    var mediaLog: [String] = []
    var tmdbID: Int? = nil
    var mediaRuntime: Int? = nil  // minutes — movies only
    var mediaSeasons: Int? = nil  // season count — TV only
    
    // Weekly Review (v1.12.1)
    // Dedicated fields replacing key:value encoding in entry.text
    var weeklyReviewHighlight: String? = nil
    var weeklyReviewCarryForward: String? = nil
    var weeklyReviewGratitude: String? = nil
    var weeklyReviewStats: Data? = nil  // JSON encoded stats (entry count, habits, mood, calories, people, tags, music, media)
    
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
    case media

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
        case .media:    return "film.fill"
        }
    }

    var displayName: String {
        switch self {
        case .text:     return "Note"
        case .photo:    return "Shot"
        case .audio:    return "Sound"
        case .link:     return "Link"
        case .journal:  return "Journal"
        case .location: return "Place"
        case .sticky:   return "List"
        case .music:    return "Music"
        case .media:    return "Media"
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
            case .media:    return InkwellTheme.collectionAccentColor(for: "#FF3B30")
            }
        }

        var cardColor: Color {
            InkwellTheme.cardBackground(for: self)
        }

        // Theme-aware versions — use these in all new and updated views
        func accentColor(for theme: AppTheme) -> Color {
            switch theme {
            case .dusk:    return DuskTheme.accentColor(for: self)
            case .inkwell: return accentColor
            case .system:  return accentColor
            }
        }

    func cardColor(for theme: AppTheme) -> Color {
            switch theme {
            case .dusk:    return DuskTheme.cardBackground(for: self)
            case .inkwell: return cardColor
            case .system:  return cardColor
            }
        }

        func detailAccentColor(for theme: AppTheme) -> Color {
            switch theme {
            case .dusk:    return DuskTheme.detailAccentColor(for: self)
            case .inkwell: return accentColor
            case .system:  return accentColor
            }
        }
}
