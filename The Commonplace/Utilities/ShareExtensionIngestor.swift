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
//   4. Save to SwiftData context
//   5. Index entry in GRDB search index (AFTER save — ensures data is committed)
//   6. For async types (link, music): re-index after metadata fetch completes
//   7. Delete the pending JSON file
//
// Safe to call on every launch — does nothing if no pending entries exist.
//
// Note: .media entries are never created via the share extension.
// Media (movies/TV) are always added directly within the app.
//
// Search indexing note:
//   index(entry:) is called AFTER context.save() to ensure SwiftData has committed
//   the entry before indexing. For link and music entries, index(entry:) is called
//   a second time after async metadata fetching completes, so the index always
//   reflects the final populated state of the entry.

import SwiftData
import Foundation
import UIKit
import LinkPresentation
import CoreLocation

struct ShareExtensionIngestor {
    
    @MainActor
    static func ingestPendingEntries(context: ModelContext) {
        guard let pending = try? AppGroupContainer.loadPending(), !pending.isEmpty else {
            return
        }
        
        print("ShareExtensionIngestor: ingesting \(pending.count) pending entries")
        for shared in pending {
            print("ShareExtensionIngestor: found entry type=\(shared.type) url=\(shared.url ?? "nil")")
        }
        
        for shared in pending {
            print("ShareExtensionIngestor: ingesting type=\(shared.type) url=\(shared.url ?? "nil")")
            guard let entryType = EntryType(rawValue: shared.type) else {
                print("ShareExtensionIngestor: unknown entry type \(shared.type), skipping")
                AppGroupContainer.deletePending(id: shared.id)
                continue
            }
            
            let entry = Entry(type: entryType, text: shared.text, tags: shared.tags)
            entry.createdAt = shared.createdAt
            entry.tagNames = shared.tags
            entry.captureLatitude = shared.captureLatitude
            entry.captureLongitude = shared.captureLongitude
            entry.captureLocationName = shared.captureLocationName
            
            // Handle type-specific fields
            switch entryType {
            case .link:
                entry.url = shared.url
                // Auto-detect content type from URL before async work
                if let urlString = shared.url {
                    entry.linkContentType = detectLinkContentType(urlString: urlString)
                }
                // Fetch link preview and article content in background.
                // Re-indexes after metadata arrives so search reflects full content.
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
                            // Upgrade to article if not already set to video
                            if entry.linkContentType == nil {
                                entry.linkContentType = "article"
                            }
                        } else {
                            entry.markdownContent = "__failed__"
                        }
                        try? context.save()
                        SearchIndex.shared.index(entry: entry)
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
                            entry.musicArtist = first["artistName"] as? String
                            entry.musicAlbum = first["collectionName"] as? String
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
                                    entry.musicArtworkPath = try? MediaFileManager.save(
                                        artworkData,
                                        type: .image,
                                        id: "\(entry.id.uuidString)_artwork"
                                    )
                                    try? context.save()
                                    // Re-index now that artist, album and track info are populated
                                    SearchIndex.shared.index(entry: entry)
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
                    // Run OCR on the saved image
                    Task {
                        let result = await VisionService.analyze(imageData: compressed)
                        await MainActor.run {
                            entry.extractedText = result.extractedText.isEmpty ? nil : result.extractedText
                            entry.visionTags = result.tags
                            try? context.save()
                            SearchIndex.shared.index(entry: entry)
                        }
                    }
                }
            case .location:
                entry.locationName = shared.locationName
                entry.locationAddress = shared.locationAddress
                if let lat = shared.locationLatitude,
                   let lon = shared.locationLongitude {
                    entry.locationLatitude = lat
                    entry.locationLongitude = lon
                } else if let urlString = shared.url {
                    if urlString.hasPrefix("commonplace-location://mapitem") {
                        // Rich MKMapItem data encoded by share extension
                        if let components = URLComponents(string: urlString),
                           let queryItems = components.queryItems {
                            let lat = queryItems.first(where: { $0.name == "lat" }).flatMap { Double($0.value ?? "") }
                            let lon = queryItems.first(where: { $0.name == "lon" }).flatMap { Double($0.value ?? "") }
                            let name = queryItems.first(where: { $0.name == "name" })?.value
                            let address = queryItems.first(where: { $0.name == "address" })?.value
                            let category = queryItems.first(where: { $0.name == "category" })?.value

                            entry.locationLatitude = lat
                            entry.locationLongitude = lon
                            entry.locationName = name
                            entry.locationAddress = address
                            entry.locationCategory = category?.isEmpty == false ? category : nil
                        }
                    } else {
                        // Regular Maps short URL — resolve the redirect
                        Task {
                            await resolveMapsURL(urlString: urlString, entry: entry, context: context)
                        }
                    }
                }

            case .text, .audio, .journal, .sticky, .media:
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

            // Save BEFORE indexing — ensures SwiftData has committed the entry
            // so the index reflects the actual persisted state
            try? context.save()

            // Initial index — captures all synchronously available fields
            SearchIndex.shared.index(entry: entry)
            
            // Clean up pending file
            AppGroupContainer.deletePending(id: shared.id)
            
            print("ShareExtensionIngestor: ingested \(entryType.rawValue) entry")
        }
        
        print("ShareExtensionIngestor: ingestion complete")
    }
    @MainActor
    static func resolveMapsURL(urlString: String, entry: Entry, context: ModelContext) async {
        guard let url = URL(string: urlString) else { return }
        
        // Follow redirects to get the final URL
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        guard let (_, response) = try? await URLSession.shared.data(from: url),
              let finalURL = (response as? HTTPURLResponse)?.url ?? url as URL? else {
            print("ShareExtensionIngestor: failed to resolve Maps URL")
            return
        }
        
        // Try to extract coordinates from the final URL
        // Apple Maps format: ?ll=lat,lon or ?q=lat,lon or ?daddr=lat,lon
        guard let components = URLComponents(url: finalURL, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return
        }
        
        var lat: Double? = nil
        var lon: Double? = nil
        var name: String? = nil
        
        // Try ?ll=lat,lon
        if let ll = queryItems.first(where: { $0.name == "ll" })?.value {
            let parts = ll.split(separator: ",")
            if parts.count == 2 {
                lat = Double(parts[0])
                lon = Double(parts[1])
            }
        }
        
        // Try ?q=lat,lon or ?q=place+name
        if lat == nil, let q = queryItems.first(where: { $0.name == "q" })?.value {
            let parts = q.split(separator: ",")
            if parts.count == 2, let parsedLat = Double(parts[0]), let parsedLon = Double(parts[1]) {
                lat = parsedLat
                lon = parsedLon
            } else {
                name = q
            }
        }
        
        // Try ?daddr=lat,lon
        if lat == nil, let daddr = queryItems.first(where: { $0.name == "daddr" })?.value {
            let parts = daddr.split(separator: ",")
            if parts.count == 2 {
                lat = Double(parts[0])
                lon = Double(parts[1])
            }
        }

        // Try ?address=
        if name == nil, let address = queryItems.first(where: { $0.name == "address" })?.value {
            name = address
        }

        // Update entry with resolved data
        if let lat, let lon {
            entry.locationLatitude = lat
            entry.locationLongitude = lon
            print("ShareExtensionIngestor: resolved coordinates \(lat), \(lon)")
            
            // Reverse geocode to get a place name
            let location = CLLocation(latitude: lat, longitude: lon)
            let geocoder = CLGeocoder()
            if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
               let placemark = placemarks.first {
                var parts: [String] = []
                if let subLocality = placemark.subLocality {
                    parts.append(subLocality)
                } else if let area = placemark.areasOfInterest?.first {
                    parts.append(area)
                }
                if let city = placemark.locality { parts.append(city) }
                if let state = placemark.administrativeArea { parts.append(state) }
                entry.locationName = parts.isEmpty ? placemark.name : parts.joined(separator: ", ")
                entry.locationAddress = placemark.thoroughfare
            }
        } else if let name {
            entry.locationName = name
            print("ShareExtensionIngestor: resolved place name \(name)")
        }
        
        try? context.save()
        SearchIndex.shared.index(entry: entry)
    }
    // MARK: - Link Content Type Detection

    static func detectLinkContentType(urlString: String) -> String? {
        let lower = urlString.lowercased()

        // Video platforms
        let videoDomains = [
            "youtube.com", "youtu.be",
            "vimeo.com",
            "tiktok.com",
            "twitch.tv",
            "dailymotion.com"
        ]
        for domain in videoDomains {
            if lower.contains(domain) { return "video" }
        }

        // Everything else gets detected after article extraction
        // returns nil here — upgraded to "article" if extraction succeeds
        return nil
    }
}
