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

    /// Generate a descriptive route name based on compass direction and distance
    static func routeName(bearing: Double, distanceKm: Double) -> String {
        let direction = compassDirection(for: bearing)
        let distanceStr = String(format: "%.1f", distanceKm)
        return "\(direction) Loop (\(distanceStr) km)"
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
