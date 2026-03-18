import Foundation
import HealthKit
import Combine

// MARK: - HealthKitService
// Fetches yesterday's activity data from HealthKit.
// Requests permission on first use, then fetches silently on each call.
// Used by JournalBlockView to display activity rings and workout summary.

class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    private let store = HKHealthStore()

    @Published var isAuthorized = false
    @Published var activeCalories: Double = 0
    @Published var exerciseMinutes: Double = 0
    @Published var standHours: Double = 0
    @Published var workouts: [WorkoutSummary] = []

    // Default goals
    let calorieGoal: Double = 500
    let exerciseGoal: Double = 30
    let standGoal: Double = 12

    var moveProgress: Double { min(activeCalories / calorieGoal, 1.0) }
    var exerciseProgress: Double { min(exerciseMinutes / exerciseGoal, 1.0) }
    var standProgress: Double { min(standHours / standGoal, 1.0) }

    struct WorkoutSummary: Identifiable {
        let id = UUID()
        let name: String
        let duration: Int
        let calories: Double
    }

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let types: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.categoryType(forIdentifier: .appleStandHour)!,
            HKObjectType.workoutType()
        ]
        do {
            try await store.requestAuthorization(toShare: [], read: types)
            await MainActor.run { isAuthorized = true }
            await fetchYesterday()
        } catch {
            print("HealthKit authorization failed: \(error)")
        }
    }

    // MARK: - Fetch

    func fetchYesterday() async {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let start = calendar.startOfDay(for: yesterday)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        async let calories = fetchQuantity(.activeEnergyBurned, predicate: predicate, unit: .kilocalorie())
        async let exercise = fetchQuantity(.appleExerciseTime, predicate: predicate, unit: .minute())
        async let stand = fetchStandHours(start: start, end: end)
        async let workoutList = fetchWorkouts(start: start, end: end)

        let (cal, ex, st, wo) = await (calories, exercise, stand, workoutList)

        await MainActor.run {
            activeCalories = cal
            exerciseMinutes = ex
            standHours = st
            workouts = wo
        }
    }

    // MARK: - Private helpers

    private func fetchQuantity(_ identifier: HKQuantityTypeIdentifier, predicate: NSPredicate, unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }

    private func fetchStandHours(start: Date, end: Date) async -> Double {
        guard let type = HKCategoryType.categoryType(forIdentifier: .appleStandHour) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let stood = samples?.filter {
                    ($0 as? HKCategorySample)?.value == HKCategoryValueAppleStandHour.stood.rawValue
                }.count ?? 0
                continuation.resume(returning: Double(stood))
            }
            store.execute(query)
        }
    }

    private func fetchWorkouts(start: Date, end: Date) async -> [WorkoutSummary] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let summaries = (samples as? [HKWorkout])?.map { workout in
                    WorkoutSummary(
                        name: workout.workoutActivityType.name,
                        duration: Int(workout.duration / 60),
                        calories: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                    )
                } ?? []
                continuation.resume(returning: summaries)
            }
            self.store.execute(query)
        }
    }
}

// MARK: - Workout name helper

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running:          return "Running"
        case .cycling:          return "Cycling"
        case .walking:          return "Walking"
        case .swimming:         return "Swimming"
        case .yoga:             return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .hiking:           return "Hiking"
        case .dance:            return "Dance"
        case .pilates:          return "Pilates"
        case .rowing:           return "Rowing"
        case .elliptical:       return "Elliptical"
        case .stairClimbing:    return "Stair Climbing"
        case .crossTraining:    return "Cross Training"
        default:                return "Workout"
        }
    }
}
