import CoreLocation

enum RouteGeometry {
    static func waypoints(
        from start: CLLocationCoordinate2D,
        radiusMeters: Double,
        count: Int
    ) -> [CLLocationCoordinate2D] {
        let angleStep = 360.0 / Double(count)
        let baseAngle = Double.random(in: 0..<360)
        return (0..<count).map { i in
            let bearing = baseAngle + angleStep * Double(i)
            return start.coordinate(at: radiusMeters, bearing: bearing)
        }
    }

    static func polylineOverlapRatio(
        polylineA: [CLLocationCoordinate2D],
        polylineB: [CLLocationCoordinate2D],
        bufferMeters: Double = 20
    ) -> Double {
        guard !polylineA.isEmpty else { return 0 }
        var overlapCount = 0
        for point in polylineA {
            let minDistance = polylineB.enumerated().compactMap { (index, bPoint) -> Double? in
                guard index + 1 < polylineB.count else { return nil }
                return segmentDistance(point: point, segStart: bPoint, segEnd: polylineB[index + 1])
            }.min() ?? Double.infinity
            if minDistance <= bufferMeters {
                overlapCount += 1
            }
        }
        return Double(overlapCount) / Double(polylineA.count)
    }

    private static func segmentDistance(
        point: CLLocationCoordinate2D,
        segStart: CLLocationCoordinate2D,
        segEnd: CLLocationCoordinate2D
    ) -> Double {
        let loc = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let a = CLLocation(latitude: segStart.latitude, longitude: segStart.longitude)
        let b = CLLocation(latitude: segEnd.latitude, longitude: segEnd.longitude)

        let ab = b.distance(from: a)
        guard ab > 0 else { return loc.distance(from: a) }

        let ap = loc.distance(from: a)
        let bp = loc.distance(from: b)
        let s = (ap + bp + ab) / 2
        let area = sqrt(max(0, s * (s - ap) * (s - bp) * (s - ab)))
        return (2 * area) / ab
    }
}
