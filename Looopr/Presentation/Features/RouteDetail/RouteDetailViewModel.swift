import CoreLocation
import SwiftUI

/// Minimum distance between POI map annotations in metres.
/// Prevents visual bunching on the map without affecting the POI list.
private let minimumAnnotationSpacingMetres: Double = 200

/// Minimum distance between Food & Drink map annotations in metres.
/// Slightly wider than general POI spacing because restaurant-dense
/// urban areas can otherwise still produce visual clusters.
private let minimumFoodAnnotationSpacingMetres: Double = 250

@MainActor
@Observable
final class RouteDetailViewModel {
    private(set) var route: Route
    private(set) var isLoadingPOIs = false
    private(set) var hasCompletedInitialPOILoad = false
    private(set) var isLoadingFood = false
    private(set) var hasFetchedFood = false
    private(set) var addedFoodStops: Set<UUID> = []
    private(set) var isSaved = false
    private(set) var isSharing = false
    private(set) var shareURL: URL?
    private(set) var plannedDepartureDate: Date?

    private let poiAggregator: POIAggregatorService
    private let foodService: GooglePlacesNewFoodService?
    private let routeRepository: RouteRepository
    private let routeShareService: RouteShareService?
    private let configuration: AppConfiguration
    private let logger = AppLogger(category: "RouteDetail")

    init(
        route: Route,
        poiAggregator: POIAggregatorService? = nil,
        foodService: GooglePlacesNewFoodService? = nil,
        routeRepository: RouteRepository? = nil,
        routeShareService: RouteShareService? = nil,
        configuration: AppConfiguration = .current
    ) {
        self.route = route
        self.poiAggregator = poiAggregator ?? POIAggregatorService(configuration: configuration)
        self.foodService = foodService ?? ServiceContainer.shared.resolveOptional(GooglePlacesNewFoodService.self)
        self.routeRepository = routeRepository ?? ServiceContainer.shared.resolve(RouteRepository.self)
        self.routeShareService = routeShareService ?? ServiceContainer.shared.resolveOptional(RouteShareService.self)
        self.configuration = configuration
        self.isSaved = self.routeRepository.isRouteSaved(route.id)
    }

    // MARK: - POI Categories

    /// All attractions (for map annotations)
    var attractions: [POI] { route.attractions.filter(isVisibleAtPlannedDeparture) }
    /// All food spots (for map annotations)
    var foodSpots: [POI] { route.foodSpots.filter(isVisibleAtPlannedDeparture) }

    /// Attractions directly along the walking path (<=100m)
    var onRouteAttractions: [POI] { route.onRouteAttractions.filter(isVisibleAtPlannedDeparture) }
    /// Attractions near the route, short detour (100-500m)
    var nearRouteAttractions: [POI] { route.nearRouteAttractions.filter(isVisibleAtPlannedDeparture) }
    /// Cafes & Restaurants (within 100m, 4.4+ rating)
    var cafesAndRestaurants: [POI] { route.foodSpots.filter(isVisibleAtPlannedDeparture) }

    var hasLoadedPOIs: Bool { !route.pois.isEmpty }
    var hasPOIs: Bool { !attractions.isEmpty || !foodSpots.isEmpty }

    var effectiveDepartureDate: Date {
        plannedDepartureDate ?? Date()
    }

    var leavingTimeValueLabel: String {
        guard let plannedDepartureDate else { return L10n.Misc.now }
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.currentLocale
        formatter.setLocalizedDateFormatFromTemplate("EEE HH:mm")
        return formatter.string(from: plannedDepartureDate)
    }

    func setLeavingTime(_ date: Date) {
        plannedDepartureDate = date
        logger.info("Leaving time set to \(date)")
    }

    func setLeavingNow() {
        plannedDepartureDate = nil
        logger.info("Leaving time reset to now")
    }

    // MARK: - Distributed Map Annotations

    /// On-route attractions sorted by route position and spaced for the map.
    var distributedOnRouteAnnotations: [POI] {
        let sorted = sortedByRoutePosition(pois: onRouteAttractions)
        return distributedAnnotations(from: sorted)
    }

    /// Near-route attractions sorted by route position and spaced for the map.
    var distributedNearRouteAnnotations: [POI] {
        let sorted = sortedByRoutePosition(pois: nearRouteAttractions)
        return distributedAnnotations(from: sorted)
    }

    /// Food spots sorted by route position and spaced for the map.
    /// Uses wider spacing than general POIs to prevent clustering in
    /// restaurant-dense urban sections.
    var distributedFoodAnnotations: [POI] {
        let sorted = sortedByRoutePosition(pois: foodSpots)
        return distributedAnnotations(from: sorted, minimumSpacing: minimumFoodAnnotationSpacingMetres)
    }

    // MARK: - Save & Share

    func toggleSave() {
        do {
            if isSaved {
                try routeRepository.removeSavedRoute(route.id)
                logger.info("Removed saved route: \(route.name)")
            } else {
                try routeRepository.saveRoute(route)
                // Verify save persisted by reading back
                let verified = routeRepository.isRouteSaved(route.id)
                logger.info("Saved route: \(route.name) (verified: \(verified))")
            }
            isSaved.toggle()
        } catch {
            logger.error("Failed to toggle save: \(error.localizedDescription)")
        }
    }

    func shareRoute() async -> URL? {
        guard let service = routeShareService else { return nil }
        isSharing = true
        defer { isSharing = false }

        do {
            let url = try await service.uploadRoute(route)
            shareURL = url
            return url
        } catch {
            logger.error("Failed to share route: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Food Waypoints

    /// Minimum distance between food stops before showing a proximity advisory.
    private static let foodStopProximityWarningMetres: Double = 500

    /// Set to true briefly when a food stop is added too close to an existing one.
    private(set) var showFoodProximityWarning = false

    func toggleFoodStop(_ poi: POI) {
        if addedFoodStops.contains(poi.id) {
            addedFoodStops.remove(poi.id)
            showFoodProximityWarning = false
        } else {
            // Advisory: warn if another food stop is nearby
            let isNearExisting = isFoodStopNearExisting(poi)
            addedFoodStops.insert(poi.id)
            if isNearExisting {
                showFoodProximityWarning = true
                // Auto-dismiss after 3 seconds
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    showFoodProximityWarning = false
                }
            }
        }
    }

    func isFoodStopAdded(_ poi: POI) -> Bool {
        addedFoodStops.contains(poi.id)
    }

    /// Returns true if a food stop is within 500m of an already-added stop.
    private func isFoodStopNearExisting(_ newStop: POI) -> Bool {
        let newLocation = CLLocation(
            latitude: newStop.location.clCoordinate.latitude,
            longitude: newStop.location.clCoordinate.longitude
        )
        let existingStops = foodSpots.filter { addedFoodStops.contains($0.id) }
        return existingStops.contains { existing in
            let existingLocation = CLLocation(
                latitude: existing.location.clCoordinate.latitude,
                longitude: existing.location.clCoordinate.longitude
            )
            return newLocation.distance(from: existingLocation) < Self.foodStopProximityWarningMetres
        }
    }

    /// Route passed to navigation -- always contains only attractions + explicitly added food stops.
    /// Non-added food POIs are stripped out so they never appear as green markers during the walk.
    var routeWithAddedStops: Route {
        let addedFood = route.foodSpots.filter {
            addedFoodStops.contains($0.id) && isVisibleAtPlannedDeparture($0)
        }
        let combined = route.attractions.filter(isVisibleAtPlannedDeparture) + addedFood
        return route.withPOIs(combined)
    }

    func loadPOIsIfNeeded() {
        guard route.pois.isEmpty, !isLoadingPOIs else { return }
        isLoadingPOIs = true

        Task {
            let pois = await poiAggregator.fetchPOIs(
                nearPolyline: route.pathCoordinates,
                maxDistance: configuration.poi.maxDistanceFromRouteMeters,
                limit: configuration.poi.maxPOIsPerRoute
            )
            route = route.withPOIs(pois)
            isLoadingPOIs = false
            hasCompletedInitialPOILoad = true
            logger.info("Loaded \(pois.count) POIs for route \(route.name) (\(route.onRouteAttractions.count) on-route, \(route.nearRouteAttractions.count) near-route)")
        }
    }

    /// Fetch cafes and restaurants on-demand via Google Places (New) API.
    /// Called when the user taps the "Food & Drinks" tab — NOT during initial load.
    func loadFoodIfNeeded() {
        guard !hasFetchedFood, !isLoadingFood else { return }
        guard let foodService else {
            logger.warning("Food service unavailable — Google Places API key missing?")
            hasFetchedFood = true
            return
        }

        isLoadingFood = true

        Task {
            let foodPOIs = await foodService.fetchFoodPOIs(
                nearPolyline: route.pathCoordinates,
                departureDate: plannedDepartureDate
            )

            // Merge food POIs into the existing route (attractions + new food)
            let existingAttractions = route.attractions
            let combined = existingAttractions + foodPOIs
            route = route.withPOIs(combined)

            hasFetchedFood = true
            isLoadingFood = false
            logger.info("Loaded \(foodPOIs.count) food POIs via Google Places (New) for route \(route.name)")
        }
    }

    // MARK: - Route Position Sorting

    /// Sorts POIs by their position along the route polyline (start to end).
    /// This distributes markers naturally from the beginning to the end of the walk
    /// instead of bunching them near the start/user location.
    private func sortedByRoutePosition(pois: [POI]) -> [POI] {
        let waypoints = route.pathCoordinates
        guard !waypoints.isEmpty else { return pois }

        return pois.sorted { a, b in
            let aIndex = nearestWaypointIndex(for: a.location.clCoordinate, in: waypoints)
            let bIndex = nearestWaypointIndex(for: b.location.clCoordinate, in: waypoints)
            return aIndex < bIndex
        }
    }

    private func isVisibleAtPlannedDeparture(_ poi: POI) -> Bool {
        poi.openStatus(at: plannedDepartureDate) != .closed
    }

    /// Finds the index of the nearest waypoint in the route polyline to a given coordinate.
    private func nearestWaypointIndex(
        for coordinate: CLLocationCoordinate2D,
        in waypoints: [CLLocationCoordinate2D]
    ) -> Int {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var minDistance = Double.infinity
        var nearestIndex = 0

        for (index, waypoint) in waypoints.enumerated() {
            let waypointLocation = CLLocation(latitude: waypoint.latitude, longitude: waypoint.longitude)
            let distance = location.distance(from: waypointLocation)
            if distance < minDistance {
                minDistance = distance
                nearestIndex = index
            }
        }
        return nearestIndex
    }

    // MARK: - Annotation Distribution

    /// Filters POIs to maintain a minimum spacing between map annotations.
    /// This prevents visual bunching on the map. The full list is still shown
    /// in the POI list tabs below the map.
    private func distributedAnnotations(
        from pois: [POI],
        minimumSpacing: Double = minimumAnnotationSpacingMetres
    ) -> [POI] {
        var selected: [POI] = []
        var lastSelectedLocation: CLLocation?

        for poi in pois {
            let poiLocation = CLLocation(
                latitude: poi.location.clCoordinate.latitude,
                longitude: poi.location.clCoordinate.longitude
            )

            if let last = lastSelectedLocation {
                let distance = poiLocation.distance(from: last)
                if distance < minimumSpacing {
                    continue
                }
            }

            selected.append(poi)
            lastSelectedLocation = poiLocation
        }

        return selected
    }
}
