import Foundation
import SwiftData
import ZIPFoundation

class DataExporter {
    
    // MARK: - Codable DTOs
    
    struct ExportManifest: Codable {
        var version: Int = 1
        var exportedAt: Date
        var entries: [EntryDTO]
        var collections: [CollectionDTO]
        var habits: [HabitDTO]
        var journalEntries: [JournalEntryDTO]
    }
    
    struct EntryDTO: Codable {
        var id: String
        var createdAt: Date
        var type: String
        var text: String
        var tags: [String]
        var isFavorited: Bool
        var imageFile: String?
        var extractedText: String?
        var visionTags: [String]
        var audioFile: String?
        var transcript: String?
        var duration: Double?
        var url: String?
        var linkTitle: String?
        var previewImageFile: String?
        var markdownContent: String?
        var faviconFile: String?
        var locationName: String?
        var locationAddress: String?
        var locationLatitude: Double?
        var locationLongitude: Double?
        var locationCategory: String?
        var captureLatitude: Double?
        var captureLongitude: Double?
        var captureLocationName: String?
        var stickyTitle: String?
        var stickyItems: [String]
        var stickyChecked: [String]
    }
    
    struct CollectionDTO: Codable {
        var id: String
        var createdAt: Date
        var name: String
        var icon: String
        var colorHex: String
        var order: Int
        var isPinned: Bool
        var pinnedOrder: Int
        var isSystem: Bool
        var filterTypes: [String]
        var filterTags: [String]
        var filterDateRange: String
        var filterSearchText: String?
        var filterLocationName: String?
        var filterLocationLatitude: Double?
        var filterLocationLongitude: Double?
        var filterLocationRadius: Double?
    }
    
    struct HabitDTO: Codable {
        var id: String
        var name: String
        var icon: String
        var order: Int
    }
    
    struct JournalEntryDTO: Codable {
        var id: String
        var date: Date
        var weatherEmoji: String
        var moodEmoji: String
        var completedHabits: [String]
        var completedHabitSnapshots: [String]
        var totalHabitsAtTime: Int
        var journalImageFile: String?
    }
    
    // MARK: - Export
    
    static func export(
        entries: [Entry],
        collections: [Collection],
        habits: [Habit],
        journalEntries: [JournalEntry]
    ) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("commonplace_export_\(UUID().uuidString)")
        let mediaDir = tempDir.appendingPathComponent("media")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        
        // Build entry DTOs
        var entryDTOs: [EntryDTO] = []
        for entry in entries {
            var dto = EntryDTO(
                id: entry.id.uuidString,
                createdAt: entry.createdAt,
                type: entry.type.rawValue,
                text: entry.text,
                tags: entry.tags,
                isFavorited: entry.isFavorited,
                imageFile: nil,
                extractedText: entry.extractedText,
                visionTags: entry.visionTags,
                audioFile: nil,
                transcript: entry.transcript,
                duration: entry.duration,
                url: entry.url,
                linkTitle: entry.linkTitle,
                previewImageFile: nil,
                markdownContent: entry.markdownContent,
                faviconFile: nil,
                locationName: entry.locationName,
                locationAddress: entry.locationAddress,
                locationLatitude: entry.locationLatitude,
                locationLongitude: entry.locationLongitude,
                locationCategory: entry.locationCategory,
                captureLatitude: entry.captureLatitude,
                captureLongitude: entry.captureLongitude,
                captureLocationName: entry.captureLocationName,
                stickyTitle: entry.stickyTitle,
                stickyItems: entry.stickyItems,
                stickyChecked: entry.stickyChecked
            )
            if let path = entry.imagePath,
               let data = MediaFileManager.load(path: path) {
                let filename = "entry_\(entry.id.uuidString)_image.jpg"
                try data.write(to: mediaDir.appendingPathComponent(filename))
                dto.imageFile = filename
            }
            if let path = entry.audioPath,
               let data = MediaFileManager.load(path: path) {
                let filename = "entry_\(entry.id.uuidString)_audio.m4a"
                try data.write(to: mediaDir.appendingPathComponent(filename))
                dto.audioFile = filename
            }
            if let path = entry.previewImagePath,
               let data = MediaFileManager.load(path: path) {
                let filename = "entry_\(entry.id.uuidString)_preview.jpg"
                try data.write(to: mediaDir.appendingPathComponent(filename))
                dto.previewImageFile = filename
            }
            if let path = entry.faviconPath,
               let data = MediaFileManager.load(path: path) {
                let filename = "entry_\(entry.id.uuidString)_favicon.png"
                try data.write(to: mediaDir.appendingPathComponent(filename))
                dto.faviconFile = filename
            }
            entryDTOs.append(dto)
        }
        
        // Build journal DTOs
        var journalDTOs: [JournalEntryDTO] = []
        for je in journalEntries {
            var dto = JournalEntryDTO(
                id: je.id.uuidString,
                date: je.date,
                weatherEmoji: je.weatherEmoji,
                moodEmoji: je.moodEmoji,
                completedHabits: je.completedHabits,
                completedHabitSnapshots: je.completedHabitSnapshots,
                totalHabitsAtTime: je.totalHabitsAtTime,
                journalImageFile: nil
            )
            if let data = je.journalImageData {
                let filename = "journal_\(je.id.uuidString)_image.jpg"
                try data.write(to: mediaDir.appendingPathComponent(filename))
                dto.journalImageFile = filename
            }
            journalDTOs.append(dto)
        }
        
        // Build collection DTOs
        let collectionDTOs = collections.map { c in
            CollectionDTO(
                id: c.id.uuidString,
                createdAt: c.createdAt,
                name: c.name,
                icon: c.icon,
                colorHex: c.colorHex,
                order: c.order,
                isPinned: c.isPinned,
                pinnedOrder: c.pinnedOrder,
                isSystem: c.isSystem,
                filterTypes: c.filterTypes,
                filterTags: c.filterTags,
                filterDateRange: c.filterDateRange,
                filterSearchText: c.filterSearchText,
                filterLocationName: c.filterLocationName,
                filterLocationLatitude: c.filterLocationLatitude,
                filterLocationLongitude: c.filterLocationLongitude,
                filterLocationRadius: c.filterLocationRadius
            )
        }
        
        // Build habit DTOs
        let habitDTOs = habits.map { h in
            HabitDTO(id: h.id.uuidString, name: h.name, icon: h.icon, order: h.order)
        }
        
        // Build manifest
        let manifest = ExportManifest(
            exportedAt: Date(),
            entries: entryDTOs,
            collections: collectionDTOs,
            habits: habitDTOs,
            journalEntries: journalDTOs
        )
        
        // Write manifest.json
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(manifest)
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        try jsonData.write(to: manifestURL)
        
        // Build ZIP with contents at root (not nested in folder)
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Commonplace_\(formattedDate()).commonplace")
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }
        let archive = try Archive(url: zipURL, accessMode: .create)
        try archive.addEntry(with: "manifest.json", fileURL: manifestURL)
        let mediaFiles = (try? FileManager.default.contentsOfDirectory(at: mediaDir, includingPropertiesForKeys: nil)) ?? []
        for file in mediaFiles {
            try archive.addEntry(with: "media/\(file.lastPathComponent)", fileURL: file)
        }
        try FileManager.default.removeItem(at: tempDir)
        
        return zipURL
    }
    
    private static func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
