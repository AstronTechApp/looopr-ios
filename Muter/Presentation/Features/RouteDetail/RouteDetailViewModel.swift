import CoreLocation
import SwiftUI

@MainActor
@Observable
final class RouteDetailViewModel {
    private(set) var route: Route
    private(set) var isLoadingPOIs = false

    private let poiAggregator: POIAggregatorService
    private let configuration: AppConfiguration
    private let logger = AppLogger(category: "RouteDetail")

    init(
        route: Route,
        poiAggregator: POIAggregatorService? = nil,
        configuration: AppConfiguration = .current
    ) {
        self.route = route
        self.poiAggregator = poiAggregator ?? POIAggregatorService(configuration: configuration)
        self.configuration = configuration
    }

    var attractions: [POI] { route.attractions }
    var foodSpots: [POI] { route.foodSpots }
    var hasLoadedPOIs: Bool { !route.pois.isEmpty }

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
            logger.info("Loaded \(pois.count) POIs for route \(route.name)")
        }
    }
}
