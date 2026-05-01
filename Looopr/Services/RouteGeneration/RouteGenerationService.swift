import CoreLocation
import MapKit

actor LiveRouteGenerationService: RouteGenerating {
    private let configuration: AppConfiguration
    private let logger = AppLogger(category: "RouteGeneration")
    private let cache: CacheManager<String, [Route]>
    private var activeDirections: [MKDirections] = []

    init(configuration: AppConfiguration = .current) {
        self.configuration = configuration
        self.cache = CacheManager(ttl: configuration.generation.cacheTTLSeconds)
    }

    func generateLoopRoutes(
        start: CLLocationCoordinate2D,
        minutes: Int,
        walkingSpeedKmH: Double
    ) async throws -> [Route] {
        try Task.checkCancellation()

        let cacheKey = "\(Int(start.latitude * 1000)),\(Int(start.longitude * 1000)),\(minutes),\(Int(walkingSpeedKmH * 10))"
        if let cached = await cache.get(cacheKey) {
            logger.info("Returning \(cached.count) cached routes")
            return cached
        }

        let config = configuration.generation
        let targetSeconds = Double(minutes) * 60
        let walkSpeedMS = walkingSpeedKmH * 1000 / 3600
        // Quadrilateral kite perimeter ≈ 3.3r; /3.5 accounts for road factor
        let initialRadius = targetSeconds * walkSpeedMS / 3.5

        logger.info("Generating routes: \(minutes)min @ \(String(format: "%.1f", walkingSpeedKmH))km/h, initial radius \(Int(initialRadius))m")

        let bearings = RouteGeometry.distributedBearings(count: config.maxCandidates)

        var routes: [Route] = []
        var allPolylines: [[CLLocationCoordinate2D]] = []

        for (index, bearing) in bearings.enumerated() {
            try Task.checkCancellation()

            // 800ms between candidates — spreads requests without excessive waiting
            if index > 0 {
                try await Task.sleep(for: .milliseconds(800))
            }

            do {
                let route = try await generateQuadrilateralLoop(
                    start: start,
                    primaryBearing: bearing,
                    radius: initialRadius,
                    targetMinutes: minutes,
                    routeIndex: index,
                    existingPolylines: allPolylines
                )
                if let route {
                    routes.append(route)
                    allPolylines.append(route.pathCoordinates)
                    logger.info("Route \(index + 1): \(route.name) - \(route.durationMinutes)min, \(String(format: "%.1f", route.distanceKilometers))km")
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if case RouteError.throttled(let waitSeconds) = error {
                    logger.warning("Throttled at route \(index + 1), waiting \(waitSeconds)s to resume")
                    try await Task.sleep(for: .seconds(Double(waitSeconds) + 2))
                    continue
                }
                logger.warning("Route \(index + 1) failed: \(error.localizedDescription)")
                continue
            }
        }

        if routes.isEmpty {
            throw RouteError.noRoutesFound
        }

        let sorted = routes.sorted { $0.durationMinutes < $1.durationMinutes }
        await cache.set(cacheKey, value: sorted)
        logger.info("Generated \(sorted.count) routes for \(minutes) minutes")
        return sorted
    }

    func cancelInFlightRequests() async {
        for directions in activeDirections {
            directions.cancel()
        }
        activeDirections.removeAll()
    }

    nonisolated func generateLoopRoutesStream(
        start: CLLocationCoordinate2D,
        minutes: Int,
        maxRoutes: Int,
        walkingSpeedKmH: Double
    ) -> AsyncThrowingStream<Route, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // Check cache first — yield cached routes immediately (up to maxRoutes)
                    let cacheKey = "\(Int(start.latitude * 1000)),\(Int(start.longitude * 1000)),\(minutes),\(Int(walkingSpeedKmH * 10))"
                    if let cached = await self.cache.get(cacheKey) {
                        self.logger.info("Streaming \(min(cached.count, maxRoutes)) cached routes")
                        for route in cached.prefix(maxRoutes) {
                            continuation.yield(route)
                        }
                        continuation.finish()
                        return
                    }

                    let routes = try await self.streamGeneration(
                        start: start,
                        minutes: minutes,
                        maxRoutes: maxRoutes,
                        walkingSpeedKmH: walkingSpeedKmH,
                        cacheKey: cacheKey,
                        continuation: continuation
                    )

                    if routes.isEmpty {
                        continuation.finish(throwing: RouteError.noRoutesFound)
                    } else {
                        continuation.finish()
                    }
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func streamGeneration(
        start: CLLocationCoordinate2D,
        minutes: Int,
        maxRoutes: Int,
        walkingSpeedKmH: Double,
        cacheKey: String,
        continuation: AsyncThrowingStream<Route, Error>.Continuation
    ) async throws -> [Route] {
        let config = configuration.generation
        let targetSeconds = Double(minutes) * 60
        let walkSpeedMS = walkingSpeedKmH * 1000 / 3600
        let initialRadius = targetSeconds * walkSpeedMS / 3.5

        logger.info("Streaming routes: \(minutes)min @ \(String(format: "%.1f", walkingSpeedKmH))km/h, initial radius \(Int(initialRadius))m")

        let bearings = RouteGeometry.distributedBearings(count: config.maxCandidates)

        var routes: [Route] = []
        var allPolylines: [[CLLocationCoordinate2D]] = []

        for (index, bearing) in bearings.enumerated() {
            try Task.checkCancellation()

            // Early stop — we have enough routes
            if routes.count >= maxRoutes { break }

            if index > 0 {
                try await Task.sleep(for: .milliseconds(800))
            }

            do {
                let route = try await generateQuadrilateralLoop(
                    start: start,
                    primaryBearing: bearing,
                    radius: initialRadius,
                    targetMinutes: minutes,
                    routeIndex: index,
                    existingPolylines: allPolylines
                )
                if let route {
                    routes.append(route)
                    allPolylines.append(route.pathCoordinates)
                    logger.info("Route \(index + 1): \(route.name) - \(route.durationMinutes)min, \(String(format: "%.1f", route.distanceKilometers))km")
                    continuation.yield(route)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if case RouteError.throttled(let waitSeconds) = error {
                    logger.warning("Throttled at route \(index + 1), waiting \(waitSeconds)s to resume")
                    try await Task.sleep(for: .seconds(Double(waitSeconds) + 2))
                    continue
                }
                logger.warning("Route \(index + 1) failed: \(error.localizedDescription)")
                continue
            }
        }

        // Cache the full set (all generated routes, not limited to maxRoutes)
        if !routes.isEmpty {
            let sorted = routes.sorted { $0.durationMinutes < $1.durationMinutes }
            await cache.set(cacheKey, value: sorted)
            logger.info("Generated \(sorted.count) routes for \(minutes) minutes")
        }

        return routes
    }

    // MARK: - Quadrilateral Loop Generation

    /// Generates a kite-shaped quadrilateral loop with 3 waypoints (4 legs).
    /// Waypoints: wp1 at B-spread, 0.75r  |  wp2 at B, 1.0r  |  wp3 at B+spread, 0.75r
    /// Route: start → wp1 → wp2 → wp3 → start
    private func generateQuadrilateralLoop(
        start: CLLocationCoordinate2D,
        primaryBearing: Double,
        radius: Double,
        targetMinutes: Int,
        routeIndex: Int,
        existingPolylines: [[CLLocationCoordinate2D]]
    ) async throws -> Route? {
        let config = configuration.generation
        var currentRadius = max(radius, 150)
        let targetSeconds = Double(targetMinutes) * 60

        // Lateral spread (degrees either side of primary bearing for outer waypoints)
        var lateralSpread = 60.0

        for attempt in 0..<3 {
            try Task.checkCancellation()

            let wp1 = start.coordinate(at: currentRadius * 0.75, bearing: primaryBearing - lateralSpread)
            let wp2 = start.coordinate(at: currentRadius,        bearing: primaryBearing)
            let wp3 = start.coordinate(at: currentRadius * 0.75, bearing: primaryBearing + lateralSpread)

            let leg1 = try await fetchWalkingRoute(from: start, to: wp1)
            try Task.checkCancellation()
            let leg2 = try await fetchWalkingRoute(from: wp1,  to: wp2)
            try Task.checkCancellation()
            let leg3 = try await fetchWalkingRoute(from: wp2,  to: wp3)
            try Task.checkCancellation()
            let leg4 = try await fetchWalkingRoute(from: wp3,  to: start)
            try Task.checkCancellation()

            let totalTime     = leg1.expectedTravelTime + leg2.expectedTravelTime +
                                leg3.expectedTravelTime + leg4.expectedTravelTime
            let totalDistance = leg1.distance + leg2.distance + leg3.distance + leg4.distance
            let ratio         = totalTime / targetSeconds

            // Proportional radius scaling when outside acceptable range
            if ratio < config.shortRatioThreshold || ratio > config.longRatioThreshold {
                currentRadius = max(currentRadius * (1.0 / ratio), 100)
                logger.debug("Attempt \(attempt + 1): ratio \(String(format: "%.2f", ratio)) (\(Int(totalTime))s vs \(Int(targetSeconds))s), scaling radius to \(Int(currentRadius))m")
                continue
            }

            let coords1 = leg1.polyline.coordinates
            let coords2 = leg2.polyline.coordinates
            let coords3 = leg3.polyline.coordinates
            let coords4 = leg4.polyline.coordinates
            let fullPolyline = coords1 + coords2 + coords3 + coords4

            // Check leg overlap — adjacent legs and the two "start" legs (1 and 4)
            let overlap12 = RouteGeometry.polylineOverlapRatio(polylineA: coords1.sampled(every: 3), polylineB: coords2, bufferMeters: 20)
            let overlap23 = RouteGeometry.polylineOverlapRatio(polylineA: coords2.sampled(every: 3), polylineB: coords3, bufferMeters: 20)
            let overlap34 = RouteGeometry.polylineOverlapRatio(polylineA: coords3.sampled(every: 3), polylineB: coords4, bufferMeters: 20)
            let overlap14 = RouteGeometry.polylineOverlapRatio(polylineA: coords1.sampled(every: 3), polylineB: coords4, bufferMeters: 20)
            let maxLegOverlap = max(overlap12, overlap23, overlap34, overlap14)

            if maxLegOverlap > config.backtrackOverlapThreshold {
                lateralSpread = min(lateralSpread + 15, 90)
                logger.debug("Attempt \(attempt + 1): legs overlap \(Int(maxLegOverlap * 100))%, widening spread to \(Int(lateralSpread))°")
                continue
            }

            // Check per-leg self-overlap (catches dead-end out-and-back spurs within a single leg)
            let legSelfOverlap = RouteGeometry.maxLegSelfOverlap(
                legs: [coords1, coords2, coords3, coords4], bufferMeters: 25
            )
            // Check full-route self-overlap and backtrack segments
            let selfOverlap = RouteGeometry.selfOverlapRatio(polyline: fullPolyline, bufferMeters: 25)
            let backtrackRatio = RouteGeometry.backtrackSegmentRatio(polyline: fullPolyline)

            if legSelfOverlap > 0.45 || selfOverlap > 0.40 || backtrackRatio > 0.20 {
                lateralSpread = min(lateralSpread + 15, 90)
                logger.debug("Attempt \(attempt + 1): legSelf \(Int(legSelfOverlap * 100))%, selfOverlap \(Int(selfOverlap * 100))%, backtrack \(Int(backtrackRatio * 100))%, widening spread to \(Int(lateralSpread))°")
                continue
            }

            // Reject routes with impossible straight-line segments (water crossings
            // where the routing engine returned a crow-flies line instead of a real path).
            // This is a hard skip — widening the spread won't help since the geometry
            // is fundamentally placing waypoints across water.
            if RouteGeometry.containsStraightLineSegment(polyline: fullPolyline) {
                logger.warning("Route \(routeIndex + 1): straight-line segment detected (likely impossible water crossing), skipping bearing")
                return nil
            }

            // Check similarity with already-accepted routes
            let tooSimilar = existingPolylines.contains { existing in
                RouteGeometry.polylineOverlapRatio(
                    polylineA: fullPolyline.sampled(every: 5), polylineB: existing, bufferMeters: 30
                ) > 0.5
            }
            if tooSimilar {
                logger.debug("Too similar to existing route, skipping")
                return nil
            }

            let steps = extractSteps(from: leg1) + extractSteps(from: leg2) +
                        extractSteps(from: leg3) + extractSteps(from: leg4)
            let hasFerry = [leg1, leg2, leg3, leg4].contains(where: { legContainsFerry($0) })
            let name = RouteGeometry.routeName(bearing: primaryBearing, distanceKm: totalDistance / 1000)

            logger.info("Quadrilateral loop: \(Int(totalTime/60))min, \(String(format: "%.1f", totalDistance/1000))km, ratio \(String(format: "%.2f", ratio)), legOverlap \(Int(maxLegOverlap * 100))%, selfOverlap \(Int(selfOverlap * 100))%, ferry: \(hasFerry)")

            return Route(
                name: name,
                description: "\(Int(totalTime / 60)) min loop",
                durationMinutes: Int(totalTime / 60),
                distanceKilometers: totalDistance / 1000,
                difficulty: difficulty(for: totalDistance, time: totalTime),
                coordinates: fullPolyline.map { Location($0) },
                navigationSteps: steps,
                startLocation: Location(start),
                colorIndex: routeIndex,
                containsFerry: hasFerry
            )
        }

        logger.debug("Failed to converge after 3 attempts for bearing \(Int(primaryBearing))°")
        return nil
    }

    // MARK: - MKDirections

    private func fetchWalkingRoute(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) async throws -> MKRoute {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .walking

        let directions = MKDirections(request: request)
        activeDirections.append(directions)

        do {
            let response = try await withTaskCancellationHandler {
                try await directions.calculate()
            } onCancel: {
                directions.cancel()
            }

            activeDirections.removeAll { $0 === directions }

            guard let route = response.routes.first else {
                throw RouteError.directionsUnavailable
            }
            return route
        } catch let error as NSError {
            activeDirections.removeAll { $0 === directions }

            if error.domain == "GEOErrorDomain" && error.code == -3 {
                throw RouteError.throttled(waitSeconds: 60)
            }
            if let mkError = error as? MKError, mkError.code == .loadingThrottled {
                throw RouteError.throttled(waitSeconds: 60)
            }
            if error.domain == MKError.errorDomain && error.code == 3 {
                throw RouteError.throttled(waitSeconds: 45)
            }
            throw RouteError.generationFailed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func extractSteps(from route: MKRoute) -> [NavigationStep] {
        route.steps.compactMap { step in
            guard !step.instructions.isEmpty else { return nil }
            return NavigationStep(
                instruction: step.instructions,
                distanceMeters: step.distance,
                coordinate: step.polyline.coordinate
            )
        }
    }

    /// Check whether an MKRoute leg contains ferry transport or ferry-related instructions.
    /// Uses instruction text matching rather than `transportType` because MapKit
    /// inconsistently labels walking steps (often `.any` instead of `.walking`).
    private func legContainsFerry(_ route: MKRoute) -> Bool {
        let ferryKeywords = ["ferry", "boat", "water taxi", "take the ferry"]
        for step in route.steps {
            let instruction = step.instructions.lowercased()
            if ferryKeywords.contains(where: { instruction.contains($0) }) {
                return true
            }
        }
        return false
    }

    private func difficulty(for distance: Double, time: Double) -> Route.Difficulty {
        let speedKmH = (distance / 1000) / (time / 3600)
        if distance > 8000 || speedKmH > 5.5 { return .challenging }
        if distance > 4000 || speedKmH > 4.8 { return .moderate }
        return .easy
    }
}
