// DataExporter.swift
// Commonplace
//
// Responsible for serializing all app data (entries, collections, habits) into
// a .commonplace archive — a ZIP file containing a JSON manifest and a flat
// media folder.
//
// Key responsibilities:
//   - Building EntryDTO, CollectionDTO, HabitDTO value types for JSON encoding
//   - Copying media files from the iCloud container into the export ZIP
//   - Checking whether iCloud media files are fully downloaded before export
//   - Triggering iCloud downloads for any files not yet on device
//   - Returning an ExportSummary so the UI can show a verification count
//
// Important notes:
//   - journalImageData is stored directly on Entry (not via MediaFileManager)
//     and is handled as a special case during export
//   - iCloud download triggering uses NSFileCoordinator — this is the correct
//     Apple-recommended API for forcing iCloud files to download on demand
//   - All iCloud checks use URLResourceValues.ubiquitousItemDownloadingStatus

import Foundation
import SwiftData
import ZIPFoundation

class DataExporter {

    // MARK: - Codable DTOs

    struct ExportManifest: Codable {
        var version: Int = 2
        var exportedAt: Date
        var entries: [EntryDTO]
        var collections: [CollectionDTO]
        var habits: [HabitDTO]
        var journalEntries: [JournalEntryDTO] = [] // kept for backward compatibility
    }

    struct EntryDTO: Codable {
        var id: String
        var createdAt: Date
        var type: String
        var text: String
        var tags: [String]
        var isFavorited: Bool
        var isPinned: Bool
        var imageFile: String?
        var extractedText: String?
        var visionTags: [String]
        var audioFile: String?
        var videoFile: String?
        var videoThumbnailFile: String?
        var videoDuration: Double?
        var transcript: String?
        var duration: Double?
        var url: String?
        var linkTitle: String?
        var previewImageFile: String?
        var markdownContent: String?
        var faviconFile: String?
        var linkContentType: String?
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
        var musicArtist: String?
        var musicAlbum: String?
        var previewURL: String?
        var musicArtworkFile: String?
        var musicTrackID: String?
        // Journal fields
        var weatherEmoji: String?
        var moodEmoji: String?
        var completedHabits: [String]?
        var completedHabitSnapshots: [String]?
        var totalHabitsAtTime: Int?
        var journalImageFile: String?
        var vibeEmoji: String?
        // HealthKit fields
        var healthActiveCalories: Double?
        var healthExerciseMinutes: Double?
        var healthStandHours: Double?
        var healthWorkoutName: String?
        var healthWorkoutDuration: Int?
        var healthWorkoutCalories: Double?
        var healthDataFetched: Bool?
        // Journal image path (replaces journalImageData blob)
        var journalImagePath: String?
        // Media fields (v1.5)
        var mediaTitle: String?
        var mediaType: String?
        var mediaYear: String?
        var mediaGenre: String?
        var mediaOverview: String?
        var mediaCoverFile: String?
        var mediaStatus: String?
        var mediaRating: Int?
        var mediaLog: [String]?
        var tmdbID: Int?
        var mediaRuntime: Int?
        var mediaSeasons: Int?
        // Weekly Review fields (v1.12.1)
        var weeklyReviewHighlight: String?
        var weeklyReviewCarryForward: String?
        var weeklyReviewGratitude: String?
        var weeklyReviewStats: Data?
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
        var filterMediaStatus: [String]
    }
    
    struct HabitDTO: Codable {
        var id: String
        var name: String
        var icon: String
        var order: Int
    }

    // Kept for decoding old archives
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

    // MARK: - Export Summary

    /// Returned after a successful export so the UI can show a verification message.
    struct ExportSummary {
        let entryCount: Int
        let mediaFileCount: Int
        let exportURL: URL

        var message: String {
            "\(entryCount) entries and \(mediaFileCount) media files exported successfully."
        }
    }

    // MARK: - iCloud Sync Check

    /// Checks how many media files referenced by entries are not yet downloaded
    /// from iCloud to this device.
    ///
    /// Returns the count of files that are in iCloud but not locally available.
    /// A count of 0 means the device is fully in sync and safe to export.
    static func countUnsyncedFiles(entries: [Entry]) -> Int {
        var unsyncedCount = 0
        for entry in entries {
            let paths = mediaPaths(for: entry)
            for path in paths {
                let fileURL = MediaFileManager.containerURL.appendingPathComponent(path)
                if isFileNotDownloaded(fileURL) {
                    unsyncedCount += 1
                }
            }
        }
        return unsyncedCount
    }

    /// Triggers iCloud to download all media files that are not yet on device.
    /// Waits until all files are downloaded or a timeout is reached.
    ///
    /// - Parameter entries: All entries to check media paths for
    /// - Parameter timeoutSeconds: How long to wait before giving up (default 60s)
    /// - Returns: true if all files downloaded successfully, false if timed out
    static func downloadUnsyncedFiles(
        entries: [Entry],
        timeoutSeconds: Double = 60
    ) async -> Bool {
        // Collect all file URLs that need downloading
        var pendingURLs: [URL] = []
        for entry in entries {
            let paths = mediaPaths(for: entry)
            for path in paths {
                let fileURL = MediaFileManager.containerURL.appendingPathComponent(path)
                if isFileNotDownloaded(fileURL) {
                    pendingURLs.append(fileURL)
                }
            }
        }

        guard !pendingURLs.isEmpty else { return true }

        // Trigger download for each file
        for url in pendingURLs {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }

        // Poll until all files are downloaded or timeout is reached
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 500_000_000) // check every 0.5s
            let stillPending = pendingURLs.filter { isFileNotDownloaded($0) }
            if stillPending.isEmpty { return true }
        }

        return false // timed out
    }

    // MARK: - Export

    static func export(
        entries: [Entry],
        collections: [Collection],
        habits: [Habit]
    ) throws -> ExportSummary {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("commonplace_export_\(UUID().uuidString)")
        let mediaDir = tempDir.appendingPathComponent("media")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)

        var mediaFileCount = 0

        // Build entry DTOs
        var entryDTOs: [EntryDTO] = []
        for entry in entries {
            var dto = EntryDTO(
                id: entry.id.uuidString,
                createdAt: entry.createdAt,
                type: entry.type.rawValue,
                text: entry.text,
                tags: entry.tagNames,
                isFavorited: entry.isFavorited,
                isPinned: entry.isPinned,
                imageFile: nil,
                extractedText: entry.extractedText,
                visionTags: entry.visionTags,
                audioFile: nil,
                videoDuration: entry.videoDuration,
                transcript: entry.transcript,
                duration: entry.duration,
                url: entry.url,
                linkTitle: entry.linkTitle,
                previewImageFile: nil,
                markdownContent: entry.markdownContent,
                faviconFile: nil,
                linkContentType: entry.linkContentType,
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
                stickyChecked: entry.stickyChecked,
                musicArtist: entry.musicArtist,
                musicAlbum: entry.musicAlbum,
                previewURL: entry.previewURL,
                musicArtworkFile: nil,
                musicTrackID: entry.musicTrackID,
                weatherEmoji: entry.type == .journal ? entry.weatherEmoji : nil,
                moodEmoji: entry.type == .journal ? entry.moodEmoji : nil,
                completedHabits: entry.type == .journal ? entry.completedHabits : nil,
                completedHabitSnapshots: entry.type == .journal ? entry.completedHabitSnapshots : nil,
                totalHabitsAtTime: entry.type == .journal ? entry.totalHabitsAtTime : nil,
                journalImageFile: nil,
                vibeEmoji: entry.type == .journal ? entry.vibeEmoji : nil,
                healthActiveCalories: entry.healthActiveCalories,
                healthExerciseMinutes: entry.healthExerciseMinutes,
                healthStandHours: entry.healthStandHours,
                healthWorkoutName: entry.healthWorkoutName,
                healthWorkoutDuration: entry.healthWorkoutDuration,
                healthWorkoutCalories: entry.healthWorkoutCalories,
                healthDataFetched: entry.healthDataFetched,
                // Media fields
                mediaTitle: entry.mediaTitle,
                mediaType: entry.mediaType,
                mediaYear: entry.mediaYear,
                mediaGenre: entry.mediaGenre,
                mediaOverview: entry.mediaOverview,
                mediaCoverFile: nil,
                mediaStatus: entry.mediaStatus,
                mediaRating: entry.mediaRating,
                mediaLog: entry.mediaLog.isEmpty ? nil : entry.mediaLog,
                tmdbID: entry.tmdbID,
                mediaRuntime: entry.mediaRuntime,
                mediaSeasons: entry.mediaSeasons,
                weeklyReviewHighlight: entry.weeklyReviewHighlight,
                weeklyReviewCarryForward: entry.weeklyReviewCarryForward,
                weeklyReviewGratitude: entry.weeklyReviewGratitude,
                weeklyReviewStats: entry.weeklyReviewStats
            )
            
            // Media files
            if let path = entry.imagePath,
               let data = MediaFileManager.load(path: path) {
                let filename = "entry_\(entry.id.uuidString)_image.jpg"
                try data.write(to: mediaDir.appendingPathComponent(filename))
                dto.imageFile = filename
                mediaFileCount += 1
            }
            if let path = entry.videoPath,
               let data = MediaFileManager.load(path: path) {
                let filename = "entry_\(entry.id.uuidString)_video.mp4"
                try data.write(to: mediaDir.appendingPathComponent(filename))
                dto.videoFile = filename
                mediaFileCount += 1
            }
            if let path = entry.videoThumbnailPath,
               let data = MediaFileManager.load(path: path) {
                let filename = "entry_\(entry.id.uuidString)_thumb.jpg"
                try data.write(to: mediaDir.appendingPathComponent(filename))
                dto.videoThumbnailFile = filename
                mediaFileCount += 1
            }
            if let path = entry.audioPath,
               let data = MediaFileManager.load(path: path) {
                let filename = "entry_\(entry.id.uuidString)_audio.m4a"
                try data.write(to: mediaDir.appendingPathComponent(filename))
                dto.audioFile = filename
                mediaFileCount += 1
            }
            if let path = entry.previewImagePath,
               let data = MediaFileManager.load(path: path) {
                let filename = "entry_\(entry.id.uuidString)_preview.jpg"
                try data.write(to: mediaDir.appendingPathComponent(filename))
                dto.previewImageFile = filename
                mediaFileCount += 1
            }
            if let path = entry.faviconPath,
               let data = MediaFileManager.load(path: path) {
                let filename = "entry_\(entry.id.uuidString)_favicon.png"
                try data.write(to: mediaDir.appendingPathComponent(filename))
                dto.faviconFile = filename
                mediaFileCount += 1
            }
            if let path = entry.musicArtworkPath,
               let data = MediaFileManager.load(path: path) {
                let filename = "entry_\(entry.id.uuidString)_artwork.jpg"
                try data.write(to: mediaDir.appendingPathComponent(filename))
                dto.musicArtworkFile = filename
                mediaFileCount += 1
            }
            if entry.type == .journal, let path = entry.journalImagePath,
               let data = MediaFileManager.load(path: path) {
                let filename = "entry_\(entry.id.uuidString)_journal.jpg"
                try data.write(to: mediaDir.appendingPathComponent(filename))
                dto.journalImageFile = filename
                mediaFileCount += 1
            }
            // Media cover art
            if entry.type == .media,
               let path = entry.mediaCoverPath,
               let data = MediaFileManager.load(path: path) {
                let filename = "entry_\(entry.id.uuidString)_cover.jpg"
                try data.write(to: mediaDir.appendingPathComponent(filename))
                dto.mediaCoverFile = filename
                mediaFileCount += 1
            }

            entryDTOs.append(dto)
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
                filterLocationRadius: c.filterLocationRadius,
                filterMediaStatus: c.filterMediaStatus
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
            habits: habitDTOs
        )

        // Write manifest.json
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(manifest)
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        try jsonData.write(to: manifestURL)

        // Build ZIP
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Commonplace_\(formattedDate()).commonplace")
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }
        let archive = try Archive(url: zipURL, accessMode: .create)
        try archive.addEntry(with: "manifest.json", fileURL: manifestURL)
        let mediaFiles = (try? FileManager.default.contentsOfDirectory(
            at: mediaDir,
            includingPropertiesForKeys: nil
        )) ?? []
        for file in mediaFiles {
            try archive.addEntry(with: "media/\(file.lastPathComponent)", fileURL: file)
        }
        try FileManager.default.removeItem(at: tempDir)

        return ExportSummary(
            entryCount: entries.count,
            mediaFileCount: mediaFileCount,
            exportURL: zipURL
        )
    }

    // MARK: - Private Helpers

    /// Collects all media file paths referenced by an entry.
    /// Used by the iCloud sync check to know which files to inspect.
    private static func mediaPaths(for entry: Entry) -> [String] {
        [
            entry.imagePath,
            entry.audioPath,
            entry.previewImagePath,
            entry.faviconPath,
            entry.musicArtworkPath,
            entry.mediaCoverPath,
            entry.journalImagePath,
            entry.videoPath,
            entry.videoThumbnailPath
        ].compactMap { $0 }
        // Note: journalImageData is stored in SwiftData directly, not as a file path,
        // so it is always available and does not need an iCloud download check
    }

    /// Returns true if a file exists in iCloud but has not been downloaded to this device.
    private static func isFileNotDownloaded(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let resourceValues = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        let status = resourceValues?.ubiquitousItemDownloadingStatus
        return status == .notDownloaded
    }

    private static func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
