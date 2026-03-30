// DataImporter.swift
// Commonplace
//
// Reads a .commonplace archive ZIP and imports entries, collections, and habits
// into the current SwiftData context.
//
// Skips duplicates by checking existing IDs before inserting.
// Handles legacy JournalEntry records from old archive formats.
// Media files are extracted from the archive's media/ folder and saved
// via MediaFileManager into the iCloud container.

import Foundation
import SwiftData
import ZIPFoundation

class DataImporter {

    static func importArchive(from url: URL, modelContext: ModelContext) throws -> ImportResult {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("commonplace_import_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: url, to: tempDir)

        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw ImportError.missingManifest
        }

        let jsonData = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(DataExporter.ExportManifest.self, from: jsonData)

        let mediaDir = tempDir.appendingPathComponent("media")

        var entriesImported = 0
        var collectionsImported = 0
        var habitsImported = 0

        // Import Habits
        let existingHabitIDs = Set((try? modelContext.fetch(FetchDescriptor<Habit>()))?.map { $0.id.uuidString } ?? [])
        for dto in manifest.habits {
            guard !existingHabitIDs.contains(dto.id) else { continue }
            let habit = Habit(name: dto.name, icon: dto.icon, order: dto.order)
            habit.id = UUID(uuidString: dto.id) ?? UUID()
            modelContext.insert(habit)
            habitsImported += 1
        }

        // Import Collections
        let existingCollectionIDs = Set((try? modelContext.fetch(FetchDescriptor<Collection>()))?.map { $0.id.uuidString } ?? [])
        let existingCollectionNames = Set((try? modelContext.fetch(FetchDescriptor<Collection>()))?.map { $0.name } ?? [])
        for dto in manifest.collections {
            guard !existingCollectionIDs.contains(dto.id) else { continue }
            if dto.isSystem && existingCollectionNames.contains(dto.name) { continue }
            let collection = Collection(
                name: dto.name,
                icon: dto.icon,
                colorHex: dto.colorHex,
                order: dto.order
            )
            collection.id = UUID(uuidString: dto.id) ?? UUID()
            collection.createdAt = dto.createdAt
            collection.isPinned = dto.isPinned
            collection.pinnedOrder = dto.pinnedOrder
            collection.isSystem = dto.isSystem
            collection.filterTypes = dto.filterTypes
            collection.filterTags = dto.filterTags
            collection.filterDateRange = dto.filterDateRange
            collection.filterSearchText = dto.filterSearchText
            collection.filterLocationName = dto.filterLocationName
            collection.filterLocationLatitude = dto.filterLocationLatitude
            collection.filterLocationLongitude = dto.filterLocationLongitude
            collection.filterLocationRadius = dto.filterLocationRadius
            collection.filterMediaStatus = dto.filterMediaStatus
            modelContext.insert(collection)
            collectionsImported += 1
        }
        
        // Import Entries
        let existingEntryIDs = Set((try? modelContext.fetch(FetchDescriptor<Entry>()))?.map { $0.id.uuidString } ?? [])
        for dto in manifest.entries {
            guard let type = EntryType(rawValue: dto.type) else { continue }
            guard !existingEntryIDs.contains(dto.id) else { continue }
            let entry = Entry(type: type, text: dto.text, tags: dto.tags)
            entry.id = UUID(uuidString: dto.id) ?? UUID()
            entry.createdAt = dto.createdAt
            entry.isFavorited = dto.isFavorited
            entry.isPinned = dto.isPinned
            entry.extractedText = dto.extractedText
            entry.visionTags = dto.visionTags
            entry.transcript = dto.transcript
            entry.duration = dto.duration
            entry.url = dto.url
            entry.linkTitle = dto.linkTitle
            entry.markdownContent = dto.markdownContent
            entry.locationName = dto.locationName
            entry.locationAddress = dto.locationAddress
            entry.locationLatitude = dto.locationLatitude
            entry.locationLongitude = dto.locationLongitude
            entry.locationCategory = dto.locationCategory
            entry.captureLatitude = dto.captureLatitude
            entry.captureLongitude = dto.captureLongitude
            entry.captureLocationName = dto.captureLocationName
            entry.stickyTitle = dto.stickyTitle
            entry.stickyItems = dto.stickyItems
            entry.stickyChecked = dto.stickyChecked
            entry.musicArtist = dto.musicArtist
            entry.musicAlbum = dto.musicAlbum
            entry.previewURL = dto.previewURL
            entry.tagNames = dto.tags
            entry.musicTrackID = dto.musicTrackID
            
            // HealthKit fields
            entry.healthActiveCalories = dto.healthActiveCalories
            entry.healthExerciseMinutes = dto.healthExerciseMinutes
            entry.healthStandHours = dto.healthStandHours
            entry.healthWorkoutName = dto.healthWorkoutName
            entry.healthWorkoutDuration = dto.healthWorkoutDuration
            entry.healthWorkoutCalories = dto.healthWorkoutCalories
            entry.healthDataFetched = dto.healthDataFetched ?? false

            // Journal fields
            if type == .journal {
                entry.weatherEmoji = dto.weatherEmoji ?? ""
                entry.moodEmoji = dto.moodEmoji ?? ""
                entry.vibeEmoji = dto.vibeEmoji ?? ""
                entry.completedHabits = dto.completedHabits ?? []
                entry.completedHabitSnapshots = dto.completedHabitSnapshots ?? []
                entry.totalHabitsAtTime = dto.totalHabitsAtTime ?? 0
            }

            // Media fields
            if type == .media {
                entry.mediaTitle = dto.mediaTitle
                entry.mediaType = dto.mediaType
                entry.mediaYear = dto.mediaYear
                entry.mediaGenre = dto.mediaGenre
                entry.mediaOverview = dto.mediaOverview
                entry.mediaStatus = dto.mediaStatus
                entry.mediaRating = dto.mediaRating
                entry.mediaLog = dto.mediaLog ?? []
                entry.tmdbID = dto.tmdbID
                entry.mediaRuntime = dto.mediaRuntime
                entry.mediaSeasons = dto.mediaSeasons
            }
            
            // Media files
            if let filename = dto.imageFile,
               let data = try? Data(contentsOf: mediaDir.appendingPathComponent(filename)) {
                entry.imagePath = try? MediaFileManager.save(data, type: .image, id: entry.id.uuidString)
            }
            if let filename = dto.audioFile,
               let data = try? Data(contentsOf: mediaDir.appendingPathComponent(filename)) {
                entry.audioPath = try? MediaFileManager.save(data, type: .audio, id: entry.id.uuidString)
            }
            if let filename = dto.previewImageFile,
               let data = try? Data(contentsOf: mediaDir.appendingPathComponent(filename)) {
                entry.previewImagePath = try? MediaFileManager.save(data, type: .preview, id: entry.id.uuidString)
            }
            if let filename = dto.faviconFile,
               let data = try? Data(contentsOf: mediaDir.appendingPathComponent(filename)) {
                entry.faviconPath = try? MediaFileManager.save(data, type: .favicon, id: entry.id.uuidString)
            }
            if let filename = dto.musicArtworkFile,
               let data = try? Data(contentsOf: mediaDir.appendingPathComponent(filename)) {
                entry.musicArtworkPath = try? MediaFileManager.save(data, type: .image, id: "\(entry.id.uuidString)_artwork")
            }
            if let filename = dto.journalImageFile,
               let data = try? Data(contentsOf: mediaDir.appendingPathComponent(filename)) {
                entry.journalImagePath = try? MediaFileManager.save(
                    data,
                    type: .journal,
                    id: entry.id.uuidString
                )
            }
            if let filename = dto.mediaCoverFile,
               let data = try? Data(contentsOf: mediaDir.appendingPathComponent(filename)) {
                entry.mediaCoverPath = try? MediaFileManager.save(data, type: .image, id: "\(entry.id.uuidString)_cover")
            }

            modelContext.insert(entry)
            entriesImported += 1
        }

        // Handle old archive format — import legacy JournalEntry records
        // and merge them into matching journal entries
        if !manifest.journalEntries.isEmpty {
            let allEntries = (try? modelContext.fetch(FetchDescriptor<Entry>())) ?? []
            for dto in manifest.journalEntries {
                let matching = allEntries.first {
                    $0.type == .journal &&
                    Calendar.current.isDate($0.createdAt, inSameDayAs: dto.date)
                }
                if let entry = matching {
                    if entry.weatherEmoji.isEmpty { entry.weatherEmoji = dto.weatherEmoji }
                    if entry.moodEmoji.isEmpty { entry.moodEmoji = dto.moodEmoji }
                    if entry.completedHabits.isEmpty { entry.completedHabits = dto.completedHabits }
                    if entry.completedHabitSnapshots.isEmpty { entry.completedHabitSnapshots = dto.completedHabitSnapshots }
                    if entry.totalHabitsAtTime == 0 { entry.totalHabitsAtTime = dto.totalHabitsAtTime }
                    if entry.journalImageData == nil, let filename = dto.journalImageFile {
                        entry.journalImageData = try? Data(contentsOf: mediaDir.appendingPathComponent(filename))
                    }
                } else {
                    // Create a new journal entry from the legacy data
                    let entry = Entry(type: .journal, text: "", tags: [])
                    entry.createdAt = dto.date
                    entry.weatherEmoji = dto.weatherEmoji
                    entry.moodEmoji = dto.moodEmoji
                    entry.completedHabits = dto.completedHabits
                    entry.completedHabitSnapshots = dto.completedHabitSnapshots
                    entry.totalHabitsAtTime = dto.totalHabitsAtTime
                    if let filename = dto.journalImageFile {
                        entry.journalImageData = try? Data(contentsOf: mediaDir.appendingPathComponent(filename))
                    }
                    modelContext.insert(entry)
                    entriesImported += 1
                }
            }
        }
        
        // Create Tag objects for any tagNames not already in SwiftData
        // Same pattern as ShareExtensionIngestor and TagMigrationService
        let existingTags = (try? modelContext.fetch(FetchDescriptor<Tag>())) ?? []
        let existingTagNames = Set(existingTags.map { $0.name })
        let allImportedTagNames = Set(manifest.entries.flatMap { $0.tags })
        for tagName in allImportedTagNames where !existingTagNames.contains(tagName) {
            let tag = Tag(name: tagName)
            modelContext.insert(tag)
        }
        
        // Index all imported entries in search
        // Backfill will catch these on next launch too, but indexing here
        // means search works immediately after import without restarting
        let allEntries = (try? modelContext.fetch(FetchDescriptor<Entry>())) ?? []
        let importedIDs = Set(manifest.entries.map { $0.id })
        for entry in allEntries where importedIDs.contains(entry.id.uuidString) {
            SearchIndex.shared.index(entry: entry)
        }
        
        try modelContext.save()
        
        return ImportResult(
            entriesImported: entriesImported,
            collectionsImported: collectionsImported,
            habitsImported: habitsImported
        )
    }
    
    enum ImportError: LocalizedError {
        case missingManifest
        var errorDescription: String? {
            switch self {
            case .missingManifest:
                return "This file doesn't appear to be a valid Commonplace archive."
            }
        }
    }

    struct ImportResult {
        let entriesImported: Int
        let collectionsImported: Int
        let habitsImported: Int

        var summary: String {
            let total = entriesImported + collectionsImported + habitsImported
            if total == 0 {
                return "Everything is already up to date — no duplicates were imported."
            }
            var parts: [String] = []
            if entriesImported > 0 { parts.append("\(entriesImported) entries") }
            if collectionsImported > 0 { parts.append("\(collectionsImported) collections") }
            if habitsImported > 0 { parts.append("\(habitsImported) habits") }
            return "Imported \(parts.joined(separator: ", "))."
        }
    }
}
