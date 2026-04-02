// MarkdownExporter.swift
// Commonplace
//
// Exports entries as human-readable markdown files organized by week,
// saved directly to iCloud Drive for access in Finder on Mac.
//
// Output structure:
//   iCloud Drive/Commonplace Archives/Commonplace-Archive-[Month-Year]/
//     2026-03-W1-Mar01-Mar07.md
//     2026-03-W2-Mar08-Mar14.md
//     ...
//     media/
//       [entryID]_image.jpg
//       [entryID]_audio.m4a
//       etc.
//     README.md
//
// Each run creates a new dated folder — previous exports are never overwritten.
// Covers the last 30 days of entries.
//
// Entry type formatting:
//   .text     — plain text content
//   .photo    — image copied to media/, referenced in markdown
//   .audio    — audio copied to media/, transcript if available
//   .link     — title, URL, markdown content if saved
//   .journal  — date, weather/mood/vibe emojis, habits, daily note
//   .location — place name, address, coordinates
//   .sticky   — title, checklist items with completion state
//   .music    — track title, artist, album
//   .media    — title, type, year, genre, status, rating, notes

import Foundation
import UIKit
import ZIPFoundation

struct MarkdownExporter {

    // MARK: - Export Result

    struct ExportResult {
        let zipURL: URL
        let entryCount: Int
        let mediaFileCount: Int
        let weekCount: Int

        var message: String {
            "\(entryCount) entries exported across \(weekCount) weekly files with \(mediaFileCount) media files."
        }
    }

    // MARK: - Export
    
    static func exportWeek(entries: [Entry], weekStart: Date) throws -> ExportResult {
        let calendar = Calendar.current
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart

        let weekEntries = entries
            .filter { $0.createdAt >= weekStart && $0.createdAt < weekEnd }
            .sorted { $0.createdAt < $1.createdAt }

        guard !weekEntries.isEmpty else {
            throw MarkdownExportError.noEntries
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("commonplace_week_\(UUID().uuidString)")
        let mediaURL = tempDir.appendingPathComponent("media")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mediaURL, withIntermediateDirectories: true)

        var mediaFileCount = 0
        let filename = weekFilename(for: weekStart, entries: weekEntries)
        let fileURL = tempDir.appendingPathComponent(filename)
        let markdown = try renderWeek(
            weekStart: weekStart,
            entries: weekEntries,
            mediaURL: mediaURL,
            mediaFileCount: &mediaFileCount
        )
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Commonplace-Week-\(formatter.string(from: weekStart)).zip")
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }
        let archive = try Archive(url: zipURL, accessMode: .create)
        try archive.addEntry(with: filename, fileURL: fileURL)
        let mediaFiles = (try? FileManager.default.contentsOfDirectory(
            at: mediaURL,
            includingPropertiesForKeys: nil
        )) ?? []
        for file in mediaFiles {
            try archive.addEntry(with: "media/\(file.lastPathComponent)", fileURL: file)
        }
        try FileManager.default.removeItem(at: tempDir)

        return ExportResult(
            zipURL: zipURL,
            entryCount: weekEntries.count,
            mediaFileCount: mediaFileCount,
            weekCount: 1
        )
    }

    static func export(entries: [Entry]) throws -> ExportResult {
        // Filter to last 30 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentEntries = entries
            .filter { $0.createdAt >= cutoff }
            .sorted { $0.createdAt < $1.createdAt }

        guard !recentEntries.isEmpty else {
            throw MarkdownExportError.noEntries
        }

        // Create temp folder
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("commonplace_markdown_\(UUID().uuidString)")
        let mediaURL = tempDir.appendingPathComponent("media")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mediaURL, withIntermediateDirectories: true)
        let folderURL = tempDir

        // Group entries by week
        let weeks = groupByWeek(entries: recentEntries)
        var mediaFileCount = 0

        // Write each weekly file
        for (weekStart, weekEntries) in weeks.sorted(by: { $0.key < $1.key }) {
            let filename = weekFilename(for: weekStart, entries: weekEntries)
            let fileURL = folderURL.appendingPathComponent(filename)
            let markdown = try renderWeek(
                weekStart: weekStart,
                entries: weekEntries,
                mediaURL: mediaURL,
                mediaFileCount: &mediaFileCount
            )
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        // Write README
        let readmeURL = folderURL.appendingPathComponent("README.md")
        try readme().write(to: readmeURL, atomically: true, encoding: .utf8)

        // Build ZIP
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM-yyyy"
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Commonplace-Archive-\(formatter.string(from: Date())).zip")
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }
        let archive = try Archive(url: zipURL, accessMode: .create)
        // Add all files from temp folder
        let allFiles = try FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        for file in allFiles {
            if file.hasDirectoryPath {
                let subFiles = (try? FileManager.default.contentsOfDirectory(
                    at: file,
                    includingPropertiesForKeys: nil
                )) ?? []
                for subFile in subFiles {
                    try archive.addEntry(
                        with: "\(file.lastPathComponent)/\(subFile.lastPathComponent)",
                        fileURL: subFile
                    )
                }
            } else {
                try archive.addEntry(with: file.lastPathComponent, fileURL: file)
            }
        }
        try FileManager.default.removeItem(at: tempDir)

        return ExportResult(
            zipURL: zipURL,
            entryCount: recentEntries.count,
            mediaFileCount: mediaFileCount,
            weekCount: weeks.count
        )
    }

    // MARK: - Week Grouping

    private static func groupByWeek(entries: [Entry]) -> [Date: [Entry]] {
        var weeks: [Date: [Entry]] = [:]
        let calendar = Calendar.current
        for entry in entries {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: entry.createdAt)?.start ?? entry.createdAt
            weeks[weekStart, default: []].append(entry)
        }
        return weeks
    }

    private static func weekFilename(for weekStart: Date, entries: [Entry]) -> String {
        let calendar = Calendar.current
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let weekFormatter = DateFormatter()
        weekFormatter.dateFormat = "MMdd"
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMMdd"

        // Calculate week number of month
        let weekOfMonth = calendar.component(.weekOfMonth, from: weekStart)

        return "\(yearFormatter.string(from: weekStart))-\(monthString(from: weekStart))-W\(weekOfMonth)-\(displayFormatter.string(from: weekStart))-\(displayFormatter.string(from: weekEnd)).md"
    }

    private static func monthString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM"
        return formatter.string(from: date)
    }

    // MARK: - Week Rendering

    private static func renderWeek(
        weekStart: Date,
        entries: [Entry],
        mediaURL: URL,
        mediaFileCount: inout Int
    ) throws -> String {
        var lines: [String] = []

        // Week header
        let headerFormatter = DateFormatter()
        headerFormatter.dateFormat = "MMMM d, yyyy"
        lines.append("# Commonplace — Week of \(headerFormatter.string(from: weekStart))")
        lines.append("")

        // Group by day
        let days = Dictionary(grouping: entries) { entry -> Date in
            Calendar.current.startOfDay(for: entry.createdAt)
        }

        for day in days.keys.sorted() {
            let dayEntries = days[day] ?? []

            // Day header
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE, MMMM d"
            lines.append("---")
            lines.append("")
            lines.append("## \(dayFormatter.string(from: day))")
            lines.append("")

            for entry in dayEntries.sorted(by: { $0.createdAt < $1.createdAt }) {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "h:mm a"
                let time = timeFormatter.string(from: entry.createdAt)

                lines.append(try renderEntry(
                    entry: entry,
                    time: time,
                    mediaURL: mediaURL,
                    mediaFileCount: &mediaFileCount
                ))
                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Entry Rendering

    private static func renderEntry(
        entry: Entry,
        time: String,
        mediaURL: URL,
        mediaFileCount: inout Int
    ) throws -> String {
        var lines: [String] = []

        switch entry.type {
        case .text:
            lines.append("### 📝 Note — \(time)")
            if !entry.text.isEmpty {
                lines.append(entry.text)
            }

        case .photo:
            lines.append("### 📷 Photo — \(time)")
            if let path = entry.imagePath,
               let data = MediaFileManager.load(path: path) {
                let filename = "\(entry.id.uuidString)_image.jpg"
                try data.write(to: mediaURL.appendingPathComponent(filename))
                mediaFileCount += 1
                lines.append("![Photo](media/\(filename))")
            }
            if !entry.text.isEmpty {
                lines.append(entry.text)
            }
            if let extracted = entry.extractedText, !extracted.isEmpty {
                lines.append("")
                lines.append("*Extracted text: \(extracted)*")
            }

        case .audio:
            lines.append("### 🎙️ Audio — \(time)")
            if let path = entry.audioPath,
               let data = MediaFileManager.load(path: path) {
                let filename = "\(entry.id.uuidString)_audio.m4a"
                try data.write(to: mediaURL.appendingPathComponent(filename))
                mediaFileCount += 1
                lines.append("[Audio recording](media/\(filename))")
            }
            if let transcript = entry.transcript, !transcript.isEmpty {
                lines.append("")
                lines.append("**Transcript:** \(transcript)")
            }

        case .link:
            lines.append("### 🔗 Link — \(time)")
            if let title = entry.linkTitle { lines.append("**\(title)**") }
            if let url = entry.url { lines.append(url) }
            if let markdown = entry.markdownContent,
               markdown != "__failed__",
               !markdown.isEmpty {
                lines.append("")
                // Include first 500 chars of article content
                let preview = String(markdown.prefix(500))
                lines.append(preview + (markdown.count > 500 ? "..." : ""))
            }

        case .journal:
            lines.append("### 📓 Journal — \(time)")
            var emojiLine = ""
            if !entry.weatherEmoji.isEmpty { emojiLine += "**Weather:** \(entry.weatherEmoji)  " }
            if !entry.moodEmoji.isEmpty { emojiLine += "**Mood:** \(entry.moodEmoji)  " }
            if !entry.vibeEmoji.isEmpty { emojiLine += "**Vibe:** \(entry.vibeEmoji)" }
            if !emojiLine.isEmpty { lines.append(emojiLine) }
            if !entry.completedHabits.isEmpty {
                lines.append("**Habits:** \(entry.completedHabits.joined(separator: ", "))")
            }
            if !entry.text.isEmpty {
                lines.append("")
                lines.append(entry.text)
            }
            if let path = entry.journalImagePath,
               let data = MediaFileManager.load(path: path) {
                let filename = "\(entry.id.uuidString)_journal.jpg"
                try data.write(to: mediaURL.appendingPathComponent(filename))
                mediaFileCount += 1
                lines.append("")
                lines.append("![Journal Photo](media/\(filename))")
            }

        case .location:
            lines.append("### 📍 Place — \(time)")
            if let name = entry.locationName { lines.append("**\(name)**") }
            if let address = entry.locationAddress { lines.append(address) }
            if let lat = entry.locationLatitude, let lon = entry.locationLongitude {
                lines.append("*Coordinates: \(lat), \(lon)*")
            }
            if !entry.text.isEmpty {
                lines.append("")
                lines.append(entry.text)
            }

        case .sticky:
            lines.append("### ✅ List — \(time)")
            if let title = entry.stickyTitle, !title.isEmpty {
                lines.append("**\(title)**")
            }
            for item in entry.stickyItems {
                let parts = item.components(separatedBy: "::")
                guard parts.count == 2 else { continue }
                let id = parts[0]
                let text = parts[1]
                let checked = entry.stickyChecked.contains(id)
                lines.append("- [\(checked ? "x" : " ")] \(text)")
            }

        case .music:
            lines.append("### 🎵 Music — \(time)")
            if let title = entry.linkTitle { lines.append("**\(title)**") }
            if let artist = entry.musicArtist { lines.append("*\(artist)*") }
            if let album = entry.musicAlbum { lines.append(album) }
            if let url = entry.url { lines.append(url) }

        case .media:
            // Render movie/TV entry with metadata, status, rating, and any log entries
            let typeLabel = entry.mediaType == "tv" ? "TV Show" : "Movie"
            lines.append("### 🎬 \(typeLabel) — \(time)")
            if let title = entry.mediaTitle {
                var titleLine = "**\(title)**"
                if let year = entry.mediaYear { titleLine += " (\(year))" }
                lines.append(titleLine)
            }
            if let genre = entry.mediaGenre { lines.append("*\(genre)*") }
            if let status = entry.mediaStatus {
                let statusLabel: String
                switch status {
                case "wantTo":      statusLabel = "Want to Watch"
                case "inProgress":  statusLabel = "In Progress"
                case "finished":    statusLabel = "Finished"
                default:            statusLabel = status
                }
                lines.append("**Status:** \(statusLabel)")
            }
            if let rating = entry.mediaRating, rating > 0 {
                let stars = String(repeating: "★", count: rating) + String(repeating: "☆", count: 10 - rating)
                lines.append("**Rating:** \(stars) (\(rating)/10)")
            }
            if let overview = entry.mediaOverview, !overview.isEmpty {
                lines.append("")
                lines.append(overview)
            }
            if !entry.text.isEmpty {
                lines.append("")
                lines.append(entry.text)
            }
            if !entry.mediaLog.isEmpty {
                lines.append("")
                lines.append("**Log:**")
                for logEntry in entry.mediaLog {
                    let parts = logEntry.components(separatedBy: "::")
                    if parts.count == 2 {
                        lines.append("- \(parts[0]): \(parts[1])")
                    }
                }
            }
            if let path = entry.mediaCoverPath,
               let data = MediaFileManager.load(path: path) {
                let filename = "\(entry.id.uuidString)_cover.jpg"
                try data.write(to: mediaURL.appendingPathComponent(filename))
                mediaFileCount += 1
                lines.append("")
                lines.append("![Cover](media/\(filename))")
            }
        }

        // Tags
        if !entry.tagNames.isEmpty {
            let tagString = entry.tagNames.map { "#\($0)" }.joined(separator: " ")
            lines.append("")
            lines.append("**Tags:** \(tagString)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - README

    private static func readme() -> String {
        """
        # Commonplace Archive

        This archive was exported from Commonplace on \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short)).

        ## Structure

        - Weekly markdown files covering the last 30 days
        - `media/` folder containing all images and audio files
        - Media files are referenced inline in the markdown files

        ## Importing

        ### Obsidian
        Drop this folder into your Obsidian vault. Images and audio will display inline.

        ### Bear
        Import individual .md files via File → Import.

        ### Apple Notes
        Open each .md file and copy the contents.

        ## Entry Types

        | Icon | Type |
        |------|------|
        | 📝 | Note |
        | 📷 | Photo |
        | 🎙️ | Audio |
        | 🔗 | Link |
        | 📓 | Journal |
        | 📍 | Place |
        | ✅ | List |
        | 🎵 | Music |
        | 🎬 | Media |

        ---
        *Exported by Commonplace — your personal archive*
        """
    }
}

// MARK: - Errors

enum MarkdownExportError: LocalizedError {
    case noEntries
    case iCloudUnavailable

    var errorDescription: String? {
        switch self {
        case .noEntries:
            return "No entries found in the last 30 days."
        case .iCloudUnavailable:
            return "iCloud Drive is unavailable. Please check your iCloud settings."
        }
    }
}
