import CoreLocation
import Foundation

/// Paid-tier route generation using the Mapbox Directions REST API.
/// Generates pentagon-shaped loops (4 waypoints, 5 legs) for richer route geometry.
/// All candidates are generated in parallel with TaskGroup for fast results.
final class MapboxRouteGenerationService: RouteGenerating, @unchecked Sendable {

    private let configuration: AppConfiguration
    private let accessToken: String
    private let cache: CacheManager<String, [Route]>
    private let logger = AppLogger(category: "MapboxRouteGeneration")

    init(configuration: AppConfiguration = .current, accessToken: String) {
        self.configuration = configuration
        self.accessToken = accessToken
        self.cache = CacheManager(ttl: configuration.generation.cacheTTLSeconds)
    }

    // MARK: - RouteGenerating

    func generateLoopRoutes(
        start: CLLocationCoordinate2D,
        minutes: Int,
        walkingSpeedKmH: Double
    ) async throws -> [Route] {
        try Task.checkCancellation()

        let cacheKey = cacheKey(for: start, minutes: minutes, speedKmH: walkingSpeedKmH)
        if let cached = await cache.get(cacheKey) {
            logger.info("Returning \(cached.count) cached Mapbox routes")
            return cached
        }

        let routes = try await generateCandidates(
            start: start,
            minutes: minutes,
            maxRoutes: configuration.freemium.paidRouteLimit,
            walkingSpeedKmH: walkingSpeedKmH,
            cacheKey: cacheKey,
            continuation: nil
        )
        if routes.isEmpty { throw RouteError.noRoutesFound }
        return routes
    }

    func cancelInFlightRequests() async {
        // URLSession tasks are cancelled automatically via Swift structured concurrency
    }

    func generateLoopRoutesStream(
        start: CLLocationCoordinate2D,
        minutes: Int,
        maxRoutes: Int,
        walkingSpeedKmH: Double
    ) -> AsyncThrowingStream<Route, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let key = self.cacheKey(for: start, minutes: minutes, speedKmH: walkingSpeedKmH)

                    if let cached = await self.cache.get(key) {
                        self.logger.info("Streaming \(min(cached.count, maxRoutes)) cached Mapbox routes")
                        for route in cached.prefix(maxRoutes) {
                            continuation.yield(route)
                        }
                        continuation.finish()
                        return
                    }

                    let routes = try await self.generateCandidates(
                        start: start,
                        minutes: minutes,
                        maxRoutes: maxRoutes,
                        walkingSpeedKmH: walkingSpeedKmH,
                        cacheKey: key,
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
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Parallel generation + deduplication

    /// Runs all candidates in parallel, deduplicates by similarity, yields up to maxRoutes.
    private func generateCandidates(
        start: CLLocationCoordinate2D,
        minutes: Int,
        maxRoutes: Int,
        walkingSpeedKmH: Double,
        cacheKey: String,
        continuation: AsyncThrowingStream<Route, Error>.Continuation?
    ) async throws -> [Route] {
        let config = configuration.generation
        let targetSeconds = Double(minutes) * 60
        let walkSpeedMS = walkingSpeedKmH * 1000 / 3600
        // Pentagon perimeter ≈ 3.7r; /4.5 accounts for road tortuosity factor
        let initialRadius = targetSeconds * walkSpeedMS / 4.5

        logger.info("Mapbox generating: \(minutes)min @ \(String(format: "%.1f", walkingSpeedKmH))km/h, initial radius \(Int(initialRadius))m, \(config.maxCandidates) parallel candidates")

        let bearings = RouteGeometry.distributedBearings(count: config.maxCandidates)

        // Generate all candidates in parallel
        var candidateRoutes: [(index: Int, route: Route)] = []
        try await withThrowingTaskGroup(of: (Int, Route?).self) { group in
            for (index, bearing) in bearings.enumerated() {
                group.addTask { [self] in
                    do {
                        let route = try await self.generatePentagonLoop(
                            start: start,
                            primaryBearing: bearing,
                            radius: initialRadius,
                            targetMinutes: minutes,
                            routeIndex: index
                        )
                        return (index, route)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        self.logger.warning("Mapbox candidate \(index + 1) failed: \(error.localizedDescription)")
                        return (index, nil)
                    }
                }
            }

            for try await (index, route) in group {
                if let route {
                    candidateRoutes.append((index, route))
                }
            }
        }

        // Sort closest-to-target duration first for best user experience
        let sorted = candidateRoutes
            .sorted { $0.route.durationMinutes < $1.route.durationMinutes }
            .map(\.route)

        // Deduplicate: keep routes that aren't too similar to already-accepted ones
        var accepted: [Route] = []
        var acceptedPolylines: [[CLLocationCoordinate2D]] = []

        for candidate in sorted {
            let polyline = candidate.pathCoordinates
            let tooSimilar = acceptedPolylines.contains { existing in
                RouteGeometry.polylineOverlapRatio(
                    polylineA: polyline.sampled(every: 5),
                    polylineB: existing,
                    bufferMeters: 30
                ) > 0.5
            }
            if !tooSimilar {
                accepted.append(candidate)
                acceptedPolylines.append(polyline)
                continuation?.yield(candidate)
                if accepted.count >= maxRoutes { break }
            }
        }

        if !accepted.isEmpty {
            await cache.set(cacheKey, value: accepted)
            logger.info("Mapbox: cached \(accepted.count) routes for \(minutes)min")
        }

        return accepted
    }

    // MARK: - Pentagon Loop

    /// Pentagon: 4 waypoints forming an arrowhead shape, 5 legs.
    /// wp1: B-spread*0.80r  wp2: B-spread*0.4, 1.05r  wp3: B+spread*0.4, 1.05r  wp4: B+spread*0.80r
    private func generatePentagonLoop(
        start: CLLocationCoordinate2D,
        primaryBearing: Double,
        radius: Double,
        targetMinutes: Int,
        routeIndex: Int
    ) async throws -> Route? {
        let config = configuration.generation
        var currentRadius = max(radius, 150)
        let targetSeconds = Double(targetMinutes) * 60
        var spread = 60.0

        for attempt in 0..<3 {
            try Task.checkCancellation()

            let wp1 = start.coordinate(at: currentRadius * 0.80, bearing: primaryBearing - spread)
            let wp2 = start.coordinate(at: currentRadius * 1.05, bearing: primaryBearing - spread * 0.4)
            let wp3 = start.coordinate(at: currentRadius * 1.05, bearing: primaryBearing + spread * 0.4)
            let wp4 = start.coordinate(at: currentRadius * 0.80, bearing: primaryBearing + spread)

            // One Mapbox call for all 5 legs: start→wp1→wp2→wp3→wp4→start
            let allCoords = [start, wp1, wp2, wp3, wp4, start]
            let response = try await fetchMapboxRoute(coordinates: allCoords)
            try Task.checkCancellation()

            let totalTime     = response.duration
            let totalDistance = response.distance
            let ratio         = totalTime / targetSeconds

            if ratio < config.shortRatioThreshold || ratio > config.longRatioThreshold {
                currentRadius = max(currentRadius * (1.0 / ratio), 100)
                logger.debug("Attempt \(attempt + 1): ratio \(String(format: "%.2f", ratio)), scaling to \(Int(currentRadius))m")
                continue
            }

            let fullPolyline: [CLLocationCoordinate2D] = response.geometry.coordinates.map {
                CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
            }

            // --- Overlap & backtrack detection (per-leg and full-route) ---
            let legPolylines: [[CLLocationCoordinate2D]] = response.legs.map { leg in
                leg.steps.flatMap { step -> [CLLocationCoordinate2D] in
                    // Each step's geometry starts at the maneuver location;
                    // reconstruct approximate leg polylines from step positions.
                    [CLLocationCoordinate2D(latitude: step.maneuver.location[1],
                                           longitude: step.maneuver.location[0])]
                }
            }

            // Check adjacent-leg and wrap-around-leg overlap (5 legs: 0-1, 1-2, 2-3, 3-4, 4-0)
            // Plus cross-leg pairs most likely to overlap: leg0↔leg4 (both touch start)
            var maxLegOverlap = 0.0
            if response.legs.count >= 2 {
                // Build per-leg polylines from the full route using cumulative step distances
                var legCoords: [[CLLocationCoordinate2D]] = []
                var startIdx = 0
                for leg in response.legs {
                    let legPointCount = max(1, Int(leg.distance / 10)) // ~1 point per 10m
                    let endIdx = min(startIdx + legPointCount, fullPolyline.count)
                    if startIdx < endIdx {
                        legCoords.append(Array(fullPolyline[startIdx..<endIdx]))
                    }
                    startIdx = endIdx
                }
                // Append any remaining points to the last leg
                if startIdx < fullPolyline.count, !legCoords.isEmpty {
                    legCoords[legCoords.count - 1].append(contentsOf: fullPolyline[startIdx...])
                }

                // Check all adjacent pairs
                for i in 0..<(legCoords.count - 1) {
                    let overlap = RouteGeometry.polylineOverlapRatio(
                        polylineA: legCoords[i].sampled(every: 3),
                        polylineB: legCoords[i + 1],
                        bufferMeters: 20
                    )
                    maxLegOverlap = max(maxLegOverlap, overlap)
                }
                // Check first and last leg (both connect to start)
                if legCoords.count >= 3 {
                    let overlapWrap = RouteGeometry.polylineOverlapRatio(
                        polylineA: legCoords[0].sampled(every: 3),
                        polylineB: legCoords[legCoords.count - 1],
                        bufferMeters: 20
                    )
                    maxLegOverlap = max(maxLegOverlap, overlapWrap)
                }
            }

            if maxLegOverlap > config.backtrackOverlapThreshold {
                spread = min(spread + 12, 90)
                logger.debug("Attempt \(attempt + 1): leg overlap \(Int(maxLegOverlap * 100))%, widening spread to \(Int(spread))°")
                continue
            }

            // Check full-route self-overlap (catches dead-end out-and-back spurs)
            let selfOverlap = RouteGeometry.selfOverlapRatio(polyline: fullPolyline, bufferMeters: 25)
            let backtrackRatio = RouteGeometry.backtrackSegmentRatio(polyline: fullPolyline)
            if selfOverlap > 0.40 || backtrackRatio > 0.20 {
                spread = min(spread + 12, 90)
                logger.debug("Attempt \(attempt + 1): self-overlap \(Int(selfOverlap * 100))%, backtrack \(Int(backtrackRatio * 100))%, widening spread")
                continue
            }

            // Reject routes with impossible straight-line segments (water crossings
            // where the routing engine returned a crow-flies line instead of a real path).
            // This is a hard skip — widening the spread won't help since the geometry
            // is fundamentally placing waypoints across water.
            if RouteGeometry.containsStraightLineSegment(polyline: fullPolyline) {
                logger.warning("Candidate \(routeIndex + 1): straight-line segment detected (likely impossible water crossing), skipping bearing")
                return nil
            }

            let steps: [NavigationStep] = response.legs.flatMap { leg in
                leg.steps.compactMap { step -> NavigationStep? in
                    guard !step.maneuver.instruction.isEmpty else { return nil }
                    let coord = CLLocationCoordinate2D(
                        latitude:  step.maneuver.location[1],
                        longitude: step.maneuver.location[0]
                    )
                    return NavigationStep(
                        instruction: step.maneuver.instruction,
                        distanceMeters: step.distance,
                        coordinate: coord
                    )
                }
            }

            let hasFerry = routeContainsFerry(response)
            let name = RouteGeometry.routeName(bearing: primaryBearing, distanceKm: totalDistance / 1000)
            logger.info("Pentagon loop: \(Int(totalTime/60))min, \(String(format: "%.1f", totalDistance/1000))km, ratio \(String(format: "%.2f", ratio)), legOverlap \(Int(maxLegOverlap * 100))%, selfOverlap \(Int(selfOverlap * 100))%, ferry: \(hasFerry)")

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

        logger.debug("Pentagon failed to converge after 3 attempts for bearing \(Int(primaryBearing))°")
        return nil
    }

    // MARK: - Mapbox REST API

    private func fetchMapboxRoute(coordinates: [CLLocationCoordinate2D]) async throws -> MapboxRoute {
        let coordsString = coordinates
            .map { "\($0.longitude),\($0.latitude)" }
            .joined(separator: ";")

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.mapbox.com"
        components.path = "/directions/v5/mapbox/walking/\(coordsString)"
        components.queryItems = [
            URLQueryItem(name: "access_token",     value: accessToken),
            URLQueryItem(name: "geometries",       value: "geojson"),
            URLQueryItem(name: "overview",         value: "full"),
            URLQueryItem(name: "steps",            value: "true"),
            URLQueryItem(name: "continue_straight", value: "true")
        ]

        guard let url = components.url else {
            throw RouteError.generationFailed("Invalid Mapbox URL")
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse else {
            throw RouteError.generationFailed("Invalid Mapbox response")
        }
        if http.statusCode == 429 {
            throw RouteError.throttled(waitSeconds: 60)
        }
        guard http.statusCode == 200 else {
            throw RouteError.generationFailed("Mapbox HTTP \(http.statusCode)")
        }

        let decoded = try JSONDecoder().decode(MapboxDirectionsResponse.self, from: data)
        guard let route = decoded.routes.first else {
            throw RouteError.directionsUnavailable
        }
        return route
    }

    // MARK: - Helpers

    private func cacheKey(for start: CLLocationCoordinate2D, minutes: Int, speedKmH: Double) -> String {
        "mapbox_\(Int(start.latitude * 1000)),\(Int(start.longitude * 1000)),\(minutes),\(Int(speedKmH * 10))"
    }

    private func difficulty(for distance: Double, time: Double) -> Route.Difficulty {
        let speedKmH = (distance / 1000) / (time / 3600)
        if distance > 8000 || speedKmH > 5.5 { return .challenging }
        if distance > 4000 || speedKmH > 4.8 { return .moderate }
        return .easy
    }

    /// Check whether any step in the Mapbox response uses a ferry transport mode
    /// or contains ferry-related keywords in the maneuver instructions.
    private func routeContainsFerry(_ response: MapboxRoute) -> Bool {
        let ferryKeywords = ["ferry", "boat", "water taxi"]
        for leg in response.legs {
            for step in leg.steps {
                // Mapbox Directions API returns a "mode" field per step
                if let mode = step.mode, mode.lowercased() == "ferry" {
                    return true
                }
                // Fallback: check instruction text for ferry-related keywords
                let instruction = step.maneuver.instruction.lowercased()
                if ferryKeywords.contains(where: { instruction.contains($0) }) {
                    return true
                }
            }
        }
        return false
    }
}

// MARK: - Mapbox Response Models

private struct MapboxDirectionsResponse: Codable {
    let routes: [MapboxRoute]
}

private struct MapboxRoute: Codable {
    let distance: Double
    let duration: Double
    let geometry: MapboxGeometry
    let legs: [MapboxLeg]
}

private struct MapboxGeometry: Codable {
    let coordinates: [[Double]]
}

private struct MapboxLeg: Codable {
    let distance: Double
    let duration: Double
    let steps: [MapboxStep]
}

private struct MapboxStep: Codable {
    let maneuver: MapboxManeuver
    let distance: Double
    /// Transport mode for this step: "walking", "ferry", "cycling", etc.
    let mode: String?
}

private struct MapboxManeuver: Codable {
    let instruction: String
    let location: [Double]
}
