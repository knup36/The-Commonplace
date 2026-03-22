// ImageCache.swift
// Commonplace
//
// Shared in-memory cache for decoded thumbnail images in the feed.
// Keyed by file path string — the same path stored on Entry.imagePath.
//
// Uses NSCache which automatically evicts entries under memory pressure,
// making it safe to use without manual size management.
// Cache is intentionally not persisted to disk — it rebuilds automatically
// as the user scrolls.

import UIKit

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, NSData>()

    private init() {
        // Limit to 50 images in memory at once
        cache.countLimit = 50
    }

    func get(path: String) -> Data? {
        cache.object(forKey: path as NSString) as Data?
    }

    func set(path: String, data: Data) {
        cache.setObject(data as NSData, forKey: path as NSString)
    }
}
