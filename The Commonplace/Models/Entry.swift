// Entry.swift
// Commonplace
//
// SwiftData model representing a single captured entry (called a "page" in the UI).
// All entry types share this one model, differentiated by the `type` field.
//
// ============================================================
// SCHEMA VERSION: 9
// Last updated: v2.0.1
//
// Schema change policy:
//   - Adding optional fields: safe, no migration needed
//   - Adding non-optional fields: must have a default value
//   - Removing fields: NEVER remove immediately
//       1. Retire — stop writing to the field, keep reading
//       2. Deprecate — add a comment marking it deprecated + version
//       3. Remove — only after one full version cycle of deprecation
//   - Renaming fields: treat as remove + add — requires migration service
//
// SwiftData hard rules (learned the hard way):
//   - NEVER attempt many-to-many relationships — ModelContainer crashes
//   - Always use name-matching for Tag relationships (entry.tagNames)
//   - Always save explicitly: try? modelContext.save()
//   - entry.text is ALWAYS user-visible note text — never structured data
//
// Field version history:
//   v1.0  — id, createdAt, type, text, tagNames, isFavorited, isPinned
//   v1.0  — imagePath, extractedText, visionTags (photo)
//   v1.0  — audioPath, transcript, duration (audio)
//   v1.0  — url, linkTitle, previewImagePath, markdownContent, faviconPath (link)
//   v1.0  — musicArtist, musicAlbum, previewURL, musicArtworkPath (music)
//   v1.0  — locationName, locationAddress, locationLatitude, locationLongitude, locationCategory (location)
//   v1.0  — captureLatitude, captureLongitude, captureLocationName (capture metadata)
//   v1.0  — stickyTitle, stickyItems, stickyChecked (sticky)
//   v1.0  — weatherEmoji, moodEmoji, vibeEmoji, completedHabits, completedHabitSnapshots, totalHabitsAtTime (journal)
//   v1.5  — mediaTitle, mediaType, mediaYear, mediaGenre, mediaOverview, mediaCoverPath,
//            mediaStatus, mediaRating, mediaLog, tmdbID, mediaRuntime, mediaSeasons (media)
//   v1.5  — musicTrackID (music — renamed from mediaTrackID to avoid collision)
//   v1.6  — journalImageData (journal — DEPRECATED v1.9.1, retained for legacy import only)
//   v1.9  — healthActiveCalories, healthExerciseMinutes, healthStandHours,
//            healthWorkoutName, healthWorkoutDuration, healthWorkoutCalories, healthDataFetched
//   v1.9.1 — journalImagePath (replaces journalImageData blob)
//   v1.11 — linkContentType (link)
//   v1.12 — videoPath, videoDuration, videoThumbnailPath (photo/shot)
//   v1.12.1 — weeklyReviewHighlight, weeklyReviewCarryForward, weeklyReviewGratitude, weeklyReviewStats
//   v1.13.1 — modifiedAt, wordCount, readingTime, locationRating
//   v1.14 — readwiseSourceID, readwiseImportedHighlightIDs
//   v1.14.1 — locationVisited
//   v2.0    — linkedEntryIDs
//   v2.0.1  — isScreenshot, isScreenshotDetected
//
// Deprecated fields (do not remove yet):
//   journalImageData — deprecated v1.9.1, replaced by journalImagePath
//                      retained for legacy archive import compatibility
//   isFavorited      — deprecated v1.7.1, replaced by isPinned
//                      retained in schema, safe to remove after v2.0
// ============================================================
//
// UI language conventions (do not change these):
//   - Entries are called "pages" in the UI
//   - isPinned shows as "Bookmark" in the UI, not "Pin"
//   - Stickies are checklists, not to-dos
//   - .photo display name is "Shot"
//   - .audio display name is "Sound"
//
// Readwise note (v1.14):
//   - `readwiseSourceID` stores the Reader/Readwise document ID — deduplication key for sync
//   - If present, the entry is "owned" by Readwise — sync will append new highlights but never overwrite
//   - `readwiseImportedHighlightIDs` tracks individual highlight IDs already imported —
//     prevents duplicates when the same article is highlighted across multiple reading sessions
//
// Location status note (v1.14.1):
//   - `locationVisited: Bool` — false = Want to Visit (default), true = Been Here
//   - All existing location entries default to false on migration

import SwiftData
import Foundation
import SwiftUI

@Model
class Entry {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var type: EntryType = EntryType.text
    var text: String = ""
    var wordCount: Int? = nil
    var readingTime: Int? = nil
    
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
    var locationRating: Int? = nil
    
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
    
    // Readwise (v1.14)
    // readwiseSourceID: permanent ID from Readwise/Reader — used as deduplication key
    // If this field is present on an entry, that entry is "owned" by Readwise sync
    // readwiseImportedHighlightIDs: tracks which individual highlights have already been
    // imported — prevents duplicates when syncing a partially-read article over multiple sessions
    var readwiseSourceID: String? = nil
    var readwiseImportedHighlightIDs: [String] = []
    
    // Location status (v1.14.1)
    // locationVisited: false = Want to Visit (default), true = Been Here
    // Displayed as checkmark.seal (outline) / checkmark.seal.fill (green) in feed and detail
    var locationVisited: Bool = false
    
    // Entry links (v2.0)
        // Explicit connections between entries — stored as UUID strings to avoid SwiftData
        // many-to-many relationship crashes. Same pattern as tagNames.
        // UI for creating and managing links is deferred — field added now for future-proofing.
        // Powers the Knowledge Graph in v3.0.
        var linkedEntryIDs: [String] = []

        // Screenshot detection (v2.0.1)
        // isScreenshot: true if the image was detected as a screenshot via EXIF analysis
        // isScreenshotDetected: true once detection has run — prevents re-processing on every launch
        // Detection: absence of camera EXIF fields (FNumber, ExposureTime) indicates screenshot
        var isScreenshot: Bool = false
        var isScreenshotDetected: Bool = false
    
    init(type: EntryType = .text, text: String = "", tags: [String] = []) {
        self.id = UUID()
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.type = type
        self.text = text
        self.tagNames = tags
        self.isFavorited = false
        self.visionTags = []
    }
    
    /// Call whenever meaningful content on the entry changes.
    /// Updates modifiedAt and recalculates wordCount for text-heavy entries.
    func touch() {
        modifiedAt = Date()
        if !text.isEmpty {
            wordCount = text.split(whereSeparator: \.isWhitespace).count
        }
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
        case .text:     return InkwellTheme.textAccent
        case .photo:    return InkwellTheme.photoAccent
        case .audio:    return InkwellTheme.audioAccent
        case .link:     return InkwellTheme.linkAccent
        case .journal:  return InkwellTheme.journalAccent
        case .location: return InkwellTheme.locationAccent
        case .sticky:   return InkwellTheme.stickyAccent
        case .music:    return InkwellTheme.musicAccent
        case .media:    return InkwellTheme.mediaAccent
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
