// VideoProcessor.swift
// Commonplace
//
// Handles video compression and thumbnail generation for Shot entries.
// Compresses video to 540p using AVAssetExportSession.
// Generates a thumbnail from the first frame for feed card display.
//
// Kept lightweight — no editing, trimming, or filters.
// Just compress and thumbnail, that's it.

import AVFoundation
import UIKit

struct VideoProcessor {

    // MARK: - Compress

    /// Compresses a video to 540p MP4.
    /// Returns compressed Data or nil if compression fails.
    static func compress(url: URL) async -> Data? {
        let asset = AVURLAsset(url: url)
        
        // Use passthrough preset to preserve original dimensions and aspect ratio
        // This avoids black bars on vertical video
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetMediumQuality
        ) else { return nil }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        // Remove existing temp file if present
        try? FileManager.default.removeItem(at: outputURL)

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        await exportSession.export()

        guard exportSession.status == .completed else {
            print("VideoProcessor: compression failed — \(exportSession.error?.localizedDescription ?? "unknown")")
            return nil
        }

        let data = try? Data(contentsOf: outputURL)
        try? FileManager.default.removeItem(at: outputURL)
        return data
    }
    // MARK: - Thumbnail

    /// Generates a JPEG thumbnail from the first frame of a video.
    static func thumbnail(url: URL) -> Data? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)

        guard let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) else {
            return nil
        }

        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.7)
    }
}
