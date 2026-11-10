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

        let cacheKey = cacheKey(for: start, minutes: minutes, speedKmH: walkingSpeedKmH, maxRoutes: configuration.freemium.paidRouteLimit)
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
                    let key = self.cacheKey(for: start, minutes: minutes, speedKmH: walkingSpeedKmH, maxRoutes: maxRoutes)

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
        var candidateRoutes: [(index: Int, result: PentagonResult)] = []
        var failureTally: [String: Int] = [:]
        try await withThrowingTaskGroup(of: (Int, PentagonResult?, String?).self) { group in
            for (index, bearing) in bearings.enumerated() {
                group.addTask { [self] in
                    do {
                        let result = try await self.generatePentagonLoop(
                            start: start,
                            primaryBearing: bearing,
                            radius: initialRadius,
                            targetMinutes: minutes,
                            routeIndex: index
                        )
                        return (index, result, nil)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        let kind = Self.failureKind(of: error)
                        self.logger.warning("Mapbox candidate \(index + 1) failed: \(kind)")
                        return (index, nil, kind)
                    }
                }
            }

            for try await (index, result, failureKind) in group {
                if let result {
                    candidateRoutes.append((index, result))
                } else if let failureKind {
                    failureTally[failureKind, default: 0] += 1
                }
            }
        }

        if candidateRoutes.isEmpty {
            let detail = failureTally
                .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
                .map { "\($0.key):\($0.value)" }
                .joined(separator: ",")
            logger.error("Mapbox: no usable candidate (\(detail))")
            // Every request failed before reaching Mapbox: that's the
            // network, not this place, so don't tell the user "no routes here".
            if !failureTally.isEmpty, failureTally.keys.allSatisfy({ $0.hasPrefix("network") }) {
                throw RouteError.generationFailed("network (\(detail))")
            }
            throw RouteError.noUsableRoutes(detail: detail.isEmpty ? "none" : detail)
        }

        // Loops of the asked length win. Only when there are none (sparse or
        // hilly areas where no short loop exists) do the closest matches
        // show, so the user gets a walk, not nothing. Either way the loops
        // come out closest to the asked time first: the free tier shows the
        // first two that arrive, and those must be the best fits, not the
        // shortest (before 1.5 a 30-min ask could get the 20- and 22-min
        // loops while a 30-min one existed).
        let fitting = candidateRoutes.filter { $0.result.fitsLength }
        if fitting.isEmpty {
            logger.info("Mapbox: no \(minutes)-min loop, showing \(candidateRoutes.count) closest matches")
        }
        let sorted = Self.closestFirst(
            fitting.isEmpty ? candidateRoutes.map(\.result) : fitting.map(\.result)
        )

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

    /// Orders candidates by how many minutes their walking time is off the
    /// asked time (ratio 1.0 = exact): for a 30-minute ask, 27 and 34 come
    /// before 22, which comes before 40. Ties keep the shorter loop first.
    static func closestFirst(_ candidates: [PentagonResult]) -> [Route] {
        candidates
            .sorted {
                let a = abs($0.ratio - 1), b = abs($1.ratio - 1)
                return a != b ? a < b : $0.route.durationMinutes < $1.route.durationMinutes
            }
            .map(\.route)
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
    ) async throws -> PentagonResult {
        let config = configuration.generation
        var currentRadius = max(radius, 150)
        let targetSeconds = Double(targetMinutes) * 60
        var spread = 60.0
        // Why the last attempt was rejected, reported if none succeeds.
        var lastRejection = "not_converged"
        var closestMatch: (route: Route, ratio: Double)?

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
            // A zero-length answer (every waypoint snapped onto the same
            // point, e.g. no walkable network nearby) made the radius
            // infinite and crashed on Int(currentRadius) in 1.2 (LOOOPR-IOS-5).
            guard totalTime.isFinite, totalTime > 0, totalDistance > 0,
                  response.geometry.coordinates.count >= 2 else {
                throw CandidateFailure("empty_route")
            }
            let ratio         = totalTime / targetSeconds
            let lengthFits    = ratio >= config.shortRatioThreshold && ratio <= config.longRatioThreshold

            let fullPolyline: [CLLocationCoordinate2D] = response.geometry.coordinates.map {
                CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
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

            // Shape checks run on every attempt (not only when the length
            // fits), so a clean loop of the wrong length can still serve as
            // the closest match.
            let selfOverlap = RouteGeometry.selfOverlapRatio(polyline: fullPolyline, bufferMeters: 25)
            let backtrackRatio = RouteGeometry.backtrackSegmentRatio(polyline: fullPolyline)
            let shapeProblem: String?
            if maxLegOverlap > config.backtrackOverlapThreshold {
                shapeProblem = "leg_overlap"
            } else if selfOverlap > 0.40 {
                shapeProblem = "self_overlap"
            } else if backtrackRatio > 0.20 {
                shapeProblem = "backtrack"
            } else if RouteGeometry.containsStraightLineSegment(polyline: fullPolyline) {
                // A crow-flies segment = the routing engine "crossed" water.
                shapeProblem = "water"
            } else {
                shapeProblem = nil
            }

            if !lengthFits {
                if shapeProblem == nil,
                   ratio >= Self.closestMatchRatioRange.lowerBound,
                   ratio <= Self.closestMatchRatioRange.upperBound,
                   closestMatch.map({ abs(log(ratio)) < abs(log($0.ratio)) }) ?? true {
                    closestMatch = (makeRoute(response, polyline: fullPolyline, start: start,
                                              bearing: primaryBearing, routeIndex: routeIndex), ratio)
                }
                // Clamp the step so one odd answer can't fling the waypoints away.
                let scale = min(max(1.0 / ratio, 0.33), 3.0)
                currentRadius = min(max(currentRadius * scale, 100), 20_000)
                lastRejection = ratio < config.shortRatioThreshold ? "too_short" : "too_long"
                logger.debug("Attempt \(attempt + 1): ratio \(String(format: "%.2f", ratio)), scaling to \(Int(currentRadius))m")
                continue
            }

            if let shapeProblem {
                // Widening the spread won't move waypoints off water.
                if shapeProblem == "water" { throw CandidateFailure("water") }
                lastRejection = shapeProblem
                spread = min(spread + 12, 90)
                logger.debug("Attempt \(attempt + 1): \(shapeProblem) (leg \(Int(maxLegOverlap * 100))%, self \(Int(selfOverlap * 100))%, backtrack \(Int(backtrackRatio * 100))%), widening spread to \(Int(spread))°")
                continue
            }

            logger.info("Pentagon loop: \(Int(totalTime/60))min, \(String(format: "%.1f", totalDistance/1000))km, ratio \(String(format: "%.2f", ratio)), legOverlap \(Int(maxLegOverlap * 100))%, selfOverlap \(Int(selfOverlap * 100))%")
            return PentagonResult(
                route: makeRoute(response, polyline: fullPolyline, start: start, bearing: primaryBearing, routeIndex: routeIndex),
                ratio: ratio,
                fitsLength: true
            )
        }

        if let closestMatch {
            logger.info("Pentagon: no loop of the asked length for bearing \(Int(primaryBearing))°, keeping closest (ratio \(String(format: "%.2f", closestMatch.ratio)))")
            return PentagonResult(route: closestMatch.route, ratio: closestMatch.ratio, fitsLength: false)
        }
        logger.debug("Pentagon failed to converge after 3 attempts for bearing \(Int(primaryBearing))°")
        throw CandidateFailure(lastRejection)
    }

    /// A finished candidate; `fitsLength` is false for a closest match
    /// kept because no attempt came within the length band.
    struct PentagonResult {
        let route: Route
        let ratio: Double
        let fitsLength: Bool
    }

    /// How far off the asked length a closest match may be (0.4× to 3×):
    /// a 55-min loop for a 30-min ask beats nothing, a 3-hour one doesn't.
    static let closestMatchRatioRange: ClosedRange<Double> = 0.4...3.0

    private func makeRoute(
        _ response: MapboxRoute,
        polyline: [CLLocationCoordinate2D],
        start: CLLocationCoordinate2D,
        bearing: Double,
        routeIndex: Int
    ) -> Route {
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
                    coordinate: coord,
                    maneuverType: step.maneuver.type,
                    maneuverModifier: step.maneuver.modifier,
                    streetName: step.name
                )
            }
        }
        return Route(
            name: RouteGeometry.routeName(bearing: bearing, distanceKm: response.distance / 1000),
            description: "\(Int(response.duration / 60)) min loop",
            durationMinutes: Int(response.duration / 60),
            distanceKilometers: response.distance / 1000,
            difficulty: difficulty(for: response.distance, time: response.duration),
            coordinates: polyline.map { Location($0) },
            navigationSteps: steps,
            startLocation: Location(start),
            colorIndex: routeIndex,
            containsFerry: routeContainsFerry(response)
        )
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
            URLQueryItem(name: "continue_straight", value: "true"),
            // Turn instructions in the app's language (Mapbox falls back to English
            // for languages it doesn't support).
            URLQueryItem(name: "language",         value: LocalizationManager.mapboxLanguageCode)
        ]

        guard let url = components.url else {
            throw CandidateFailure("bad_url")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch let error as URLError where error.code != .cancelled {
            throw CandidateFailure("network_\(error.code.rawValue)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw CandidateFailure("bad_response")
        }
        if http.statusCode == 429 {
            throw RouteError.throttled(waitSeconds: 60)
        }
        // Mapbox puts a short reason in "code" (NoSegment, NoRoute,
        // InvalidInput, ...) — that's what tells a bad start point from a
        // bad request.
        let code = (try? JSONDecoder().decode(MapboxStatus.self, from: data))?.code
        guard http.statusCode == 200 else {
            throw CandidateFailure("http_\(http.statusCode)" + (code.map { "_\($0)" } ?? ""))
        }
        guard let decoded = try? JSONDecoder().decode(MapboxDirectionsResponse.self, from: data) else {
            throw CandidateFailure("decode" + (code.map { "_\($0)" } ?? ""))
        }
        guard let route = decoded.routes?.first else {
            throw CandidateFailure("no_route" + (code.map { "_\($0)" } ?? ""))
        }
        return route
    }

    /// One short, low-cardinality label per failed candidate for analytics.
    private static func failureKind(of error: Error) -> String {
        if let failure = error as? CandidateFailure { return failure.kind }
        if case RouteError.throttled = error { return "http_429" }
        if let urlError = error as? URLError { return "network_\(urlError.code.rawValue)" }
        return "other"
    }

    // MARK: - Helpers

    /// The route limit is part of the key so a set generated at the free tier
    /// (2 routes) is not handed back to a Premium request (8 routes) after an
    /// upgrade in the same session.
    private func cacheKey(for start: CLLocationCoordinate2D, minutes: Int, speedKmH: Double, maxRoutes: Int) -> String {
        "mapbox_\(Int(start.latitude * 1000)),\(Int(start.longitude * 1000)),\(minutes),\(Int(speedKmH * 10)),max\(maxRoutes)"
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
    let routes: [MapboxRoute]?
}

private struct MapboxStatus: Codable {
    let code: String?
}

/// Why one candidate loop was dropped; `kind` goes into analytics.
private struct CandidateFailure: Error {
    let kind: String
    init(_ kind: String) { self.kind = kind }
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
    /// Street name for the step, empty when unnamed.
    let name: String?
    /// Transport mode for this step: "walking", "ferry", "cycling", etc.
    let mode: String?
}

private struct MapboxManeuver: Codable {
    let instruction: String
    let location: [Double]
    let type: String?
    let modifier: String?
}
