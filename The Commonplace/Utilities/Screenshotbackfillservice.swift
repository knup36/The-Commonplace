// ScreenshotBackfillService.swift
// Commonplace
//
// One-time backfill service that detects screenshots among existing Shot entries.
// Runs at launch as a detached background task — processes entries in batches
// to avoid memory pressure.
//
// Detection:
//   Uses ImageProcessor.isScreenshot(data:) which checks for camera EXIF metadata.
//   Real photos have FNumber and ExposureTime in EXIF. Screenshots do not.
//
// Safety:
//   - Only processes entries where isScreenshotDetected == false
//   - Sets isScreenshotDetected = true after processing — never re-runs on same entry
//   - Skips entries with no imagePath (video shots, entries missing media)
//   - Saves in batches of 10 to avoid overwhelming SwiftData
//   - Runs as a detached Task — never blocks the main thread
//
// Architecture:
//   Same pattern as HealthKitBackfillService — safe to call repeatedly,
//   no-ops once all entries are processed.

import Foundation
import SwiftData

class ScreenshotBackfillService {

    static let shared = ScreenshotBackfillService()

    func backfillIfNeeded(entries: [Entry], context: ModelContext) async {
        let toProcess = entries.filter {
            $0.type == .photo &&
            !$0.isScreenshotDetected &&
            $0.imagePath != nil &&
            $0.videoPath == nil  // skip video shots — no EXIF detection needed
        }

        guard !toProcess.isEmpty else { return }

        print("ScreenshotBackfillService: processing \(toProcess.count) Shot entries")

        let batchSize = 10
        for batch in stride(from: 0, to: toProcess.count, by: batchSize) {
            let end = min(batch + batchSize, toProcess.count)
            let batchEntries = Array(toProcess[batch..<end])

            await withTaskGroup(of: Void.self) { group in
                for entry in batchEntries {
                    group.addTask { await self.process(entry: entry) }
                }
            }

            await MainActor.run {
                try? context.save()
            }

            // Small yield between batches to keep app responsive
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }

        print("ScreenshotBackfillService: backfill complete")
    }

    // MARK: - Private

    private func process(entry: Entry) async {
        await MainActor.run {
            guard let path = entry.imagePath,
                  let data = MediaFileManager.load(path: path) else {
                // Can't load image — mark as detected to prevent retrying
                entry.isScreenshotDetected = true
                return
            }
            entry.isScreenshot = ImageProcessor.isScreenshot(data: data)
            entry.isScreenshotDetected = true
        }
    }
}
