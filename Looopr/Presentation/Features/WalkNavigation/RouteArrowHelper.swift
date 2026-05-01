import CoreLocation

/// A directional arrow placed along the route polyline.
///
/// `id` is a content-aware composite of `index` and `bearing`, so that when
/// the route is flipped (every arrow's bearing rotates 180°), SwiftUI's
/// `ForEach` sees each arrow as a *new* identity and re-renders the
/// rotation effect. Without this, stable integer IDs cause MapKit
/// annotations to retain stale rotations after a flip — the bug that made
/// flips appear to do nothing on screen.
///
/// `index` is exposed separately for the "marching arrows" wave-phase
/// animation, which needs a stable sequential position 0...N-1.
struct RouteArrow: Identifiable, Equatable {
    /// Sequential position along the route, 0-based. Stable across flips
    /// so the wave animation phase stays smooth.
    let index: Int
    let coordinate: CLLocationCoordinate2D
    /// Compass degrees (0 = North, 90 = East).
    let bearing: Double

    /// Content-aware identity: changes whenever the bearing changes (e.g.
    /// after a route flip), forcing SwiftUI to treat the arrow as a new
    /// view and apply the updated rotation.
    var id: String { "\(index)-\(Int(bearing.rounded()))" }
}

/// Computes evenly-spaced `RouteArrow` values along a polyline.
enum RouteArrowHelper {

    /// Distributes arrows evenly along the full route.
    /// Always covers 100 % of the route length by deriving spacing from the
    /// total distance so that exactly `targetCount` arrows are placed.
    /// - Parameters:
    ///   - coordinates: The polyline to annotate.
    ///   - direction: Which way the user is walking. When `.reverse`, each
    ///                arrow's bearing is flipped 180° so chevrons point the
    ///                way the user is travelling. The polyline coordinates
    ///                themselves are never mutated.
    ///   - targetCount: Desired number of arrows (used to derive spacing).
    ///                  More arrows = denser; fewer = sparser.
    static func arrows(
        along coordinates: [CLLocationCoordinate2D],
        direction: WalkDirection = .forward,
        targetCount: Int = 40
    ) -> [RouteArrow] {
        guard coordinates.count >= 2, targetCount > 0 else { return [] }

        // Measure total route length
        var totalLength: Double = 0
        for i in 1 ..< coordinates.count {
            totalLength += coordinates[i - 1].distance(to: coordinates[i])
        }
        guard totalLength > 0 else { return [] }

        // Derive spacing so arrows cover the entire route
        let spacing = totalLength / Double(targetCount)

        var result: [RouteArrow] = []
        var accumulated: Double = 0
        var nextAt: Double = spacing / 2   // first arrow half a spacing in

        for i in 1 ..< coordinates.count {
            let from = coordinates[i - 1]
            let to   = coordinates[i]
            let segLen = from.distance(to: to)
            guard segLen > 0 else { continue }

            while accumulated + segLen >= nextAt {
                let t = (nextAt - accumulated) / segLen
                let lat = from.latitude  + t * (to.latitude  - from.latitude)
                let lon = from.longitude + t * (to.longitude - from.longitude)
                // Forward direction: arrow points along the segment.
                // Reverse direction: arrow points the opposite way.
                let forwardBearing = from.bearing(to: to)
                let bearing: Double
                switch direction {
                case .forward:
                    bearing = forwardBearing
                case .reverse:
                    bearing = (forwardBearing + 180).truncatingRemainder(dividingBy: 360)
                }

                result.append(RouteArrow(
                    index: result.count,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    bearing: bearing
                ))

                nextAt += spacing
            }

            accumulated += segLen
        }

        return result
    }
}
