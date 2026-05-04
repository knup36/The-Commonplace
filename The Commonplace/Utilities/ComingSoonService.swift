// ComingSoonService.swift
// Commonplace
//
// Manages the Coming Soon gift card — surfaces upcoming movie and TV release dates
// in the Feed on Mondays when something in the archive drops within 14 days.
//
// Responsibilities:
//   1. Monday cadence check — fires at most once per calendar week
//   2. Weekly TMDB refresh — re-fetches release dates for all future-dated media entries
//   3. Card evaluation — filters for entries releasing within 14 days
//   4. Archive write — snapshots the card to giftCard_archive for Chronicles
//
// UserDefaults keys:
//   comingSoon_lastShownWeek   — "YYYY-Www" string, ISO week of last card fire
//   comingSoon_lastRefreshWeek — "YYYY-Www" string, ISO week of last TMDB refresh
//
// This service is intentionally separate from GiftCardService — the Coming Soon card
// has a weekly cadence, shows multiple entries, and lives in the Feed rather than
// collection views. Shoehorning it into GiftCardService.evaluate() would be wrong.

import Foundation
import SwiftData

// MARK: - Coming Soon Card

struct ComingSoonCard: Identifiable {
    let id: String
    let items: [ComingSoonItem]
    let firedAt: Date
}

struct ComingSoonItem: Identifiable {
    let id: String          // entry UUID string
    let title: String
    let mediaType: String   // "movie" or "tv"
    let releaseDate: Date
    let coverPath: String?
    
    /// "in X days" or "tomorrow" or "today"
    var releaseDateLabel: String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: releaseDate)).day ?? 0
        switch days {
        case 0:  return "today"
        case 1:  return "tomorrow"
        default: return "in \(days) days"
        }
    }
}

// No separate record type needed — uses GiftCardRecord with comingSoonTitles populated

// MARK: - Service

struct ComingSoonService {
    
    // MARK: - ISO Week Key
    
    /// Returns a string like "2025-W03" representing the ISO week of the given date.
    /// Used as the deduplication key — one card per calendar week.
    static func isoWeekKey(for date: Date = Date()) -> String {
        let cal = Calendar(identifier: .iso8601)
        let week = cal.component(.weekOfYear, from: date)
        let year = cal.component(.yearForWeekOfYear, from: date)
        return "\(year)-W\(String(format: "%02d", week))"
    }
    
    static var isMonday: Bool {
            Calendar.current.component(.weekday, from: Date()) == 2
        }
    
    // MARK: - Main Entry Point
    
    /// Call from FeedView.onAppear inside a Task {}.
    /// Runs the TMDB refresh if needed, then evaluates and returns a card if one qualifies.
    /// All network work happens off the main thread — returns on MainActor.
    @MainActor
    static func runIfNeeded(entries: [Entry], modelContext: ModelContext) async -> ComingSoonCard? {
        guard isMonday else { return nil }
                
                let currentWeek = isoWeekKey()
        
        // Refresh TMDB dates once per week (independent of card fire)
        let lastRefreshWeek = UserDefaults.standard.string(forKey: "comingSoon_lastRefreshWeek") ?? ""
        if lastRefreshWeek != currentWeek {
            await refreshReleaseDates(entries: entries, modelContext: modelContext)
            UserDefaults.standard.set(currentWeek, forKey: "comingSoon_lastRefreshWeek")
        }
        
        // Only fire card once per week
        let lastShownWeek = UserDefaults.standard.string(forKey: "comingSoon_lastShownWeek") ?? ""
        guard lastShownWeek != currentWeek else { return nil }
                
                // Evaluate
                guard let card = evaluateCard(entries: entries) else { return nil }
                
                // Mark fired and archive
        UserDefaults.standard.set(currentWeek, forKey: "comingSoon_lastShownWeek")
        archiveCard(card)
        
        return card
    }
    
    // MARK: - TMDB Refresh
    
    /// Re-fetches release dates from TMDB for all movie/TV entries where
    /// mediaReleaseDate is still in the future or has never been fetched.
    /// Runs async — safe to call from a background Task.
    static func refreshReleaseDates(entries: [Entry], modelContext: ModelContext) async {
        let now = Date()
        let mediaEntries = entries.filter {
            $0.type == .media &&
            ($0.mediaType == "movie" || $0.mediaType == "tv") &&
            $0.tmdbID != nil &&
            // Only refresh entries whose release date is in the future, or never fetched
            ($0.mediaReleaseDate == nil || $0.mediaReleaseDate! > now)
        }
        
        for entry in mediaEntries {
            guard let tmdbID = entry.tmdbID,
                  let mediaTypeString = entry.mediaType,
                  let tmdbType = TMDBMediaType(rawValue: mediaTypeString)
            else { continue }
            
            let releaseDate = await TMDBService.fetchReleaseDate(id: tmdbID, type: tmdbType)
            
            await MainActor.run {
                entry.mediaReleaseDate = releaseDate
                entry.mediaReleaseDateFetched = Date()
                try? modelContext.save()
            }
        }
    }
    
    // MARK: - Evaluate
    
    /// Returns a ComingSoonCard if any media entries have a release date within the next 14 days.
    static func evaluateCard(entries: [Entry]) -> ComingSoonCard? {
            let now = Date()
            let cutoff = Calendar.current.date(byAdding: .day, value: 14, to: now) ?? now

        let qualifying = entries
                .filter {
                    $0.type == .media &&
                    ($0.mediaType == "movie" || $0.mediaType == "tv") &&
                    $0.mediaTitle != nil &&
                    $0.mediaReleaseDate != nil &&
                    $0.mediaReleaseDate! > now &&
                    $0.mediaReleaseDate! <= cutoff
                }
                .sorted { ($0.mediaReleaseDate ?? now) < ($1.mediaReleaseDate ?? now) }

            guard !qualifying.isEmpty else { return nil }
        
        let items = qualifying.map { entry in
            ComingSoonItem(
                id: entry.id.uuidString,
                title: entry.mediaTitle ?? "Unknown",
                mediaType: entry.mediaType ?? "movie",
                releaseDate: entry.mediaReleaseDate!,
                coverPath: entry.mediaCoverPath
            )
        }
        
        return ComingSoonCard(
            id: "comingSoon_\(isoWeekKey())",
            items: items,
            firedAt: now
        )
    }
    
    // MARK: - Archive
    
    /// Writes a snapshot of the card to giftCard_archive in UserDefaults.
    /// Uses GiftCardRecord with comingSoonTitles populated — same archive, same decoder.
    static func archiveCard(_ card: ComingSoonCard) {
        let titles = card.items.map { $0.title }
        let titleList = titles.joined(separator: ", ")
        let record = GiftCardRecord(
            id: card.id,
            cardType: GiftCardType.comingSoon.rawValue,
            title: "Coming Soon",
            message: titleList,
            icon: "popcorn.fill",
            entryID: "",
            firedAt: card.firedAt,
            comingSoonTitles: titles
        )
        
        var archive = GiftCardService.loadArchive()
        archive.removeAll { $0.id == record.id }
        archive.insert(record, at: 0)
        if archive.count > 10 { archive = Array(archive.prefix(10)) }
        if let data = try? JSONEncoder().encode(archive) {
            UserDefaults.standard.set(data, forKey: "giftCard_archive")
        }
    }
}
