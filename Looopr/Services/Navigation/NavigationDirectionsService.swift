import CoreLocation
import MapKit

actor LiveNavigationDirectionsService: NavigationDirecting {
    private let logger = AppLogger(category: "Navigation")
    private let cache = CacheManager<UUID, [NavigationStep]>(ttl: 600)

    func computeSteps(for route: Route) async throws -> [NavigationStep] {
        // Return cached steps if route already has them
        if let steps = route.navigationSteps, !steps.isEmpty {
            return steps
        }

        // Check in-memory cache
        if let cached = await cache.get(route.id) {
            return cached
        }

        let coordinates = route.pathCoordinates
        guard coordinates.count >= 2 else {
            throw NavigationError.stepsUnavailable
        }

        // Simplify waypoints for MKDirections (max 10 intermediate waypoints)
        let simplified = simplifyWaypoints(coordinates, maxCount: 12)

        var allSteps: [NavigationStep] = []

        // Compute directions leg by leg
        let totalLegs = simplified.count - 1
        for i in 0..<totalLegs {
            let source = MKMapItem(placemark: MKPlacemark(coordinate: simplified[i]))
            let destination = MKMapItem(placemark: MKPlacemark(coordinate: simplified[i + 1]))

            let request = MKDirections.Request()
            request.source = source
            request.destination = destination
            request.transportType = .walking

            let directions = MKDirections(request: request)
            let response = try await directions.calculate()

            guard let mkRoute = response.routes.first else { continue }

            let isLastLeg = (i == totalLegs - 1)

            for step in mkRoute.steps where !step.instructions.isEmpty {
                // Filter out intermediate arrival messages — MKDirections artefacts.
                if !isLastLeg && isArrivalStep(step.instructions) { continue }

                let navStep = NavigationStep(
                    instruction: step.instructions,
                    distanceMeters: step.distance,
                    coordinate: step.polyline.coordinate
                )
                allSteps.append(navStep)
            }
        }

        guard !allSteps.isEmpty else {
            throw NavigationError.stepsUnavailable
        }

        await cache.set(route.id, value: allSteps)
        logger.info("Computed \(allSteps.count) navigation steps for route \(route.name)")
        return allSteps
    }

    func computeDetour(
        from current: CLLocationCoordinate2D,
        to target: CLLocationCoordinate2D
    ) async throws -> DetourResult {
        let source = MKMapItem(placemark: MKPlacemark(coordinate: current))
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: target))

        let request = MKDirections.Request()
        request.source = source
        request.destination = destination
        request.transportType = .walking

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let mkRoute = response.routes.first else {
            throw NavigationError.rerouteFailed
        }

        let steps = mkRoute.steps.compactMap { step -> NavigationStep? in
            guard !step.instructions.isEmpty else { return nil }
            return NavigationStep(
                instruction: step.instructions,
                distanceMeters: step.distance,
                coordinate: step.polyline.coordinate
            )
        }

        let polylineCoords = mkRoute.polyline.coordinates
        logger.info("Computed detour with \(steps.count) steps")

        return DetourResult(steps: steps, polylineCoordinates: polylineCoords)
    }

    func computeStepsAlongPath(
        _ coordinates: [CLLocationCoordinate2D]
    ) async throws -> RerouteResult {
        guard coordinates.count >= 2 else {
            throw NavigationError.stepsUnavailable
        }

        let simplified = simplifyWaypoints(coordinates, maxCount: 12)

        var allSteps: [NavigationStep] = []
        var allPolylineCoords: [CLLocationCoordinate2D] = []

        let totalLegs = simplified.count - 1
        for i in 0..<totalLegs {
            let source = MKMapItem(placemark: MKPlacemark(coordinate: simplified[i]))
            let destination = MKMapItem(placemark: MKPlacemark(coordinate: simplified[i + 1]))

            let request = MKDirections.Request()
            request.source = source
            request.destination = destination
            request.transportType = .walking

            let directions = MKDirections(request: request)
            let response = try await directions.calculate()

            guard let mkRoute = response.routes.first else { continue }

            let isLastLeg = (i == totalLegs - 1)

            for step in mkRoute.steps where !step.instructions.isEmpty {
                if !isLastLeg && isArrivalStep(step.instructions) { continue }
                allSteps.append(NavigationStep(
                    instruction: step.instructions,
                    distanceMeters: step.distance,
                    coordinate: step.polyline.coordinate
                ))
            }

            // Collect polyline — skip first point on subsequent legs to avoid duplicates
            let legCoords = mkRoute.polyline.coordinates
            if allPolylineCoords.isEmpty {
                allPolylineCoords.append(contentsOf: legCoords)
            } else if legCoords.count > 1 {
                allPolylineCoords.append(contentsOf: legCoords.dropFirst())
            }
        }

        guard !allSteps.isEmpty else {
            throw NavigationError.stepsUnavailable
        }

        logger.info("Computed reroute with \(allSteps.count) steps along \(allPolylineCoords.count)-point polyline")
        return RerouteResult(steps: allSteps, polyline: allPolylineCoords)
    }

    // MARK: - Private

    /// Returns true for any step instruction that indicates route arrival —
    /// used to filter mid-route "destination" artefacts from MKDirections.
    private func isArrivalStep(_ instruction: String) -> Bool {
        let lower = instruction.lowercased()
        return lower.contains("destination")
            || lower.contains("arrive")
            || lower.contains("arriving")
            || lower.contains("arrived")
            || lower.contains("you have reached")
            || lower.contains("end of route")
    }

    private func simplifyWaypoints(
        _ coordinates: [CLLocationCoordinate2D],
        maxCount: Int
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxCount else { return coordinates }
        let step = Double(coordinates.count - 1) / Double(maxCount - 1)
        var result: [CLLocationCoordinate2D] = []
        for i in 0..<maxCount {
            let index = min(Int(Double(i) * step), coordinates.count - 1)
            result.append(coordinates[index])
        }
        // Always include last point
        if let last = coordinates.last {
            result[result.count - 1] = last
        }
        return result
    }
}
