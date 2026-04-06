// MigrationCoordinator.swift
// Commonplace
//
// Centralized, versioned coordinator for all one-time data migrations.
// Replaces individual migration service calls scattered across startupTasks().
//
// How it works:
//   - Each migration is assigned a permanent version number (1, 2, 3...)
//   - UserDefaults stores the highest completed migration number
//   - On launch, only migrations above that number are run
//   - Completed migrations are permanently skipped on all future launches
//   - Adding a new migration = add one entry to the migrations list with the next number
//
// Adding a new migration:
//   1. Add a new case to the migrations array with the next version number
//   2. Call the appropriate service inside the run() closure
//   3. That's it — tracking is automatic
//
// Important distinction:
//   - Migrations (this file): run ONCE ever, then permanently skipped
//   - Backfills (SearchIndex, HealthKit): run every launch by design — do NOT add them here
//
// Current migrations:
//   1 → TagMigrationService        (v1.3)
//   2 → PersonMigrationService     (v1.7)
//   3 → SubjectMigrationService    (v1.10.1)
//   4 → JournalImageMigrationService (v1.9.1)
//   5 → WeeklyReviewMigrationService (v1.12.1)

import Foundation
import SwiftData

@MainActor
final class MigrationCoordinator {
    
    static let shared = MigrationCoordinator()
    private init() {}
    
    private let userDefaultsKey = "completedMigrationVersion"
    
    // MARK: - Migration Registry
    
    /// The ordered list of all one-time migrations.
    /// Each migration has a version number and a run closure.
    /// NEVER reorder or renumber existing migrations — only append new ones.
    private struct Migration {
        let version: Int
        let name: String
        let run: (ModelContext, [Entry]) -> Void
    }
    
    private func migrations(entries: [Entry]) -> [Migration] {
        [
            Migration(version: 1, name: "TagMigration") { context, _ in
                TagMigrationService.migrateIfNeeded(context: context)
            },
            Migration(version: 2, name: "PersonMigration") { context, _ in
                PersonMigrationService.migrateIfNeeded(context: context)
            },
            Migration(version: 3, name: "SubjectMigration") { context, _ in
                SubjectMigrationService.shared.migrateIfNeeded(context: context)
            },
            Migration(version: 4, name: "JournalImageMigration") { context, entries in
                JournalImageMigrationService.shared.migrateIfNeeded(entries: entries, context: context)
            },
            Migration(version: 5, name: "WeeklyReviewMigration") { context, _ in
                WeeklyReviewMigrationService.shared.migrateIfNeeded(context: context)
            }
            // Add future migrations here — append only, never reorder
        ]
    }
    
    // MARK: - Public
    
    /// Run all pending migrations in order.
    /// Call once from startupTasks() — safe to call on every launch.
    func runIfNeeded(context: ModelContext, entries: [Entry]) {
        let completedVersion = UserDefaults.standard.integer(forKey: userDefaultsKey)
        let pending = migrations(entries: entries).filter { $0.version > completedVersion }
        
        guard !pending.isEmpty else {
            AppLogger.info("All migrations up to date (v\(completedVersion))", domain: .migration)
            return
        }
        
        for migration in pending {
            AppLogger.info("Running migration \(migration.version): \(migration.name)", domain: .migration)
            migration.run(context, entries)
            UserDefaults.standard.set(migration.version, forKey: userDefaultsKey)
            AppLogger.info("Migration \(migration.version) complete", domain: .migration)
        }
    }
}
