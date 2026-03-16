import Foundation
import UIKit
import Security

/// Manages reading, writing, and deleting media files on the file system.
/// Files are stored in the app's iCloud container so they sync automatically across devices.
/// SwiftData stores only the file path string — never the raw Data blob.
///
/// 
struct MediaFileManager {

    // MARK: - Container URL

    /// Root URL for the iCloud container.
    /// Falls back to local Documents directory if iCloud is unavailable.
    static var containerURL: URL {
            if let icloudURL = FileManager.default.url(
                forUbiquityContainerIdentifier: "iCloud.com.johncaldwell.commonplace"
            ) {
                let documentsURL = icloudURL.appendingPathComponent("Documents")
                try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
                return documentsURL
            }
            // Fallback to local Documents if iCloud unavailable
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }

    // MARK: - Subdirectory URLs

    static var imagesURL: URL { containerURL.appendingPathComponent("media/images") }
    static var audioURL: URL  { containerURL.appendingPathComponent("media/audio") }
    static var previewsURL: URL { containerURL.appendingPathComponent("media/previews") }
    static var faviconsURL: URL { containerURL.appendingPathComponent("media/favicons") }

    // MARK: - Media Types

    enum MediaType {
        case image
        case audio
        case preview
        case favicon

        var directory: URL {
            switch self {
            case .image:   return MediaFileManager.imagesURL
            case .audio:   return MediaFileManager.audioURL
            case .preview: return MediaFileManager.previewsURL
            case .favicon: return MediaFileManager.faviconsURL
            }
        }

        var fileExtension: String {
            switch self {
            case .image:   return "jpg"
            case .audio:   return "m4a"
            case .preview: return "jpg"
            case .favicon: return "png"
            }
        }
    }

    // MARK: - Save

    /// Saves data to the file system and returns the relative path string.
    /// The returned path is what gets stored in SwiftData (e.g. "media/images/abc123.jpg").
    @discardableResult
    static func save(_ data: Data, type: MediaType, id: String? = nil) throws -> String {
            let directory = type.directory
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            print("Saving media to: \(directory.path)")

        let filename = "\(id ?? UUID().uuidString).\(type.fileExtension)"
        let fileURL = directory.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)

        // Return relative path for storage in SwiftData
        return "media/\(folderName(for: type))/\(filename)"
    }

    // MARK: - Load

    /// Loads data from a relative path string stored in SwiftData.
    static func load(path: String) -> Data? {
        let fileURL = containerURL.appendingPathComponent(path)
        return try? Data(contentsOf: fileURL)
    }

    /// Loads a UIImage from a relative path string.
    static func loadImage(path: String) -> UIImage? {
        guard let data = load(path: path) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Delete

    /// Deletes a file at the given relative path. Silently ignores missing files.
    static func delete(path: String) {
        let fileURL = containerURL.appendingPathComponent(path)
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Helpers

    private static func folderName(for type: MediaType) -> String {
        switch type {
        case .image:   return "images"
        case .audio:   return "audio"
        case .preview: return "previews"
        case .favicon: return "favicons"
        }
    }
    // MARK: - Debug

    static func debugContainerURL() {
        let icloudURL = FileManager.default.url(
            forUbiquityContainerIdentifier: "iCloud.com.johncaldwell.commonplace"
        )
        print("iCloud URL: \(String(describing: icloudURL))")
        print("Container URL being used: \(containerURL)")
    }
    // Call this once at app launch on a background thread
        static func initializeiCloudContainer() {
            DispatchQueue.global(qos: .utility).async {
                if let icloudURL = FileManager.default.url(
                    forUbiquityContainerIdentifier: "iCloud.com.johncaldwell.commonplace"
                ) {
                    let documentsURL = icloudURL.appendingPathComponent("Documents")
                    try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
                    print("iCloud container initialized: \(documentsURL)")
                } else {
                    print("iCloud container unavailable — using local storage")
                }
                
            }
            
        }
    
    
}
