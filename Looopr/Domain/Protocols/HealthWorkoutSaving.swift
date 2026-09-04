import Foundation

/// Write permission state for the system health store.
enum HealthAuthorization: Sendable, Equatable {
    /// This device has no health store (iPad, Mac, some simulators).
    case unavailable
    case notDetermined
    case denied
    case authorized
}

/// Hands completed walks to the system health store (Apple Health on iOS)
/// as walking workouts. Write-only by design: Looopr never reads health
/// data back, which also keeps the permission prompt to a single item.
protocol HealthWorkoutSaving: AnyObject, Sendable {
    /// Whether the device has a health store at all.
    var isAvailable: Bool { get }

    /// Current write-permission state for workouts.
    var authorization: HealthAuthorization { get }

    /// Shows the system permission sheet (a no-op if already decided) and
    /// returns the resulting state.
    func requestAuthorization() async throws -> HealthAuthorization

    /// Saves the walk as an outdoor walking workout carrying its distance
    /// and, when recorded, its GPS route. Saving the same walk again updates
    /// the existing workout instead of duplicating it. Returns the workout's
    /// identifier.
    func saveWalk(_ session: WalkSession) async throws -> UUID
}
