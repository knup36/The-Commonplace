// GiftCardService.swift
// Commonplace
//
// Evaluates Gift Card eligibility and manages the archive.
// Gift Cards are ambient, joyful nudges that surface when the data earns them.
//
// Evaluation rules:
//   - One card per day maximum (bypassed in test mode)
//   - Staleness thresholds bypassed in test mode
//   - Snoozed entries skipped (30-day snooze per dismissal)
//   - Most stale entry wins when multiple qualify
//   - Tie-break: inProgress > wantTo, location > media
//
// UserDefaults keys:
//   giftCardLastShownDate          — Date, last time any card fired
//   giftCard_snoozed_{type}_{id}   — Date, snooze start for a specific card
//   giftCard_archive               — JSON [GiftCardRecord], max 10 items
//   giftCardTestMode               — Bool, bypasses time rules for testing

import Foundation
import SwiftData
import UIKit
import WidgetKit

// MARK: - GiftCard

struct GiftCard: Identifiable {
    let id: String
    let cardType: GiftCardType
    let title: String
    let message: String
    let icon: String
    let entryID: String
    let entry: Entry
    let firedAt: Date
}

// MARK: - GiftCardType

enum GiftCardType: String, Codable {
    case unfinishedMedia    = "unfinishedMedia"
    case forgottenWatchlist = "forgottenWatchlist"
    case placeRevisit       = "placeRevisit"
    
    var snoozeKey: String { "giftCard_snoozed_\(rawValue)" }
}

// MARK: - GiftCardRecord (Codable for archive)

struct GiftCardRecord: Codable, Identifiable {
    let id: String
    let cardType: String
    let title: String
    let message: String
    let icon: String
    let entryID: String
    let firedAt: Date
}

// MARK: - GiftCardService

struct GiftCardService {
    
    // MARK: - Test Mode
    
    static var testMode: Bool {
        UserDefaults.standard.bool(forKey: "giftCardTestMode")
    }
    
    // MARK: - Thresholds
    
    /// Days before an inProgress media entry is considered stale
    static var inProgressThresholdDays: Int { testMode ? 0 : 30 }
    
    /// Days before a watchlist entry is considered forgotten
    static var watchlistThresholdDays: Int { testMode ? 0 : 90 }
    
    /// Days before an unvisited location is considered forgotten
    static var placeThresholdDays: Int { testMode ? 0 : 90 }
    
    /// Days a dismissed card is snoozed
    static let snoozeDays: Int = 30
    
    // MARK: - Evaluate
    
    /// Returns the single most relevant Gift Card, or nil if nothing qualifies.
    static func evaluate(entries: [Entry], allowMedia: Bool = true, allowLocation: Bool = true) -> GiftCard? {
        
        // One per day — unless test mode
        if !testMode {
            if let lastShown = UserDefaults.standard.object(forKey: "giftCardLastShownDate") as? Date,
               Calendar.current.isDateInToday(lastShown) {
                return nil
            }
        }
        
        let now = Date()
        var candidates: [(card: GiftCard, staleness: TimeInterval)] = []
        
        for entry in entries {
            if allowMedia {
                if let card = evaluateUnfinishedMedia(entry: entry, now: now) {
                    let staleness = now.timeIntervalSince(entry.modifiedAt ?? entry.createdAt)
                    candidates.append((card, staleness))
                }
                if let card = evaluateForgottenWatchlist(entry: entry, now: now) {
                    let staleness = now.timeIntervalSince(entry.createdAt)
                    candidates.append((card, staleness))
                }
            }
            if allowLocation {
                if let card = evaluatePlaceRevisit(entry: entry, now: now) {
                    let staleness = now.timeIntervalSince(entry.createdAt)
                    candidates.append((card, staleness))
                }
            }
        }
        
        // Sort by staleness descending, tie-break by type priority
        let sorted = candidates.sorted { a, b in
            if abs(a.staleness - b.staleness) > 86400 { // > 1 day difference
                return a.staleness > b.staleness
            }
            return typePriority(a.card.cardType) > typePriority(b.card.cardType)
        }
        
        guard let winner = sorted.first?.card else { return nil }
        
        // Record that a card fired today
                UserDefaults.standard.set(Date(), forKey: "giftCardLastShownDate")
                
                // Add to archive
                addToArchive(winner)

        // Write thumbnail to App Group if cover art exists
                var thumbnailPath: String? = nil
                if let coverPath = winner.entry.mediaCoverPath,
                   let imageData = MediaFileManager.load(path: coverPath),
                   let uiImage = UIImage(data: imageData),
                   let thumbData = uiImage.jpegData(compressionQuality: 0.6) {
                    thumbnailPath = GiftCardSnapshotStore.saveThumbnail(thumbData, id: winner.entryID)
                }

                // Write to App Group for widget
                let snapshot = GiftCardSnapshot(
                    title: winner.title,
                    message: winner.message,
                    icon: winner.icon,
                    firedAt: winner.firedAt,
                    isEmpty: false,
                    thumbnailPath: thumbnailPath
                )
                GiftCardSnapshotStore.save(snapshot)
                WidgetCenter.shared.reloadAllTimelines()
                
                return winner
    }
    
    // MARK: - Card Rules
    
    private static func evaluateUnfinishedMedia(entry: Entry, now: Date) -> GiftCard? {
        guard entry.type == .media,
              entry.mediaStatus == "inProgress",
              let title = entry.mediaTitle else { return nil }
        
        let reference = entry.modifiedAt ?? entry.createdAt
        let days = Calendar.current.dateComponents([.day], from: reference, to: now).day ?? 0
        guard days >= inProgressThresholdDays else { return nil }
        
        let id = "\(GiftCardType.unfinishedMedia.rawValue)_\(entry.id.uuidString)"
        guard !isSnoozed(id: id) else { return nil }
        
        let weeks = max(1, days / 7)
        let timeString = weeks == 1 ? "a week" : "\(weeks) weeks"
        
        return GiftCard(
            id: id,
            cardType: .unfinishedMedia,
            title: "Still watching?",
            message: "You started \(title) \(timeString) ago and haven't logged anything since.",
            icon: "play.circle",
            entryID: entry.id.uuidString,
            entry: entry,
            firedAt: now
        )
    }
    
    private static func evaluateForgottenWatchlist(entry: Entry, now: Date) -> GiftCard? {
        guard entry.type == .media,
              entry.mediaStatus == "wantTo",
              let title = entry.mediaTitle else { return nil }
        
        let days = Calendar.current.dateComponents([.day], from: entry.createdAt, to: now).day ?? 0
        guard days >= watchlistThresholdDays else { return nil }
        
        let id = "\(GiftCardType.forgottenWatchlist.rawValue)_\(entry.id.uuidString)"
        guard !isSnoozed(id: id) else { return nil }
        
        let months = max(1, days / 30)
        let timeString = months == 1 ? "a month" : "\(months) months"
        
        return GiftCard(
            id: id,
            cardType: .forgottenWatchlist,
            title: "Still on your list?",
            message: "\(title) has been on your watchlist for \(timeString).",
            icon: "bookmark",
            entryID: entry.id.uuidString,
            entry: entry,
            firedAt: now
        )
    }
    
    private static func evaluatePlaceRevisit(entry: Entry, now: Date) -> GiftCard? {
        guard entry.type == .location,
              entry.locationVisited == false,
              let name = entry.locationName else { return nil }
        
        let days = Calendar.current.dateComponents([.day], from: entry.createdAt, to: now).day ?? 0
        guard days >= placeThresholdDays else { return nil }
        
        let id = "\(GiftCardType.placeRevisit.rawValue)_\(entry.id.uuidString)"
        guard !isSnoozed(id: id) else { return nil }
        
        let months = max(1, days / 30)
        let timeString = months == 1 ? "a month" : "\(months) months"
        
        return GiftCard(
            id: id,
            cardType: .placeRevisit,
            title: "Still want to go?",
            message: "You saved \(name) \(timeString) ago and haven't visited yet.",
            icon: "mappin.circle",
            entryID: entry.id.uuidString,
            entry: entry,
            firedAt: now
        )
    }
    
    // MARK: - Snooze
    
    static func snooze(cardID: String) {
        UserDefaults.standard.set(Date(), forKey: "giftCard_snoozed_\(cardID)")
    }
    
    private static func isSnoozed(id: String) -> Bool {
        guard let snoozeStart = UserDefaults.standard.object(
            forKey: "giftCard_snoozed_\(id)"
        ) as? Date else { return false }
        let daysSince = Calendar.current.dateComponents([.day], from: snoozeStart, to: Date()).day ?? 0
        return daysSince < snoozeDays
    }
    
    // MARK: - Archive
    
    static func loadArchive() -> [GiftCardRecord] {
        guard let data = UserDefaults.standard.data(forKey: "giftCard_archive"),
              let records = try? JSONDecoder().decode([GiftCardRecord].self, from: data)
        else { return [] }
        return records
    }
    
    private static func addToArchive(_ card: GiftCard) {
        var archive = loadArchive()
        let record = GiftCardRecord(
            id: card.id,
            cardType: card.cardType.rawValue,
            title: card.title,
            message: card.message,
            icon: card.icon,
            entryID: card.entryID,
            firedAt: card.firedAt
        )
        // Remove existing record for same card if present
        archive.removeAll { $0.id == card.id }
        // Insert at front
        archive.insert(record, at: 0)
        // Cap at 10
        if archive.count > 10 { archive = Array(archive.prefix(10)) }
        if let data = try? JSONEncoder().encode(archive) {
            UserDefaults.standard.set(data, forKey: "giftCard_archive")
        }
    }
    
    // MARK: - Type Priority
    
    private static func typePriority(_ type: GiftCardType) -> Int {
        switch type {
        case .unfinishedMedia:    return 3
        case .forgottenWatchlist: return 2
        case .placeRevisit:       return 1
        }
    }
}
