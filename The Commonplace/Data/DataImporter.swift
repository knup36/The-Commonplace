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
        var journalEntriesImported = 0
        
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
            // Skip if same ID already exists (exact duplicate)
            guard !existingCollectionIDs.contains(dto.id) else { continue }
            // Skip system collections if one with the same name already exists
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
            modelContext.insert(collection)
            collectionsImported += 1
        }
        
        // Import Journal Entries
        let existingJournalIDs = Set((try? modelContext.fetch(FetchDescriptor<JournalEntry>()))?.map { $0.id.uuidString } ?? [])
        for dto in manifest.journalEntries {
            guard !existingJournalIDs.contains(dto.id) else { continue }
            let je = JournalEntry(date: dto.date)
            je.id = UUID(uuidString: dto.id) ?? UUID()
            je.weatherEmoji = dto.weatherEmoji
            je.moodEmoji = dto.moodEmoji
            je.completedHabits = dto.completedHabits
            je.completedHabitSnapshots = dto.completedHabitSnapshots
            je.totalHabitsAtTime = dto.totalHabitsAtTime
            if let filename = dto.journalImageFile {
                je.journalImageData = try? Data(contentsOf: mediaDir.appendingPathComponent(filename))
            }
            modelContext.insert(je)
            journalEntriesImported += 1
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
            entry.mediaArtist = dto.mediaArtist
            entry.mediaAlbum = dto.mediaAlbum
            entry.previewURL = dto.previewURL
            
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
            if let filename = dto.mediaArtworkFile,
               let data = try? Data(contentsOf: mediaDir.appendingPathComponent(filename)) {
                entry.mediaArtworkPath = try? MediaFileManager.save(data, type: .image, id: "\(entry.id.uuidString)_artwork")
            }
            
            modelContext.insert(entry)
            entriesImported += 1
        }
        
        try modelContext.save()
        
        return ImportResult(
            entriesImported: entriesImported,
            collectionsImported: collectionsImported,
            habitsImported: habitsImported,
            journalEntriesImported: journalEntriesImported
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
        let journalEntriesImported: Int
        
        var summary: String {
            let total = entriesImported + collectionsImported + habitsImported + journalEntriesImported
            if total == 0 {
                return "Everything is already up to date — no duplicates were imported."
            }
            var parts: [String] = []
            if entriesImported > 0 { parts.append("\(entriesImported) entries") }
            if collectionsImported > 0 { parts.append("\(collectionsImported) collections") }
            if habitsImported > 0 { parts.append("\(habitsImported) habits") }
            if journalEntriesImported > 0 { parts.append("\(journalEntriesImported) journal entries") }
            return "Imported \(parts.joined(separator: ", "))."
        }
    }
}
