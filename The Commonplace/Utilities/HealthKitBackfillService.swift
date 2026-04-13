// HealthKitBackfillService.swift
// Commonplace
//
// Backfills HealthKit data onto past journal entries at app launch.
// Runs as part of the startup sequence in The_CommonplaceApp.swift.
//
// Responsibilities:
//   - Requests HealthKit authorization on first run
//   - Finds all journal entries older than today where healthDataFetched == false
//   - Fetches activity summary and primary workout for each entry's date
//   - Writes results to the entry and sets healthDataFetched = true
//   - Processes entries sequentially to avoid overwhelming HealthKit
//
// Safe to call repeatedly — healthDataFetched flag prevents redundant fetches.
// Skips today's entries — health data is incomplete until end of day.

import Foundation
import SwiftData
import HealthKit

class HealthKitBackfillService {
    
    static let shared = HealthKitBackfillService()
    
    func backfillIfNeeded(entries: [Entry], context: ModelContext) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        // Request authorization — no-op if already granted
        let authorized = await HealthKitService.shared.requestAuthorization()
        guard authorized else { return }
        
        // Find journal entries older than today that haven't been fetched yet
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        
        let toBackfill = entries.filter {
            $0.type == .journal &&
            !$0.healthDataFetched &&
            $0.createdAt < startOfToday
        }
        
        guard !toBackfill.isEmpty else { return }
                
                print("HealthKitBackfillService: backfilling \(toBackfill.count) journal entries")
                
                // Process in batches of 5 to avoid overwhelming HealthKit
                // Save once per batch rather than per entry
                let batchSize = 5
                for batch in stride(from: 0, to: toBackfill.count, by: batchSize) {
                    let end = min(batch + batchSize, toBackfill.count)
                    let batchEntries = Array(toBackfill[batch..<end])
                    
                    await withTaskGroup(of: Void.self) { group in
                        for entry in batchEntries {
                            group.addTask { await self.backfill(entry: entry) }
                        }
                    }
                    try? context.save()
                    
                    // Small yield between batches to keep app responsive
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                }
                
                print("HealthKitBackfillService: backfill complete")
    }
    
    // MARK: - Private
    
    private func backfill(entry: Entry) async {
        let date = entry.createdAt
        
        // Fetch activity summary and workout concurrently
        async let activitySummary = HealthKitService.shared.fetchActivitySummary(for: date)
        async let workout = HealthKitService.shared.fetchPrimaryWorkout(for: date)
        
        let (summary, workoutResult) = await (activitySummary, workout)
        
        // Write to entry on main actor to keep SwiftData happy
        await MainActor.run {
            if let summary {
                print("Stand hours fetched: \(summary.standHours)")
                print("Active calories fetched: \(summary.activeCalories)")
                print("Exercise minutes fetched: \(summary.exerciseMinutes)")
                entry.healthActiveCalories = summary.activeCalories
                entry.healthExerciseMinutes = summary.exerciseMinutes
                entry.healthStandHours = summary.standHours
            }
            if let workout = workoutResult {
                entry.healthWorkoutName = workout.name
                entry.healthWorkoutDuration = Int(workout.durationMinutes)
                entry.healthWorkoutCalories = workout.activeCalories
            }
            entry.healthDataFetched = true
        }
    }
}
