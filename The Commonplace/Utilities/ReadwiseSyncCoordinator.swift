// ReadwiseSyncCoordinator.swift
// Commonplace
//
// Converts Readwise/Reader API responses into Commonplace Entry objects.
// This is the business logic layer between ReadwiseService (networking) and
// SwiftData (storage). It has no knowledge of UI or networking — it only
// knows how to map ReaderDocumentWithHighlights → Entry.
//
// Sync behaviour:
//   - New document (no existing entry with matching readwiseSourceID):
//       → Creates a new .link Entry
//       → Sets createdAt to the original Reader saved date (not today)
//       → Formats all highlights as a bullet list in entry.text
//       → Stores all highlight IDs in readwiseImportedHighlightIDs
//       → Auto-tags with "readwise" and "article"
//
//   - Existing document (entry with matching readwiseSourceID found):
//       → Compares incoming highlight IDs against readwiseImportedHighlightIDs
//       → Appends ONLY new highlights to the bottom of entry.text
//       → Adds new highlight IDs to readwiseImportedHighlightIDs
//       → Never overwrites existing text — append only
//
//   - Deleted entries are re-imported on next sync (Reader tag is source of truth)
//
// Auto-tagging:
//   - All Readwise entries receive: "readwise", "article"
//   - Tags are added to tagNames (the standard Commonplace tag mechanism)
//
// Search indexing:
//   - All created or updated entries are passed to SearchIndex for FTS5 indexing
//
// Usage:
//   let coordinator = ReadwiseSyncCoordinator(modelContext: context, searchIndex: index)
//   let summary = try await coordinator.sync(documents: pairedDocuments)

import Foundation
import SwiftData

// MARK: - Sync Summary

/// Returned after a sync run — used to display results in the Settings UI.
struct ReadwiseSyncSummary {
    let newEntries: Int
    let updatedEntries: Int
    let newHighlightsAppended: Int
    let syncedAt: Date
    
    var displayMessage: String {
        if newEntries == 0 && updatedEntries == 0 {
            return "Already up to date."
        }
        var parts: [String] = []
        if newEntries > 0 {
            parts.append("\(newEntries) new \(newEntries == 1 ? "article" : "articles")")
        }
        if updatedEntries > 0 {
            parts.append("\(updatedEntries) updated with \(newHighlightsAppended) new \(newHighlightsAppended == 1 ? "highlight" : "highlights")")
        }
        return parts.joined(separator: ", ") + "."
    }
}

// MARK: - Coordinator

@MainActor
class ReadwiseSyncCoordinator {
    
    private let modelContext: ModelContext
    private let searchIndex: SearchIndex
    
    // Tags automatically applied to every Readwise-imported entry
    private let autoTags = ["readwise", "article"]
    
    init(modelContext: ModelContext, searchIndex: SearchIndex) {
        self.modelContext = modelContext
        self.searchIndex = searchIndex
    }
    
    // MARK: - Public
    
    /// Main entry point. Processes all paired documents from ReadwiseService
    /// and creates or updates Commonplace entries accordingly.
    func sync(documents: [ReaderDocumentWithHighlights]) throws -> ReadwiseSyncSummary {
        var newEntries = 0
        var updatedEntries = 0
        var newHighlightsAppended = 0
        
        for paired in documents {
            // Skip documents with no highlights — nothing meaningful to import
                        guard !paired.highlights.isEmpty else { continue }
            
            if let existing = try findExistingEntry(sourceID: paired.document.id) {
                // Entry already exists — check for new highlights only
                let appended = appendNewHighlights(to: existing, from: paired.highlights)
                if appended > 0 {
                    existing.touch()
                    updatedEntries += 1
                    newHighlightsAppended += appended
                    searchIndex.index(entry: existing)
                }
            } else {
                // Brand new document — create a fresh entry
                let entry = createEntry(from: paired)
                modelContext.insert(entry)
                newEntries += 1
                searchIndex.index(entry: entry)
            }
        }
        
        try modelContext.save()
        
        return ReadwiseSyncSummary(
            newEntries: newEntries,
            updatedEntries: updatedEntries,
            newHighlightsAppended: newHighlightsAppended,
            syncedAt: Date()
        )
    }
    
    // MARK: - Entry Creation
    
    /// Creates a brand new .link Entry from a Reader document and its highlights.
    private func createEntry(from paired: ReaderDocumentWithHighlights) -> Entry {
        let doc = paired.document
        
        let entry = Entry(type: .link, text: "", tags: autoTags)
        
        // Identity
        entry.readwiseSourceID = doc.id
        
        // Dates — use Reader's saved_at / created_at, fall back to now
        entry.createdAt = parseDate(doc.createdAt) ?? Date()
        entry.modifiedAt = Date()
        
        // Link fields — source_url is the real article URL; url is the Reader wrapper URL
        entry.url = doc.sourceURL ?? doc.url
        entry.linkTitle = doc.title
        entry.linkContentType = "article"
        
        // Cover image — download and save locally so LinkPreviewView can load it
                if let imageURLString = doc.imageURL, let imageURL = URL(string: imageURLString) {
                    do {
                        let data = try Data(contentsOf: imageURL)
                        entry.previewImagePath = try MediaFileManager.save(data, type: .preview, id: entry.id.uuidString)
                    } catch {
                        AppLogger.warning("Could not download cover image for \(doc.title ?? doc.id)", domain: .media)
                    }
                }
        
        // Build the highlight bullet list
        let (bulletText, highlightIDs) = formatHighlights(paired.highlights)
        entry.text = bulletText
        entry.readwiseImportedHighlightIDs = highlightIDs
        
        return entry
    }
    
    // MARK: - Highlight Appending
    
    /// Checks incoming highlights against already-imported IDs and appends only new ones.
    /// Returns the count of newly appended highlights.
    @discardableResult
    private func appendNewHighlights(to entry: Entry, from highlights: [ReaderDocument]) -> Int {
        let alreadyImported = Set(entry.readwiseImportedHighlightIDs)
        let newHighlights = highlights.filter { !alreadyImported.contains($0.id) }
        
        guard !newHighlights.isEmpty else { return 0 }
        
        let (newBullets, newIDs) = formatHighlights(newHighlights)
        
        // Append to existing text with a blank line separator
        if entry.text.isEmpty {
            entry.text = newBullets
        } else {
            entry.text += "\n\n" + newBullets
        }
        
        entry.readwiseImportedHighlightIDs += newIDs
        
        return newHighlights.count
    }
    
    // MARK: - Formatting
    
    /// Formats an array of highlight documents into a bullet list string
    /// and returns both the formatted text and the list of highlight IDs.
    ///
    /// Example output:
    ///   • "The best way to predict the future is to create it."
    ///   • "Consistency beats intensity every single time."
    private func formatHighlights(_ highlights: [ReaderDocument]) -> (text: String, ids: [String]) {
        // Sort highlights by created_at so they appear in reading order
        let sorted = highlights.sorted {
            let a = parseDate($0.createdAt) ?? Date.distantPast
            let b = parseDate($1.createdAt) ?? Date.distantPast
            return a < b
        }
        
        let paragraphs = sorted.compactMap { highlight -> String? in
                    // Reader highlights store the highlighted text in the content field
                    guard let text = highlight.content, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return nil
                    }
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                let ids = sorted.map { $0.id }
                
                return (paragraphs.joined(separator: "\n\n"), ids)
    }
    
    // MARK: - SwiftData Lookup
    
    /// Finds an existing Entry by its readwiseSourceID.
    /// Returns nil if no match found.
    private func findExistingEntry(sourceID: String) throws -> Entry? {
        let descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate { entry in
                entry.readwiseSourceID == sourceID
            }
        )
        let results = try modelContext.fetch(descriptor)
        return results.first
    }
    
    // MARK: - Date Parsing
    
    /// Parses an ISO8601 date string from the Readwise API.
    /// Handles both fractional seconds (e.g. "2023-03-26T21:02:51.618751+00:00")
    /// and standard format (e.g. "2023-03-26T21:02:51+00:00").
    private func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        
        // Try with fractional seconds first (Readwise uses microseconds)
        let formatterWithFraction = ISO8601DateFormatter()
        formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFraction.date(from: string) {
            return date
        }
        
        // Fall back to standard ISO8601
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
