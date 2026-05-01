import CoreLocation

/// Finds a logical re-entry point on the remaining route by projecting the
/// user's current heading forward and checking where their path crosses the
/// remaining route. Returns nil if no good candidate is found, in which case
/// the caller should fall back to the skip-ahead behaviour.
enum ReentryPointFinder {

    struct Candidate {
        let coordinate: CLLocationCoordinate2D
        let distanceFromUser: Double
        let polylineIndex: Int
    }

    /// Searches `remainingPolyline` (coordinates *after* the closest point to
    /// the user) for the best forward-facing re-entry point.
    ///
    /// - Parameters:
    ///   - userLocation: User's current GPS position.
    ///   - userHeading: User's current compass heading (0–360°).
    ///   - remainingPolyline: The portion of the active route polyline that
    ///     lies ahead of the user's closest polyline index.
    ///   - config: Navigation configuration for search range and corridor.
    /// - Returns: Best candidate or nil.
    static func findReentryPoint(
        userLocation: CLLocationCoordinate2D,
        userHeading: CLLocationDirection,
        remainingPolyline: [CLLocationCoordinate2D],
        config: AppConfiguration.Navigation
    ) -> Candidate? {
        guard remainingPolyline.count >= 2 else { return nil }

        var best: Candidate?
        var bestScore = Double.infinity // lower is better (closeness to 250m ideal)

        let idealDistance = (config.reentrySearchMinMeters + config.reentrySearchMaxMeters) / 2

        for i in 0..<(remainingPolyline.count - 1) {
            let segStart = remainingPolyline[i]
            let segEnd   = remainingPolyline[i + 1]

            // Use segment midpoint as candidate coordinate
            let midLat = (segStart.latitude + segEnd.latitude) / 2
            let midLon = (segStart.longitude + segEnd.longitude) / 2
            let midpoint = CLLocationCoordinate2D(latitude: midLat, longitude: midLon)

            let distance = userLocation.distance(to: midpoint)

            // Range filter
            guard distance >= config.reentrySearchMinMeters,
                  distance <= config.reentrySearchMaxMeters else { continue }

            // Heading corridor filter — is this segment ahead of us?
            let bearingToMid = userLocation.bearing(to: midpoint)
            let angleDiff = abs(angleDifference(userHeading, bearingToMid))
            guard angleDiff <= config.reentryCorridorDegrees else { continue }

            // Score by proximity to ideal distance
            let score = abs(distance - idealDistance)
            if score < bestScore {
                bestScore = score
                best = Candidate(
                    coordinate: midpoint,
                    distanceFromUser: distance,
                    polylineIndex: i
                )
            }
        }

        return best
    }

    // MARK: - Private

    private static func angleDifference(_ a: CLLocationDirection, _ b: CLLocationDirection) -> Double {
        var diff = a - b
        while diff > 180  { diff -= 360 }
        while diff < -180 { diff += 360 }
        return abs(diff)
    }
}
