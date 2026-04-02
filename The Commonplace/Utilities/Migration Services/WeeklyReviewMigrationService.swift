// WeeklyReviewMigrationService.swift
// Commonplace
//
// One-time migration service that moves Weekly Review structured data
// out of entry.text key:value encoding into dedicated typed fields.
//
// Runs at launch via startupTasks(). Safe to call repeatedly —
// skips entries that already have weeklyReviewHighlight set OR
// that have no key:value data in entry.text to migrate.
//
// After migration, entry.text is cleared so it is always
// user-visible note text only — never structured data.

import SwiftData
import Foundation

class WeeklyReviewMigrationService {
    static let shared = WeeklyReviewMigrationService()
    private init() {}

    func migrateIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Entry>()
        guard let allEntries = try? context.fetch(descriptor) else { return }

        let reviewEntries = allEntries.filter {
            $0.tagNames.contains(WeeklyReviewTheme.weeklyReviewTag) &&
            $0.weeklyReviewHighlight == nil &&
            !$0.text.isEmpty
        }

        guard !reviewEntries.isEmpty else { return }

        for entry in reviewEntries {
            let parsed = parse(entry.text)

            // Build stats dictionary and encode as JSON
            var stats: [String: String] = [:]
            if let v = parsed["entries"]  { stats["entries"] = v }
            if let v = parsed["habits"]   { stats["habits"] = v }
            if let v = parsed["avgmood"]  { stats["avgmood"] = v }
            if let v = parsed["avgcal"]   { stats["avgcal"] = v }
            if let v = parsed["people"]   { stats["people"] = v }
            if let v = parsed["tags"]     { stats["tags"] = v }
            if let v = parsed["music"]    { stats["music"] = v }
            if let v = parsed["media"]    { stats["media"] = v }
            entry.weeklyReviewStats = try? JSONEncoder().encode(stats)

            // Move reflection answers to dedicated fields
            entry.weeklyReviewHighlight    = parsed["highlight"]
            entry.weeklyReviewCarryForward = parsed["carry"]
            entry.weeklyReviewGratitude    = parsed["gratitude"]

            // Clear entry.text — it should never hold structured data
            entry.text = ""
        }

        try? context.save()
        print("✦ WeeklyReviewMigrationService: migrated \(reviewEntries.count) entries")
    }

    // MARK: - Parser

    private func parse(_ text: String) -> [String: String] {
        var dict: [String: String] = [:]
        for line in text.components(separatedBy: "\n") {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[line.startIndex..<colon])
            let value = String(line[line.index(after: colon)...])
                .trimmingCharacters(in: .whitespaces)
            if !value.isEmpty { dict[key] = value }
        }
        return dict
    }
}
