// TypeRawValueBackfillService.swift
// Commonplace
//
// One-time backfill service that populates the typeRawValue field
// on all existing entries created before v2.16.
//
// typeRawValue is a stored mirror of entry.type.rawValue that enables
// #Predicate-based type filtering without loading the full archive.
//
// New entries set typeRawValue in the Entry initializer — this service
// only needs to run once to catch all pre-v2.16 entries.

import Foundation
import SwiftData

struct TypeRawValueBackfillService {
    static func migrateIfNeeded(entries: [Entry], context: ModelContext) {
        var count = 0
        for entry in entries where entry.typeRawValue.isEmpty {
            entry.typeRawValue = entry.type.rawValue
            count += 1
        }
        if count > 0 {
            try? context.save()
            AppLogger.info("TypeRawValueBackfillService: updated \(count) entries", domain: .migration)
        }
    }
}
