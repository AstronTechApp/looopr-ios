import CoreLocation
import Foundation
import HealthKit

/// Apple Health implementation of `HealthWorkoutSaving`.
///
/// Each walk becomes one `HKWorkout` (activity type walking, outdoor) with a
/// distance sample spanning the walk and an `HKWorkoutRoute` built from the
/// recorded `TrackPoint`s — the same track the GPX export uses. The Fitness
/// app then shows the walk with its map and counts it towards the rings.
///
/// Steps and calories are deliberately *not* written: the iPhone already
/// counts steps itself (writing ours would double-count), and Looopr has no
/// calorie model worth putting in someone's health record.
final class LiveHealthWorkoutService: HealthWorkoutSaving, @unchecked Sendable {

    enum SaveError: LocalizedError {
        case unavailable
        case notAuthorized
        case nothingToSave
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .unavailable: return L10n.Health.unavailable
            case .notAuthorized: return L10n.Health.notAuthorized
            case .nothingToSave: return L10n.Health.nothingToSave
            case .saveFailed: return L10n.Health.saveFailed
            }
        }
    }

    private let store = HKHealthStore()
    private let logger = AppLogger(category: "Health")

    private static let workoutType = HKObjectType.workoutType()
    private static let routeType = HKSeriesType.workoutRoute()
    private static let distanceType = HKQuantityType(.distanceWalkingRunning)

    /// Everything we write. Requested together so the user sees one sheet.
    private static let typesToShare: Set<HKSampleType> = [workoutType, routeType, distanceType]

    // MARK: - HealthWorkoutSaving

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    var authorization: HealthAuthorization {
        guard isAvailable else { return .unavailable }
        switch store.authorizationStatus(for: Self.workoutType) {
        case .sharingAuthorized: return .authorized
        case .sharingDenied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    func requestAuthorization() async throws -> HealthAuthorization {
        guard isAvailable else { return .unavailable }
        try await store.requestAuthorization(toShare: Self.typesToShare, read: [])
        let result = authorization
        logger.info("Health authorization: \(String(describing: result))")
        return result
    }

    func saveWalk(_ session: WalkSession) async throws -> UUID {
        guard isAvailable else { throw SaveError.unavailable }
        guard authorization == .authorized else { throw SaveError.notAuthorized }
        guard session.distanceWalkedMeters > 0 || session.hasTrack else { throw SaveError.nothingToSave }

        let start = session.startedAt
        let end = session.finishedAt ?? start.addingTimeInterval(max(session.durationSeconds, 1))

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: start)

        if session.distanceWalkedMeters > 0 {
            let distance = HKQuantitySample(
                type: Self.distanceType,
                quantity: HKQuantity(unit: .meter(), doubleValue: session.distanceWalkedMeters),
                start: start,
                end: end
            )
            try await builder.addSamples([distance])
        }

        // The sync identifier is what makes this idempotent: HealthKit treats
        // a later save with the same identifier as an update of the existing
        // workout, so retrying (or saving from the walk detail screen after
        // an automatic save) never produces a duplicate.
        var metadata: [String: Any] = [
            HKMetadataKeySyncIdentifier: "nl.astrontech.looopr.walk.\(session.id.uuidString)",
            HKMetadataKeySyncVersion: 1,
            HKMetadataKeyIndoorWorkout: false,
        ]
        if let name = session.routeName, !name.isEmpty {
            metadata[HKMetadataKeyWorkoutBrandName] = "Looopr · \(name)"
        }
        try await builder.addMetadata(metadata)

        try await builder.endCollection(at: end)
        guard let workout = try await builder.finishWorkout() else { throw SaveError.saveFailed }

        let locations = Self.locations(for: session)
        if locations.count >= 2 {
            let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
            try await routeBuilder.insertRouteData(locations)
            _ = try await routeBuilder.finishRoute(with: workout, metadata: nil)
        }

        logger.info("Saved walk \(session.id) to Health as workout \(workout.uuid) (\(locations.count) route points)")
        return workout.uuid
    }

    // MARK: - Private

    /// Rebuilds `CLLocation`s from the stored track. HealthKit wants a
    /// non-negative horizontal accuracy on every point; a negative vertical
    /// accuracy is the documented way to say "no altitude for this fix".
    private static func locations(for session: WalkSession) -> [CLLocation] {
        (session.trackPoints ?? []).map { point in
            CLLocation(
                coordinate: point.clCoordinate,
                altitude: point.altitude ?? 0,
                horizontalAccuracy: point.horizontalAccuracy ?? 20,
                verticalAccuracy: point.altitude == nil ? -1 : 10,
                timestamp: point.timestamp
            )
        }
    }
}
