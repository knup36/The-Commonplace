// ShareViewController.swift
// CommonplaceShareExtension
//
// UIKit host for the SwiftUI ShareView.
// Responsibility: extract raw content as fast as possible, present UI immediately.
// No metadata fetching, no type detection beyond the basics.
// All enrichment (link previews, music metadata, Maps redirect) handled by
// ShareExtensionIngestor in the main app.
//
// Supported content types:
//   - URLs (web links, Apple Music links, Maps links)
//   - Images (including screenshots via public.png)
//   - Plain text
//
// Important notes:
//   - Screenshots share as public.png not public.image — check image BEFORE text
//   - loadItem must only be called ONCE per attachment to avoid hangs
//   - Memory limit is ~120MB — always use CGImageSource for downsampling

import UIKit
import SwiftUI
import UniformTypeIdentifiers
import Social
import MapKit

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        Task {
            await extractAndPresent()
        }
    }

    // MARK: - Content Extraction

    func extractAndPresent() async {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            cancel()
            return
        }

        var url: URL? = nil
        var imageData: Data? = nil
        var text: String? = nil

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for attachment in attachments {

                // Check for MKMapItem first — Apple Maps shares rich place data this way
                if attachment.hasItemConformingToTypeIdentifier("com.apple.mapkit.map-item") {
                    if let loaded = try? await attachment.loadItem(forTypeIdentifier: "com.apple.mapkit.map-item"),
                       let mapItem = loaded as? MKMapItem {
                        // Extract all place data directly from MKMapItem
                        url = nil // Don't save URL for map items — we have the coordinates
                        let coordinate = mapItem.placemark.coordinate
                        // Pass map item data via a special encoded URL we'll decode in the ingestor
                        let lat = coordinate.latitude
                        let lon = coordinate.longitude
                        let name = mapItem.name ?? ""
                        let address = [
                            mapItem.placemark.thoroughfare,
                            mapItem.placemark.locality,
                            mapItem.placemark.administrativeArea
                        ].compactMap { $0 }.joined(separator: ", ")
                        let category = mapItem.pointOfInterestCategory?.rawValue
                            .replacingOccurrences(of: "MKPOICategory", with: "") ?? ""
                        
                        // Encode as a special URL so SharedEntry can carry the data
                        var components = URLComponents()
                        components.scheme = "commonplace-location"
                        components.host = "mapitem"
                        components.queryItems = [
                            URLQueryItem(name: "lat", value: String(lat)),
                            URLQueryItem(name: "lon", value: String(lon)),
                            URLQueryItem(name: "name", value: name),
                            URLQueryItem(name: "address", value: address),
                            URLQueryItem(name: "category", value: category),
                        ]
                        url = components.url
                        break
                    }
                }

                // Check image FIRST — screenshots only provide public.png, not public.image
                let isImage = attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier)
                let isPNG = attachment.hasItemConformingToTypeIdentifier("public.png")

                if isImage || isPNG {
                    let typeID = isImage ? UTType.image.identifier : "public.png"
                    if let loaded = try? await attachment.loadItem(forTypeIdentifier: typeID) {
                        if let loadedURL = loaded as? URL,
                           FileManager.default.fileExists(atPath: loadedURL.path),
                           FileManager.default.isReadableFile(atPath: loadedURL.path) {
                            imageData = downsampleImage(at: loadedURL)
                        } else if let uiImage = loaded as? UIImage {
                            imageData = ImageProcessor.resizeAndCompress(image: uiImage)
                        } else if let data = loaded as? Data, let uiImage = UIImage(data: data) {
                            imageData = ImageProcessor.resizeAndCompress(image: uiImage)
                        }
                    }
                    if imageData != nil { break }

                } else if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let loaded = try? await attachment.loadItem(forTypeIdentifier: UTType.url.identifier),
                       let loadedURL = loaded as? URL {
                        url = loadedURL
                    } else {
                    }
                } else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let loaded = try? await attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier),
                       let loadedText = loaded as? String {
                        // Check if plain text is actually a URL
                        if loadedText.hasPrefix("http") || loadedText.hasPrefix("www"),
                           let detectedURL = URL(string: loadedText.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            url = detectedURL
                        } else {
                            text = loadedText
                        }
                    }
                }
            }
        }

        // Determine suggested type and available types based on content
        // No metadata fetching — just look at what we have
        let suggestedType: String
        let availableTypes: [String]
        
        if imageData != nil {
            suggestedType = "photo"
            availableTypes = ["photo", "text", "sticky"]
        } else if let urlString = url?.absoluteString {
            if urlString.contains("music.apple.com") {
                suggestedType = "music"
                availableTypes = ["link", "music", "media", "text"]
            } else if urlString.contains("maps.apple") || urlString.contains("maps.app") || urlString.contains("maps.google") {
                suggestedType = "location"
                availableTypes = ["location", "link", "text"]
            } else {
                suggestedType = "link"
                availableTypes = ["link", "music", "media", "text"]
            }
        } else if text != nil {
            suggestedType = "text"
            availableTypes = ["text", "sticky", "link"]
        } else {
            suggestedType = "text"
            availableTypes = ["text", "photo", "link", "music", "media", "sticky", "location"]
        }

        await MainActor.run {
            let shareView = ShareView(
                suggestedType: suggestedType,
                availableTypes: availableTypes,
                url: url?.absoluteString,
                imageData: imageData,
                initialText: text ?? "",
                onSave: { [weak self] sharedEntry in
                    try? AppGroupContainer.save(sharedEntry)
                    self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                },
                onCancel: { [weak self] in
                    self?.cancel()
                }
            )

            let hostingController = UIHostingController(rootView: shareView)
            hostingController.view.backgroundColor = .clear
            self.addChild(hostingController)
            self.view.addSubview(hostingController.view)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: self.view.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            ])
            hostingController.didMove(toParent: self)
        }
    }

    // MARK: - Image Downsampling

    func downsampleImage(at url: URL) -> Data? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, imageSourceOptions) else {
            return nil
        }
        let maxDimension: CGFloat = 1200
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ] as CFDictionary
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }
        return UIImage(cgImage: downsampledImage).jpegData(compressionQuality: 0.6)
    }

    // MARK: - Cancel

    func cancel() {
        extensionContext?.cancelRequest(withError: NSError(
            domain: "com.johncaldwell.commonplace",
            code: 0,
            userInfo: nil
        ))
    }
}
