import CoreLocation
import MapKit

enum RouteGeometry {

    /// Generate evenly-distributed bearings with a random starting angle
    static func distributedBearings(count: Int) -> [Double] {
        let step = 360.0 / Double(count)
        let base = Double.random(in: 0..<360)
        return (0..<count).map { i in
            (base + step * Double(i)).truncatingRemainder(dividingBy: 360)
        }
    }

    /// Generate waypoints around a center at given radius
    static func waypoints(
        from start: CLLocationCoordinate2D,
        radiusMeters: Double,
        count: Int
    ) -> [CLLocationCoordinate2D] {
        distributedBearings(count: count).map { bearing in
            start.coordinate(at: radiusMeters, bearing: bearing)
        }
    }

    /// Measure how much of polylineA overlaps with polylineB within a buffer distance
    static func polylineOverlapRatio(
        polylineA: [CLLocationCoordinate2D],
        polylineB: [CLLocationCoordinate2D],
        bufferMeters: Double = 20
    ) -> Double {
        guard !polylineA.isEmpty, polylineB.count >= 2 else { return 0 }
        var overlapCount = 0
        for point in polylineA {
            let minDist = minimumDistance(from: point, toPolyline: polylineB)
            if minDist <= bufferMeters {
                overlapCount += 1
            }
        }
        return Double(overlapCount) / Double(polylineA.count)
    }

    /// Minimum distance from a point to a polyline (checking each segment)
    static func minimumDistance(
        from point: CLLocationCoordinate2D,
        toPolyline polyline: [CLLocationCoordinate2D]
    ) -> Double {
        guard polyline.count >= 2 else {
            if let first = polyline.first {
                return point.distance(to: first)
            }
            return .infinity
        }
        var minDist = Double.infinity
        for i in 0..<(polyline.count - 1) {
            let dist = segmentDistance(point: point, segStart: polyline[i], segEnd: polyline[i + 1])
            minDist = min(minDist, dist)
        }
        return minDist
    }

    /// Generate a descriptive base route name from compass direction.
    /// Distance is NOT included — it is appended dynamically at display time
    /// via `Route.displayName` so it respects the user's km/mi preference.
    static func routeName(bearing: Double, distanceKm: Double) -> String {
        let direction = compassDirection(for: bearing)
        return "\(direction) Loop"
    }

    static func compassDirection(for bearing: Double) -> String {
        let normalized = bearing.truncatingRemainder(dividingBy: 360)
        switch normalized {
        case 337.5..<360, 0..<22.5:       return "North"
        case 22.5..<67.5:                  return "Northeast"
        case 67.5..<112.5:                 return "East"
        case 112.5..<157.5:                return "Southeast"
        case 157.5..<202.5:                return "South"
        case 202.5..<247.5:                return "Southwest"
        case 247.5..<292.5:                return "West"
        case 292.5..<337.5:                return "Northwest"
        default:                           return "North"
        }
    }

    /// Detect back-and-forth segments within a single polyline.
    /// Splits the polyline into two halves and measures how much the first half
    /// overlaps with the second half. A high ratio indicates the route doubles
    /// back on itself (e.g. going down a dead-end and returning the same way).
    static func selfOverlapRatio(
        polyline: [CLLocationCoordinate2D],
        bufferMeters: Double = 25
    ) -> Double {
        guard polyline.count >= 6 else { return 0 }
        let mid = polyline.count / 2
        let firstHalf = Array(polyline[0..<mid]).sampled(every: 3)
        let secondHalf = Array(polyline[mid...])
        return polylineOverlapRatio(polylineA: firstHalf, polylineB: secondHalf, bufferMeters: bufferMeters)
    }

    /// Detect back-and-forth within individual legs of a multi-leg route.
    /// Returns the maximum self-overlap ratio across all legs.
    /// Each leg's polyline is split and checked for segments that retrace themselves.
    static func maxLegSelfOverlap(
        legs: [[CLLocationCoordinate2D]],
        bufferMeters: Double = 25
    ) -> Double {
        legs.map { selfOverlapRatio(polyline: $0, bufferMeters: bufferMeters) }.max() ?? 0
    }

    /// Detect back-and-forth by sliding a window along the polyline and checking
    /// if any segment reverses direction to overlap with a previous segment.
    /// More granular than selfOverlapRatio — catches short out-and-back spurs
    /// even if the overall first-half/second-half overlap is low.
    static func backtrackSegmentRatio(
        polyline: [CLLocationCoordinate2D],
        windowSize: Int = 20,
        bufferMeters: Double = 20
    ) -> Double {
        guard polyline.count >= windowSize * 3 else { return 0 }
        let sampled = polyline.sampled(every: 2)
        guard sampled.count >= windowSize * 3 else { return 0 }

        var backtrackCount = 0
        let totalWindows = max(1, sampled.count - windowSize * 2)

        for i in stride(from: 0, to: sampled.count - windowSize * 2, by: windowSize) {
            let windowA = Array(sampled[i..<(i + windowSize)])
            let windowB = Array(sampled[(i + windowSize)..<min(i + windowSize * 2, sampled.count)])
            let overlap = polylineOverlapRatio(polylineA: windowA, polylineB: windowB, bufferMeters: bufferMeters)
            if overlap > 0.6 {
                backtrackCount += 1
            }
        }
        return Double(backtrackCount) / Double(totalWindows)
    }

    /// Distance along the polyline from the start to the closest point to a given coordinate.
    /// Walks segment-by-segment, accumulating distance, and returns the cumulative
    /// distance at the projection point on the nearest segment.
    static func distanceAlongRoute(
        to point: CLLocationCoordinate2D,
        polyline: [CLLocationCoordinate2D]
    ) -> Double {
        guard polyline.count >= 2 else { return 0 }

        // First, find which segment is closest to the point
        var minDist = Double.infinity
        var nearestSegmentIndex = 0
        for i in 0..<(polyline.count - 1) {
            let dist = segmentDistance(point: point, segStart: polyline[i], segEnd: polyline[i + 1])
            if dist < minDist {
                minDist = dist
                nearestSegmentIndex = i
            }
        }

        // Accumulate distance along the polyline up to the nearest segment
        var accumulated = 0.0
        for i in 0..<nearestSegmentIndex {
            let a = CLLocation(latitude: polyline[i].latitude, longitude: polyline[i].longitude)
            let b = CLLocation(latitude: polyline[i + 1].latitude, longitude: polyline[i + 1].longitude)
            accumulated += b.distance(from: a)
        }

        // Add the partial distance along the nearest segment to the projection point
        let segStart = polyline[nearestSegmentIndex]
        let segEnd = polyline[nearestSegmentIndex + 1]
        accumulated += projectionDistanceAlongSegment(
            point: point, segStart: segStart, segEnd: segEnd
        )

        return accumulated
    }

    /// Distance from segStart to the projection of `point` onto the segment [segStart, segEnd].
    /// If the projection falls before the segment, returns 0.
    /// If it falls after, returns the full segment length.
    private static func projectionDistanceAlongSegment(
        point: CLLocationCoordinate2D,
        segStart: CLLocationCoordinate2D,
        segEnd: CLLocationCoordinate2D
    ) -> Double {
        let p = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let a = CLLocation(latitude: segStart.latitude, longitude: segStart.longitude)
        let b = CLLocation(latitude: segEnd.latitude, longitude: segEnd.longitude)

        let ab = b.distance(from: a)
        guard ab > 0 else { return 0 }

        let ap = p.distance(from: a)
        let bp = p.distance(from: b)

        // Use the cosine rule to find the projection distance along the segment
        // cos(angle_A) = (ap² + ab² - bp²) / (2 * ap * ab)
        // projection = ap * cos(angle_A)
        let projection = (ap * ap + ab * ab - bp * bp) / (2 * ab)

        // Clamp to segment bounds
        return min(max(projection, 0), ab)
    }

    // MARK: - Straight-Line (Impossible Segment) Detection

    /// Detect suspiciously straight segments in a route polyline that likely indicate
    /// an impossible water crossing or routing failure. Real walking routes through
    /// city streets always have tortuosity from turns, intersections, and curves.
    /// An impossibly straight segment (e.g. 1.5km+ at >98.5% straightness) strongly
    /// suggests the routing engine drew a straight line over water.
    ///
    /// Thresholds are intentionally high to avoid false positives on grid-layout cities
    /// (NYC avenues, Amsterdam canal paths) where 400-800m straight stretches are normal.
    ///
    /// Returns `true` if any segment longer than `minSegmentMeters` has a straightness
    /// ratio (crow-flies / routed distance) above `straightnessThreshold`.
    static func containsStraightLineSegment(
        polyline: [CLLocationCoordinate2D],
        minSegmentMeters: Double = 1200,
        straightnessThreshold: Double = 0.985,
        windowSize: Int = 50
    ) -> Bool {
        guard polyline.count >= windowSize * 2 else { return false }

        // Slide a window along the polyline and compare routed vs. crow-flies distance
        for i in stride(from: 0, to: polyline.count - windowSize, by: windowSize / 2) {
            let endIdx = min(i + windowSize, polyline.count - 1)
            let segmentStart = polyline[i]
            let segmentEnd = polyline[endIdx]

            // Crow-flies distance
            let crowFlies = segmentStart.distance(to: segmentEnd)
            guard crowFlies >= minSegmentMeters else { continue }

            // Routed distance (sum of consecutive point distances)
            var routedDistance = 0.0
            for j in i..<endIdx {
                routedDistance += polyline[j].distance(to: polyline[j + 1])
            }

            guard routedDistance > 0 else { continue }

            let straightnessRatio = crowFlies / routedDistance
            if straightnessRatio >= straightnessThreshold {
                return true
            }
        }
        return false
    }

    // MARK: - Private

    private static func segmentDistance(
        point: CLLocationCoordinate2D,
        segStart: CLLocationCoordinate2D,
        segEnd: CLLocationCoordinate2D
    ) -> Double {
        let p = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let a = CLLocation(latitude: segStart.latitude, longitude: segStart.longitude)
        let b = CLLocation(latitude: segEnd.latitude, longitude: segEnd.longitude)

        let ab = b.distance(from: a)
        guard ab > 0 else { return p.distance(from: a) }

        let ap = p.distance(from: a)
        let bp = p.distance(from: b)

        // Use Heron's formula for triangle area, then height = 2*area/base
        let s = (ap + bp + ab) / 2
        let areaSquared = s * (s - ap) * (s - bp) * (s - ab)
        let area = sqrt(max(0, areaSquared))
        let height = (2 * area) / ab

        // Check if projection falls within segment
        let dotAP = ap * ap
        let dotBP = bp * bp
        let dotAB = ab * ab

        if dotAP > dotAB + dotBP { return bp }
        if dotBP > dotAB + dotAP { return ap }
        return height
    }
}

// MARK: - MKPolyline Extension

extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

// MARK: - Array Sampling

extension Array {
    func sampled(every n: Int) -> [Element] {
        guard n > 1 else { return self }
        return stride(from: 0, to: count, by: n).map { self[$0] }
    }
}
