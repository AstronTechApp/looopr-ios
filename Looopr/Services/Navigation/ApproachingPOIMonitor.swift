import CoreLocation
import Foundation

/// What the "Approaching" banner shows: the next attraction ahead and how
/// far along the route it is.
struct ApproachingPOIInfo: Equatable {
    let poi: POI
    let distanceMeters: Double
}

/// Decides which attraction, if any, the "Approaching" banner should show.
///
/// Everything is measured *along the route*: each POI is projected onto the
/// polyline once (`setRoute`) and compared with the user's own projection
/// on every fix, so a POI across the canal that is 60 m away as the crow
/// flies but 800 m away on foot does not light up the banner.
///
/// Rules:
/// - Show the nearest POI that is ahead in the direction of travel and
///   within `showDistanceMeters` along the route. One banner at a time.
/// - Hide it `passedHideDistanceMeters` after walking past the POI's point
///   on the route, or after `lingerHideSeconds` spent within
///   `lingerRadiusMeters` of that point (the user stopped to look).
/// - A POI that was hidden either way, or dismissed by hand, stays hidden
///   for the rest of the walk, across reroutes.
@MainActor
final class ApproachingPOIMonitor {

    // MARK: - Tuning

    /// Show the banner once the POI is this close along the route (metres).
    var showDistanceMeters: Double = 100
    /// Hide the banner this far past the POI's point on the route (metres).
    var passedHideDistanceMeters: Double = 20
    /// … or after this long within `lingerRadiusMeters` of it (seconds).
    var lingerHideSeconds: TimeInterval = 10
    var lingerRadiusMeters: Double = 15

    // MARK: - State

    private(set) var current: ApproachingPOIInfo?

    private struct Candidate {
        let poi: POI
        let alongRouteMeters: Double
    }

    private var candidates: [Candidate] = []
    /// POIs shown and then hidden (passed, lingered, dismissed) this walk.
    private var retiredIds: Set<UUID> = []
    /// When the user first came within `lingerRadiusMeters` of the current POI.
    private var lingerStartedAt: TimeInterval?

    // MARK: - Input

    /// Projects `pois` onto `polyline`. Call on start and after every
    /// reroute; retired POIs stay retired.
    func setRoute(_ polyline: [CLLocationCoordinate2D], pois: [POI]) {
        candidates = pois.compactMap { poi in
            SmoothedLocationTracker.project(poi.location.clCoordinate, onto: polyline).map {
                Candidate(poi: poi, alongRouteMeters: $0.distanceAlongRouteMeters)
            }
        }
        // A route change invalidates the current POI's along-route position.
        // If it is still ahead it comes straight back on the next update.
        current = nil
        lingerStartedAt = nil
    }

    /// Updates the banner for the user's position.
    ///
    /// - Parameters:
    ///   - userAlongRouteMeters: Arc length from the polyline start to the
    ///     user's projection on it. `nil` (off route) hides the banner
    ///     without retiring anything.
    ///   - isReversed: `true` when walking the polyline from end to start.
    ///   - now: Monotonic clock in seconds, for the linger timer.
    @discardableResult
    func update(userAlongRouteMeters: Double?, isReversed: Bool,
                now: TimeInterval = Date().timeIntervalSinceReferenceDate) -> ApproachingPOIInfo? {
        guard let user = userAlongRouteMeters else {
            current = nil
            lingerStartedAt = nil
            return nil
        }
        let direction: Double = isReversed ? -1 : 1
        // Signed distance from the user to a POI along the direction of
        // travel: positive = ahead, negative = behind.
        func ahead(_ candidate: Candidate) -> Double {
            (candidate.alongRouteMeters - user) * direction
        }

        if let shown = current,
           let candidate = candidates.first(where: { $0.poi.id == shown.poi.id }) {
            let remaining = ahead(candidate)
            if remaining < -passedHideDistanceMeters {
                retire(shown.poi.id)
            } else if abs(remaining) <= lingerRadiusMeters {
                let since = lingerStartedAt ?? now
                lingerStartedAt = since
                if now - since >= lingerHideSeconds {
                    retire(shown.poi.id)
                } else {
                    current = ApproachingPOIInfo(poi: shown.poi, distanceMeters: max(remaining, 0))
                }
            } else {
                lingerStartedAt = nil
                current = ApproachingPOIInfo(poi: shown.poi, distanceMeters: max(remaining, 0))
            }
        } else if current != nil {
            // Shown POI no longer on the route (shouldn't happen after
            // setRoute cleared it, but be safe).
            current = nil
            lingerStartedAt = nil
        }

        // Nearest eligible POI ahead. It replaces the current one only when
        // it is closer; a POI already being passed (negative distance) keeps
        // the banner until the hide rules above retire it.
        let next = candidates
            .filter { !retiredIds.contains($0.poi.id) }
            .map { ($0, ahead($0)) }
            .filter { $0.1 >= 0 && $0.1 <= showDistanceMeters }
            .min { $0.1 < $1.1 }
        if let (candidate, remaining) = next, candidate.poi.id != current?.poi.id {
            let currentRemaining = current.flatMap { shown in
                candidates.first { $0.poi.id == shown.poi.id }.map(ahead)
            }
            if currentRemaining == nil || remaining < currentRemaining! {
                current = ApproachingPOIInfo(poi: candidate.poi, distanceMeters: remaining)
                lingerStartedAt = remaining <= lingerRadiusMeters ? now : nil
            }
        }
        return current
    }

    /// Hides the current banner for the rest of the walk.
    func dismiss() {
        guard let shown = current else { return }
        retire(shown.poi.id)
    }

    private func retire(_ id: UUID) {
        retiredIds.insert(id)
        current = nil
        lingerStartedAt = nil
    }
}
