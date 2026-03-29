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
        
        // Process sequentially to avoid overwhelming HealthKit
        for entry in toBackfill {
            await backfill(entry: entry)
            try? context.save()
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
