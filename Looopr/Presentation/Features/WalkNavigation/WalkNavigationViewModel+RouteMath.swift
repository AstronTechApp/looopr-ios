import CoreLocation
import Foundation

// Pure route geometry used by WalkNavigationViewModel: polyline distances,
// projections and step matching. No view-model state is read or written
// here; moved out of WalkNavigationViewModel.swift (1.5) unchanged apart
// from `private` → internal so the main file can still call them.

extension WalkNavigationViewModel {
    static func nextPolylineVertexIndex(
        after point: CLLocationCoordinate2D,
        in polyline: [CLLocationCoordinate2D]
    ) -> Int {
        guard polyline.count >= 2 else { return 0 }

        var bestDistance = Double.infinity
        var bestNextIndex = 1

        for index in 0..<(polyline.count - 1) {
            let distance = distanceFrom(point, toSegmentStart: polyline[index], end: polyline[index + 1])
            if distance < bestDistance {
                bestDistance = distance
                bestNextIndex = index + 1
            }
        }

        return bestNextIndex
    }

    static func removingConsecutiveNearDuplicates(
        _ coordinates: [CLLocationCoordinate2D],
        thresholdMeters: Double = 5
    ) -> [CLLocationCoordinate2D] {
        var result: [CLLocationCoordinate2D] = []
        for coordinate in coordinates {
            guard let last = result.last else {
                result.append(coordinate)
                continue
            }
            if last.distance(to: coordinate) >= thresholdMeters {
                result.append(coordinate)
            }
        }
        return result
    }

    static func distanceFrom(
        _ point: CLLocationCoordinate2D,
        toSegmentStart start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D
    ) -> Double {
        let origin = start
        let metersPerDegreeLatitude = 111_320.0
        let metersPerDegreeLongitude = metersPerDegreeLatitude * cos(origin.latitude * .pi / 180)

        func xy(_ coordinate: CLLocationCoordinate2D) -> (x: Double, y: Double) {
            (
                x: (coordinate.longitude - origin.longitude) * metersPerDegreeLongitude,
                y: (coordinate.latitude - origin.latitude) * metersPerDegreeLatitude
            )
        }

        let p = xy(point)
        let a = xy(start)
        let b = xy(end)
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return hypot(p.x - a.x, p.y - a.y)
        }

        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        let projectedX = a.x + t * dx
        let projectedY = a.y + t * dy
        return hypot(p.x - projectedX, p.y - projectedY)
    }

    func closestPolylineIndex(to point: CLLocationCoordinate2D, in polyline: [CLLocationCoordinate2D]) -> Int {
        var minDist = Double.infinity
        var minIdx = 0
        for (i, coord) in polyline.enumerated() {
            let dist = point.distance(to: coord)
            if dist < minDist { minDist = dist; minIdx = i }
        }
        return minIdx
    }

    /// Total length of an arbitrary polyline, in meters.
    /// Static so we can call it from `init` before `self` is fully formed.
    static func polylineLength(_ polyline: [CLLocationCoordinate2D]) -> Double {
        guard polyline.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 1 ..< polyline.count {
            total += polyline[i - 1].distance(to: polyline[i])
        }
        return total
    }

    static func routeDistancesForSteps(
        _ steps: [NavigationStep],
        along polyline: [CLLocationCoordinate2D]
    ) -> [Double?] {
        guard polyline.count >= 2 else { return Array(repeating: nil, count: steps.count) }

        let cumulativeDistances = cumulativeDistances(for: polyline)
        var minimumDistanceFromStart: Double = 0
        let orderToleranceMeters: Double = 25

        return steps.map { step in
            let match = nearestRouteProgress(
                to: step.coordinate,
                in: polyline,
                cumulativeDistances: cumulativeDistances,
                minimumDistanceFromStart: max(0, minimumDistanceFromStart - orderToleranceMeters)
            )
            guard let distanceFromStart = match?.distanceFromStartMeters else { return nil }
            minimumDistanceFromStart = max(minimumDistanceFromStart, distanceFromStart)
            return distanceFromStart
        }
    }

    static func hasPassedStepByRouteProgress(
        progressDistanceFromStart: Double,
        stepDistanceFromStart: Double,
        totalDistance: Double,
        walkDirection: WalkDirection,
        toleranceMeters: Double
    ) -> Bool {
        guard totalDistance > 0 else { return false }

        let progressTravelDistance: Double
        let stepTravelDistance: Double
        switch walkDirection {
        case .forward:
            progressTravelDistance = progressDistanceFromStart
            stepTravelDistance = stepDistanceFromStart
        case .reverse:
            progressTravelDistance = totalDistance - progressDistanceFromStart
            stepTravelDistance = totalDistance - stepDistanceFromStart
        }

        return progressTravelDistance >= stepTravelDistance + toleranceMeters
    }

    struct RouteProgressMatch {
        let distanceFromStartMeters: Double
        let distanceToRouteMeters: Double
    }

    static func cumulativeDistances(for polyline: [CLLocationCoordinate2D]) -> [Double] {
        guard !polyline.isEmpty else { return [] }
        var distances = Array(repeating: 0.0, count: polyline.count)
        guard polyline.count >= 2 else { return distances }

        for index in 1..<polyline.count {
            distances[index] = distances[index - 1] + polyline[index - 1].distance(to: polyline[index])
        }
        return distances
    }

    static func nearestRouteProgress(
        to point: CLLocationCoordinate2D,
        in polyline: [CLLocationCoordinate2D],
        cumulativeDistances: [Double],
        minimumDistanceFromStart: Double = 0
    ) -> RouteProgressMatch? {
        guard polyline.count >= 2,
              cumulativeDistances.count == polyline.count
        else {
            return nil
        }

        var bestAllowed: RouteProgressMatch?
        var bestAny: RouteProgressMatch?

        for index in 0..<(polyline.count - 1) {
            let projection = project(point, ontoSegmentStart: polyline[index], end: polyline[index + 1])
            let segmentLength = cumulativeDistances[index + 1] - cumulativeDistances[index]
            let distanceFromStart = cumulativeDistances[index] + projection.fraction * segmentLength
            let match = RouteProgressMatch(
                distanceFromStartMeters: distanceFromStart,
                distanceToRouteMeters: projection.distanceToSegmentMeters
            )

            if bestAny == nil || match.distanceToRouteMeters < bestAny!.distanceToRouteMeters {
                bestAny = match
            }
            if distanceFromStart >= minimumDistanceFromStart,
               bestAllowed == nil || match.distanceToRouteMeters < bestAllowed!.distanceToRouteMeters {
                bestAllowed = match
            }
        }

        return bestAllowed ?? bestAny
    }

    struct SegmentProjection {
        let distanceToSegmentMeters: Double
        let fraction: Double
    }

    static func project(
        _ point: CLLocationCoordinate2D,
        ontoSegmentStart start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D
    ) -> SegmentProjection {
        let origin = start
        let metersPerDegreeLatitude = 111_320.0
        let metersPerDegreeLongitude = metersPerDegreeLatitude * cos(origin.latitude * .pi / 180)

        func xy(_ coordinate: CLLocationCoordinate2D) -> (x: Double, y: Double) {
            (
                x: (coordinate.longitude - origin.longitude) * metersPerDegreeLongitude,
                y: (coordinate.latitude - origin.latitude) * metersPerDegreeLatitude
            )
        }

        let p = xy(point)
        let a = xy(start)
        let b = xy(end)
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return SegmentProjection(
                distanceToSegmentMeters: hypot(p.x - a.x, p.y - a.y),
                fraction: 0
            )
        }

        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        let projectedX = a.x + t * dx
        let projectedY = a.y + t * dy
        return SegmentProjection(
            distanceToSegmentMeters: hypot(p.x - projectedX, p.y - projectedY),
            fraction: t
        )
    }
}
