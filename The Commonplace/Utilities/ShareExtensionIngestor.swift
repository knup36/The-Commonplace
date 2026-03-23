// ShareExtensionIngestor.swift
// Commonplace (main app only)
//
// Reads pending SharedEntry files from the App Group container
// and converts them into proper SwiftData Entry objects.
// Called from startupTasks() in The_CommonplaceApp on every launch.
//
// Flow:
//   1. Check App Group container for pending JSON files
//   2. Convert each SharedEntry to a SwiftData Entry
//   3. Save media files to iCloud container via MediaFileManager
//   4. Index entry in GRDB search index
//   5. Delete the pending JSON file
//
// Safe to call on every launch — does nothing if no pending entries exist.

import SwiftData
import Foundation
import UIKit
import LinkPresentation

struct ShareExtensionIngestor {
    
    @MainActor
    static func ingestPendingEntries(context: ModelContext) {
        guard let pending = try? AppGroupContainer.loadPending(), !pending.isEmpty else {
            return
        }
        
        print("ShareExtensionIngestor: ingesting \(pending.count) pending entries")
        
        for shared in pending {
            guard let entryType = EntryType(rawValue: shared.type) else {
                print("ShareExtensionIngestor: unknown entry type \(shared.type), skipping")
                AppGroupContainer.deletePending(id: shared.id)
                continue
            }
            
            let entry = Entry(type: entryType, text: shared.text, tags: shared.tags)
            entry.createdAt = shared.createdAt
            entry.tagNames = shared.tags
            
            // Handle type-specific fields
            switch entryType {
            case .link:
                entry.url = shared.url
                // Fetch link preview and article content in background
                if let urlString = shared.url {
                    Task {
                        let fetcher = await LinkPreviewFetcher()
                        await fetcher.fetch(urlString: urlString)
                        if let metadata = await fetcher.metadata {
                            entry.linkTitle = metadata.title
                            if let imageProvider = metadata.imageProvider {
                                imageProvider.loadObject(ofClass: UIImage.self) { image, _ in
                                    if let uiImage = image as? UIImage,
                                       let data = uiImage.jpegData(compressionQuality: 0.7) {
                                        DispatchQueue.main.async {
                                            entry.previewImagePath = try? MediaFileManager.save(
                                                data,
                                                type: .preview,
                                                id: entry.id.uuidString
                                            )
                                            try? context.save()
                                        }
                                    }
                                }
                            }
                        }
                        let result = await ArticleExtractor.extract(from: urlString)
                        if let markdown = result.markdown,
                           markdown.trimmingCharacters(in: .whitespacesAndNewlines).count > 200 {
                            entry.markdownContent = markdown
                            if entry.linkTitle == nil { entry.linkTitle = result.title }
                        } else {
                            entry.markdownContent = "__failed__"
                        }
                        try? context.save()
                    }
                }
                
            case .music:
                entry.url = shared.url
                if let urlString = shared.url {
                    Task {
                        let fetcher = await LinkPreviewFetcher()
                        await fetcher.fetch(urlString: urlString)
                        if let metadata = await fetcher.metadata {
                            await MainActor.run { entry.linkTitle = metadata.title }
                        }
                        // Extract track ID directly from Apple Music URL for accurate lookup
                        var trackID: String? = nil
                        if let urlComponents = URLComponents(string: urlString),
                           let itemID = urlComponents.queryItems?.first(where: { $0.name == "i" })?.value {
                            trackID = itemID
                        }

                        // Use direct ID lookup if available, fall back to title search
                        let searchQuery: String
                        if let id = trackID {
                            searchQuery = "https://itunes.apple.com/lookup?id=\(id)"
                        } else if let term = entry.linkTitle?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                            searchQuery = "https://itunes.apple.com/search?term=\(term)&limit=1&entity=song"
                        } else { return }

                        guard let apiURL = URL(string: searchQuery),
                              let (apiData, _) = try? await URLSession.shared.data(from: apiURL),
                              let json = try? JSONSerialization.jsonObject(with: apiData) as? [String: Any],
                              let results = json["results"] as? [[String: Any]],
                              let first = results.first
                        else { return }
                        
                        await MainActor.run {
                            entry.mediaArtist = first["artistName"] as? String
                            entry.mediaAlbum = first["collectionName"] as? String
                            entry.previewURL = first["previewUrl"] as? String
                            if let trackID = first["trackId"] as? Int {
                                entry.musicTrackID = String(trackID)
                            }
                        }
                        
                        if let artworkURLString = first["artworkUrl100"] as? String {
                            let hdURL = artworkURLString.replacingOccurrences(of: "100x100bb", with: "600x600bb")
                            if let artworkURL = URL(string: hdURL),
                               let (artworkData, _) = try? await URLSession.shared.data(from: artworkURL) {
                                await MainActor.run {
                                    entry.mediaArtworkPath = try? MediaFileManager.save(
                                        artworkData,
                                        type: .image,
                                        id: "\(entry.id.uuidString)_artwork"
                                    )
                                    try? context.save()
                                }
                            }
                        }
                    }
                }
                
            case .photo:
                if let imageData = shared.imageData,
                   let uiImage = UIImage(data: imageData),
                   let compressed = ImageProcessor.resizeAndCompress(image: uiImage) {
                    entry.imagePath = try? MediaFileManager.save(
                        compressed,
                        type: .image,
                        id: entry.id.uuidString
                    )
                }
                
            case .location:
                // Parse location from Maps URL if available
                entry.url = shared.url
            case .location:
                entry.url = shared.url
                print("📍 Location URL: \(shared.url ?? "nil")")
                entry.locationName = shared.locationName
                entry.locationAddress = shared.locationAddress
                if let lat = shared.locationLatitude,
                   let lon = shared.locationLongitude {
                    entry.locationLatitude = lat
                    entry.locationLongitude = lon
                }
                
            case .text, .audio, .journal, .sticky:
                break
            }
            
            context.insert(entry)
            
            // Create Tag objects for any new tags
            if let existingTags = try? context.fetch(FetchDescriptor<Tag>()) {
                let existingTagNames = Set(existingTags.map { $0.name })
                for tagName in shared.tags where !existingTagNames.contains(tagName) {
                    let tag = Tag(name: tagName)
                    context.insert(tag)
                }
            }
            
            // Index in search
            SearchIndex.shared.index(entry: entry)
            
            // Clean up pending file
            AppGroupContainer.deletePending(id: shared.id)
            
            print("ShareExtensionIngestor: ingested \(entryType.rawValue) entry")
        }
        
        try? context.save()
        print("ShareExtensionIngestor: ingestion complete")
    }
}
