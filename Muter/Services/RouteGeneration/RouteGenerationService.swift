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
        minutes: Int
    ) async throws -> [Route] {
        try Task.checkCancellation()

        let cacheKey = "\(Int(start.latitude * 1000)),\(Int(start.longitude * 1000)),\(minutes)"
        if let cached = await cache.get(cacheKey) {
            logger.info("Returning \(cached.count) cached routes")
            return cached
        }

        let config = configuration.generation
        let targetSeconds = Double(minutes) * 60
        let estimatedDistance = config.walkingSpeedKmH * 1000 / 3600 * targetSeconds
        let initialRadius = estimatedDistance * config.radiusMultiplier

        let bearings = RouteGeometry.distributedBearings(count: config.maxCandidates)

        var routes: [Route] = []
        var allPolylines: [[CLLocationCoordinate2D]] = []

        for (index, bearing) in bearings.enumerated() {
            try Task.checkCancellation()

            do {
                let route = try await generateSingleLoop(
                    start: start,
                    bearing: bearing,
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
                if case RouteError.throttled = error {
                    logger.warning("Throttled, stopping generation")
                    break
                }
                logger.warning("Route \(index + 1) failed: \(error.localizedDescription)")
                continue
            }
        }

        guard !routes.isEmpty else {
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

    // MARK: - Single Loop Generation

    private func generateSingleLoop(
        start: CLLocationCoordinate2D,
        bearing: Double,
        radius: Double,
        targetMinutes: Int,
        routeIndex: Int,
        existingPolylines: [[CLLocationCoordinate2D]]
    ) async throws -> Route? {
        let config = configuration.generation
        var currentRadius = max(radius, 200)
        let targetSeconds = Double(targetMinutes) * 60

        for attempt in 0..<config.maxRetryAttempts {
            try Task.checkCancellation()

            let waypoint = start.coordinate(at: currentRadius, bearing: bearing)

            let legOut = try await fetchWalkingRoute(from: start, to: waypoint)
            try Task.checkCancellation()
            let legBack = try await fetchWalkingRoute(from: waypoint, to: start)
            try Task.checkCancellation()

            let totalTime = legOut.expectedTravelTime + legBack.expectedTravelTime
            let totalDistance = legOut.distance + legBack.distance

            let ratio = totalTime / targetSeconds
            if ratio < config.shortRatioThreshold {
                currentRadius *= config.scaleUpFactor
                logger.debug("Attempt \(attempt + 1): too short (\(Int(totalTime))s), scaling up")
                continue
            }
            if ratio > config.longRatioThreshold {
                currentRadius *= config.scaleDownFactor
                logger.debug("Attempt \(attempt + 1): too long (\(Int(totalTime))s), scaling down")
                continue
            }

            let outCoords = legOut.polyline.coordinates
            let backCoords = legBack.polyline.coordinates
            let fullPolyline = outCoords + backCoords

            // No-backtrack: verify the outbound and return legs take different streets
            let selfOverlap = RouteGeometry.polylineOverlapRatio(
                polylineA: outCoords.sampled(every: 3),
                polylineB: backCoords,
                bufferMeters: 20
            )
            if selfOverlap > config.backtrackOverlapThreshold {
                let offsetBearing = bearing + Double.random(in: 15...45) * (Bool.random() ? 1 : -1)
                let offsetWaypoint = start.coordinate(at: currentRadius, bearing: offsetBearing)
                if let offsetRoute = try? await buildLoopViaWaypoint(
                    start: start,
                    waypoint: offsetWaypoint,
                    targetSeconds: targetSeconds,
                    routeIndex: routeIndex,
                    existingPolylines: existingPolylines
                ) {
                    return offsetRoute
                }
                logger.debug("Backtrack \(Int(selfOverlap * 100))%, skipping")
                return nil
            }

            // Check overlap with already-generated routes
            let tooSimilar = existingPolylines.contains { existing in
                RouteGeometry.polylineOverlapRatio(
                    polylineA: fullPolyline.sampled(every: 5),
                    polylineB: existing,
                    bufferMeters: 30
                ) > 0.5
            }
            if tooSimilar {
                logger.debug("Too similar to existing route, skipping")
                return nil
            }

            let steps = extractSteps(from: legOut) + extractSteps(from: legBack)
            let name = RouteGeometry.routeName(bearing: bearing, distanceKm: totalDistance / 1000)

            return Route(
                name: name,
                description: "\(Int(totalTime / 60)) min loop",
                durationMinutes: Int(totalTime / 60),
                distanceKilometers: totalDistance / 1000,
                difficulty: difficulty(for: totalDistance, time: totalTime),
                coordinates: fullPolyline.map { Location($0) },
                navigationSteps: steps,
                startLocation: Location(start),
                colorIndex: routeIndex
            )
        }

        return nil
    }

    private func buildLoopViaWaypoint(
        start: CLLocationCoordinate2D,
        waypoint: CLLocationCoordinate2D,
        targetSeconds: Double,
        routeIndex: Int,
        existingPolylines: [[CLLocationCoordinate2D]]
    ) async throws -> Route? {
        let legOut = try await fetchWalkingRoute(from: start, to: waypoint)
        let legBack = try await fetchWalkingRoute(from: waypoint, to: start)

        let totalTime = legOut.expectedTravelTime + legBack.expectedTravelTime
        let totalDistance = legOut.distance + legBack.distance
        let ratio = totalTime / targetSeconds

        let config = configuration.generation
        guard ratio >= config.shortRatioThreshold && ratio <= config.longRatioThreshold else {
            return nil
        }

        let outCoords = legOut.polyline.coordinates
        let backCoords = legBack.polyline.coordinates
        let fullPolyline = outCoords + backCoords

        let selfOverlap = RouteGeometry.polylineOverlapRatio(
            polylineA: outCoords.sampled(every: 3),
            polylineB: backCoords,
            bufferMeters: 20
        )
        guard selfOverlap <= config.backtrackOverlapThreshold else { return nil }

        let bearing = start.bearing(to: waypoint)
        let steps = extractSteps(from: legOut) + extractSteps(from: legBack)
        let name = RouteGeometry.routeName(bearing: bearing, distanceKm: totalDistance / 1000)

        return Route(
            name: name,
            description: "\(Int(totalTime / 60)) min loop",
            durationMinutes: Int(totalTime / 60),
            distanceKilometers: totalDistance / 1000,
            difficulty: difficulty(for: totalDistance, time: totalTime),
            coordinates: fullPolyline.map { Location($0) },
            navigationSteps: steps,
            startLocation: Location(start),
            colorIndex: routeIndex
        )
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
            if (error as? MKError)?.code == .loadingThrottled {
                throw RouteError.throttled(waitSeconds: 60)
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

    private func difficulty(for distance: Double, time: Double) -> Route.Difficulty {
        let speedKmH = (distance / 1000) / (time / 3600)
        if distance > 8000 || speedKmH > 5.5 { return .challenging }
        if distance > 4000 || speedKmH > 4.8 { return .moderate }
        return .easy
    }
}
