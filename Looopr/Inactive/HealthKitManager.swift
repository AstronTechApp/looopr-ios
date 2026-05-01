import Foundation
import HealthKit
import CoreLocation

/// Singleton managing all Apple HealthKit interactions.
/// Always guard calls with `isAvailable` — HealthKit is not present on iPad or some simulators.
final class HealthKitManager {
    static let shared = HealthKitManager()
    private init() {}

    private let store = HKHealthStore()

    // MARK: - Types

    private var writeTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        return types
    }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        return types
    }

    // MARK: - Availability

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorisation

    func requestAuthorisation() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            return true
        } catch {
            print("HealthKit auth error: \(error.localizedDescription)")
            return false
        }
    }

    func workoutAuthorisationStatus() -> HKAuthorizationStatus {
        guard isAvailable else { return .notDetermined }
        return store.authorizationStatus(for: HKObjectType.workoutType())
    }

    // MARK: - Write Walk Workout

    /// Saves a completed walk as an HKWorkout with distance, calories, and optional route.
    func saveWalk(
        session: WalkSession,
        routeLocations: [CLLocation]
    ) async -> Bool {
        guard isAvailable else { return false }

        let startDate = session.startedAt
        let endDate = session.finishedAt ?? startDate.addingTimeInterval(session.durationSeconds)

        // Estimate calories: MET ~3.8 for walking, assume 70kg
        let met = 3.8
        let weightKg = 70.0
        let hours = session.durationSeconds / 3600
        let kcal = met * weightKg * hours

        let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
        let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: session.distanceWalkedMeters)

        let workout = HKWorkout(
            activityType: .walking,
            start: startDate,
            end: endDate,
            duration: session.durationSeconds,
            totalEnergyBurned: energyQuantity,
            totalDistance: distanceQuantity,
            metadata: [
                HKMetadataKeyWorkoutBrandName: "Looopr",
                "routeName": session.routeName ?? "Walk"
            ]
        )

        do {
            try await store.save(workout)

            // Save route locations if available
            if !routeLocations.isEmpty {
                await saveRoute(locations: routeLocations, workout: workout)
            }
            return true
        } catch {
            print("HealthKit save error: \(error.localizedDescription)")
            return false
        }
    }

    private func saveRoute(locations: [CLLocation], workout: HKWorkout) async {
        let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: nil)
        do {
            try await routeBuilder.insertRouteData(locations)
            try await routeBuilder.finishRoute(with: workout, metadata: nil)
        } catch {
            print("HealthKit route save error: \(error.localizedDescription)")
        }
    }

    // MARK: - Read: Steps This Week

    func stepsThisWeek() async -> Int {
        guard isAvailable,
              let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return 0
        }

        let startOfWeek = Calendar.current.dateComponents(
            [.calendar, .yearForWeekOfYear, .weekOfYear],
            from: Date()
        ).date ?? Date()

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfWeek,
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            store.execute(query)
        }
    }

    // MARK: - Read: Walking Distance This Week (metres)

    func walkingDistanceThisWeek() async -> Double {
        guard isAvailable,
              let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            return 0
        }

        let startOfWeek = Calendar.current.dateComponents(
            [.calendar, .yearForWeekOfYear, .weekOfYear],
            from: Date()
        ).date ?? Date()

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfWeek,
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: distanceType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let metres = result?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                continuation.resume(returning: metres)
            }
            store.execute(query)
        }
    }
}
