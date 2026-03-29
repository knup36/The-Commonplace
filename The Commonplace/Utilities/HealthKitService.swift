// HealthKitService.swift
// Commonplace
//
// Handles all HealthKit interaction for Commonplace.
// Responsibilities:
//   - Requesting authorization for activity and workout data
//   - Fetching activity summary (active calories, exercise minutes, stand hours) for a given date
//   - Fetching the primary workout for a given date
//
// All fetch methods are async and run off the main thread.
// Called by HealthKitBackfillService at launch to populate journal entries.
// Never called from the UI layer directly.

import Foundation
import HealthKit

class HealthKitService {
    
    static let shared = HealthKitService()
    private let store = HKHealthStore()
    
    // MARK: - Data Types
    
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
        HKObjectType.quantityType(forIdentifier: .appleStandTime)!,
        HKObjectType.workoutType()
    ]
    
    // MARK: - Authorization
    
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            print("HealthKit authorization error: \(error)")
            return false
        }
    }
    
    // MARK: - Activity Summary
    
    struct ActivitySummary {
        let activeCalories: Double
        let exerciseMinutes: Double
        let standHours: Double
    }
    
    func fetchActivitySummary(for date: Date) async -> ActivitySummary? {
        guard isAvailable else { return nil }
        
        async let calories = fetchSum(
            typeIdentifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            for: date
        )
        async let exercise = fetchSum(
            typeIdentifier: .appleExerciseTime,
            unit: .minute(),
            for: date
        )
        async let stand = fetchSum(
            typeIdentifier: .appleStandTime,
            unit: .hour(),
            for: date
        )
        
        let (cal, ex, st) = await (calories, exercise, stand)
        
        // Return nil if all values are zero — no data for this day
        guard cal > 0 || ex > 0 || st > 0 else { return nil }
        
        return ActivitySummary(
            activeCalories: cal,
            exerciseMinutes: ex,
            standHours: st
        )
    }
    
    // MARK: - Workout
    
    struct WorkoutSummary {
        let name: String
        let durationMinutes: Double
        let activeCalories: Double
    }
    
    func fetchPrimaryWorkout(for date: Date) async -> WorkoutSummary? {
        guard isAvailable else { return nil }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let workout = samples?.first as? HKWorkout, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let name = workout.workoutActivityType.name
                let duration = workout.duration / 60
                let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                    .sumQuantity()?
                    .doubleValue(for: .kilocalorie()) ?? 0
                
                continuation.resume(returning: WorkoutSummary(
                    name: name,
                    durationMinutes: duration,
                    activeCalories: calories
                ))
            }
            store.execute(query)
        }
    }
    
    // MARK: - Private Helpers
    
    private func fetchSum(
        typeIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        for date: Date
    ) async -> Double {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else {
            return 0
        }
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}

// MARK: - Workout Activity Type Name

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .swimming: return "Swimming"
        case .hiking: return "Hiking"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .rowing: return "Rowing"
        case .elliptical: return "Elliptical"
        case .stairClimbing: return "Stair Climbing"
        case .pilates: return "Pilates"
        case .crossTraining: return "Cross Training"
        case .play: return "Play"
        case .soccer: return "Soccer"
        case .basketball: return "Basketball"
        case .tennis: return "Tennis"
        case .golf: return "Golf"
        case .dance: return "Dance"
        default: return "Workout"
        }
    }
}
