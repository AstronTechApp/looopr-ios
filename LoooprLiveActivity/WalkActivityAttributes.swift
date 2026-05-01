import ActivityKit
import Foundation

/// Defines the data model for the Looopr walking Live Activity.
/// Static attributes are set once at the start; ContentState is updated throughout the walk.
struct WalkActivityAttributes: ActivityAttributes {
    // MARK: - Static Data (set once when the activity starts)

    /// Name of the walking route (e.g. "Northwest Loop")
    let routeName: String

    /// Total route distance in meters
    let totalDistanceMeters: Double

    /// Total number of POIs on the route
    let totalPOIs: Int

    // MARK: - Dynamic Data (updated throughout the walk)

    struct ContentState: Codable, Hashable {
        /// The moment the walk started.
        /// Used with `Text(date, style: .timer)` so the elapsed time counts
        /// up automatically on the Lock Screen / Dynamic Island without
        /// needing frequent updates from the app.
        let walkStartDate: Date

        /// Distance walked so far in meters
        let distanceWalkedMeters: Double

        /// Current walking pace in m/s (distance / time). Zero if not moving.
        let currentPaceMetersPerSecond: Double

        /// Name of the next upcoming POI, if any
        let nextPOIName: String?

        /// Distance to the next upcoming POI in meters, if any
        let nextPOIDistanceMeters: Double?

        /// Walk progress as a percentage (0.0 – 1.0)
        let progressFraction: Double

        /// Arrow character for the next navigation direction (e.g. "↑", "→", "↗").
        /// Nil when no turn-by-turn data is available.
        let nextDirectionArrow: String?

        /// Human-readable next navigation instruction (e.g. "Turn right").
        let nextDirectionText: String?

        /// Distance in meters to the next navigation step.
        let nextDirectionDistanceMeters: Double?
    }
}
