// ImageProcessor.swift
// Commonplace
//
// Lightweight image resizing and compression utility.
// Used before saving any user photo to the iCloud container or SwiftData
// to avoid storing unnecessarily large files.
//
// Design decisions:
//   - Max 1200px on the longest side — sufficient for full-screen display
//     on any current iPhone, far smaller than a raw camera photo
//   - 0.6 JPEG compression quality — good visual quality at roughly 1/3
//     the file size of an uncompressed image
//   - Photos already exist at full resolution in the user's camera roll,
//     so Commonplace only needs screen-quality copies
//   - Returns Data directly so it can be passed straight to
//     MediaFileManager.save() or stored as journalImageData
//
// Usage:
//   let compressed = ImageProcessor.resizeAndCompress(image: uiImage)
//   entry.imagePath = try? MediaFileManager.save(compressed, type: .image, id: entry.id.uuidString)

import UIKit

struct ImageProcessor {

    // MARK: - Configuration

    /// Maximum dimension (width or height) of the output image in points.
    static let maxDimension: CGFloat = 1200

    /// JPEG compression quality. 0.0 = smallest file, 1.0 = best quality.
    static let compressionQuality: CGFloat = 0.6

    // MARK: - Public API

    /// Resizes a UIImage so its longest side is at most `maxDimension`,
    /// then compresses it as JPEG at `compressionQuality`.
    ///
    /// - Parameter image: The source image, typically from PhotosPicker or ImagePicker
    /// - Returns: Compressed JPEG data, or nil if the conversion fails
    static func resizeAndCompress(image: UIImage) -> Data? {
        let resized = resize(image: image)
        let compressed = resized.jpegData(compressionQuality: compressionQuality)
        return compressed
    }

    // MARK: - Private Helpers

    /// Returns a new UIImage scaled so its longest side is at most `maxDimension`.
    /// If the image is already smaller than the limit, it is returned unchanged.
    private static func resize(image: UIImage) -> UIImage {
        let size = image.size
        let longestSide = max(size.width, size.height)

        // Already within the limit — no resize needed
        guard longestSide > maxDimension else { return image }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
