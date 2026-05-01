import CoreLocation
import SwiftUI

@MainActor @Observable
final class RouteSelectionViewModel {

    // MARK: - State

    private(set) var routes: [Route] = []
    private(set) var isLoading = true

    // TODO: v2 — Route filter tabs (Quiet, Parks, Scenic, Cafés)
    // Restore when route generation tags routes by character type
    //
    // enum RouteFilter: String, CaseIterable {
    //     case all     = "All"
    //     case quiet   = "Quiet"
    //     case parks   = "Parks"
    //     case scenic  = "Scenic"
    //     case cafes   = "Cafés"
    // }
    //
    // var selectedFilter: RouteFilter = .all
    //
    // var filteredRoutes: [Route] {
    //     switch selectedFilter {
    //     case .all:    return routes
    //     case .quiet:  return routes.filter { $0.difficulty == .easy }
    //     case .parks:  return routes.filter { $0.pois.contains { $0.category.isTouristAttraction } }
    //     case .scenic: return routes.filter { $0.difficulty == .moderate || $0.difficulty == .challenging }
    //     case .cafes:  return routes.filter { $0.pois.contains { $0.category.isFood } }
    //     }
    // }

    // MARK: - Display helpers

    let walkDurationMinutes: Int

    var subtitle: String {
        if isLoading {
            return "Finding routes · \(Self.formattedMinutes(walkDurationMinutes)) walk"
        }
        return "\(routes.count) route\(routes.count == 1 ? "" : "s") found · \(Self.formattedMinutes(walkDurationMinutes)) walk"
    }

    /// Formatted duration string from raw minutes (e.g. "30min", "1h 30min").
    static func formattedMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)min"
        }
        let hours = minutes / 60
        let rem = minutes % 60
        return rem == 0 ? "\(hours)h" : "\(hours)h \(rem)min"
    }

    /// Approximate elevation from difficulty (Route model has no elevation field)
    static func estimatedElevation(for route: Route) -> Int {
        switch route.difficulty {
        case .easy:        return Int(route.distanceKilometers * 8)
        case .moderate:    return Int(route.distanceKilometers * 18)
        case .challenging: return Int(route.distanceKilometers * 30)
        }
    }

    // MARK: - Dependencies

    private let routeGeneration: RouteGenerating
    private let mapboxGeneration: MapboxRouteGenerationService?
    private let subscriptionService: SubscriptionProviding
    private let locationService: LocationProviding
    private let configuration: AppConfiguration
    private let logger = AppLogger(category: "RouteSelection")

    private var activeRouteService: RouteGenerating {
        if subscriptionService.isPaidSubscriber, let mapbox = mapboxGeneration {
            return mapbox
        }
        return routeGeneration
    }

    private var maxRoutes: Int {
        subscriptionService.isPaidSubscriber
            ? configuration.freemium.paidRouteLimit
            : configuration.freemium.freeRouteLimit
    }

    /// Optional custom location override (from location search on home screen).
    /// When nil, the device's current GPS location is used.
    private let customLocation: CustomRouteLocation?

    // MARK: - Init

    init(
        walkDurationMinutes: Int = 30,
        customLocation: CustomRouteLocation? = nil,
        routeGeneration: RouteGenerating? = nil,
        mapboxGeneration: MapboxRouteGenerationService? = nil,
        subscriptionService: SubscriptionProviding? = nil,
        locationService: LocationProviding? = nil,
        configuration: AppConfiguration = .current
    ) {
        self.walkDurationMinutes = walkDurationMinutes
        self.customLocation      = customLocation
        self.routeGeneration     = routeGeneration     ?? ServiceContainer.shared.resolve(RouteGenerating.self)
        self.mapboxGeneration    = mapboxGeneration     ?? ServiceContainer.shared.resolveOptional(MapboxRouteGenerationService.self)
        self.subscriptionService = subscriptionService  ?? ServiceContainer.shared.resolve(SubscriptionProviding.self)
        self.locationService     = locationService      ?? ServiceContainer.shared.resolve(LocationProviding.self)
        self.configuration       = configuration
    }

    // MARK: - Loading

    func loadRoutes() async {
        isLoading = true

        // Use custom location if provided, otherwise wait for GPS
        if let custom = customLocation {
            logger.info("Using custom location: \(custom.displayName)")
            await generateRoutes(from: custom.coordinate)
            return
        }

        // Ensure location services are active
        locationService.requestAuthorization()
        locationService.startUpdating()

        // Wait up to 15 seconds for a location fix
        var coordinate = locationService.currentCoordinate
        if coordinate == nil {
            for _ in 0..<30 {
                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }
                try? await Task.sleep(for: .milliseconds(500))
                coordinate = locationService.currentCoordinate
                if coordinate != nil { break }
            }
        }

        guard let coordinate else {
            logger.error("Timed out waiting for location")
            isLoading = false
            return
        }

        await generateRoutes(from: coordinate)
    }

    private func generateRoutes(from coordinate: CLLocationCoordinate2D) async {
        do {
            let walkingSpeedKmH = SettingsManager.shared.walkingPace.kilometresPerHour
            let stream = activeRouteService.generateLoopRoutesStream(
                start: coordinate,
                minutes: walkDurationMinutes,
                maxRoutes: maxRoutes,
                walkingSpeedKmH: walkingSpeedKmH
            )
            var collected: [Route] = []
            for try await route in stream {
                collected.append(route)
                collected.sort { $0.durationMinutes < $1.durationMinutes }
                routes = collected
            }
            logger.info("Loaded \(collected.count) routes for \(walkDurationMinutes) min walk")
        } catch {
            logger.error("Route generation failed: \(error)")
        }
        isLoading = false
    }
}
