import CoreLocation
import SwiftUI

@MainActor @Observable
final class RouteSelectionViewModel {

    // MARK: - State

    private(set) var routes: [Route] = []
    private(set) var isLoading = true
    /// Why the last search ended without routes. Nil while loading, after a
    /// successful search, and when the search was merely cancelled (the
    /// view went away) — a cancelled search is not a failed one.
    private(set) var failure: SearchFailure?

    enum SearchFailure: Equatable {
        /// The generator finished (or threw `RouteError.noRoutesFound`)
        /// without a single loop of this length from this start.
        case noRoutes
        /// No GPS fix within the wait window.
        case locationUnavailable
        /// Network / directions / anything else.
        case generation(String)

        /// Short machine-readable reason for analytics.
        var analyticsReason: String {
            switch self {
            case .noRoutes: return "no_routes"
            case .locationUnavailable: return "location_unavailable"
            case .generation: return "generation_error"
            }
        }
    }

    /// True only when a search finished and produced routes. The free-tier
    /// upgrade card hangs off this, never off "not loading" — a failed or
    /// empty search must not end in a paywall.
    var didFindRoutes: Bool { !isLoading && failure == nil && !routes.isEmpty }

    /// A longer duration to offer when the short end comes up empty, or nil
    /// at the top of the slider.
    var suggestedLongerMinutes: Int? {
        let longer = walkDurationMinutes + Self.longerWalkStepMinutes
        return longer <= Self.maxWalkMinutes ? longer : nil
    }
    static let longerWalkStepMinutes = 15
    static let maxWalkMinutes = 180

    /// The location the search ran from, so a retry with another duration
    /// can keep it.
    var searchLocation: CustomRouteLocation? { customLocation }

    /// How long `loadRoutes` waits for a first GPS fix before giving up.
    var locationWaitSeconds: TimeInterval = 15

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
            return L10n.RouteSelection.subtitleFinding(Self.formattedMinutes(walkDurationMinutes))
        }
        return L10n.RouteSelection.subtitleFound(count: routes.count, duration: Self.formattedMinutes(walkDurationMinutes))
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
    private let analytics: AnalyticsTracking
    private let logger = AppLogger(category: "RouteSelection")

    /// Mapbox for every tier — the free/paid line is how many routes you
    /// see, not which engine draws them. A Mapbox search costs roughly a
    /// cent, so giving free users the good generator is cheap; the
    /// MKDirections loop builder is now only a fallback when no Mapbox
    /// token is configured.
    private var activeRouteService: RouteGenerating {
        if let mapbox = mapboxGeneration { return mapbox }
        return routeGeneration
    }

    /// True when the free-tier limit applies. While the paywall master switch
    /// is off every user is treated as paid, so this is false pre-launch.
    var isFreeTier: Bool { !subscriptionService.isPaidSubscriber }

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
        analytics: AnalyticsTracking? = nil,
        configuration: AppConfiguration = .current
    ) {
        self.walkDurationMinutes = walkDurationMinutes
        self.customLocation      = customLocation
        self.routeGeneration     = routeGeneration     ?? ServiceContainer.shared.resolve(RouteGenerating.self)
        // An explicitly injected generator is the one to use (tests, previews);
        // only fall back to the container's Mapbox service when nothing was given.
        self.mapboxGeneration    = mapboxGeneration
            ?? (routeGeneration == nil ? ServiceContainer.shared.resolveOptional(MapboxRouteGenerationService.self) : nil)
        self.subscriptionService = subscriptionService  ?? ServiceContainer.shared.resolve(SubscriptionProviding.self)
        self.locationService     = locationService      ?? ServiceContainer.shared.resolve(LocationProviding.self)
        self.analytics           = analytics            ?? ServiceContainer.shared.resolve(AnalyticsTracking.self)
        self.configuration       = configuration
    }

    // MARK: - Loading

    func loadRoutes() async {
        isLoading = true
        failure = nil
        analytics.track(.routeSearchStarted(
            minutes: walkDurationMinutes,
            usingCustomLocation: customLocation != nil
        ))

        // Use custom location if provided, otherwise wait for GPS
        if let custom = customLocation {
            logger.info("Using custom location: \(custom.displayName)")
            await generateRoutes(from: custom.coordinate)
            return
        }

        // Ensure location services are active
        locationService.requestAuthorization()
        locationService.startUpdating()

        // Wait up to `locationWaitSeconds` for a location fix
        var coordinate = locationService.currentCoordinate
        if coordinate == nil {
            let polls = max(1, Int(locationWaitSeconds / 0.5))
            for _ in 0..<polls {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(500))
                coordinate = locationService.currentCoordinate
                if coordinate != nil { break }
            }
        }

        guard let coordinate else {
            if Task.isCancelled { return }
            logger.error("Timed out waiting for location")
            fail(.locationUnavailable)
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
            // A cancelled generator ends its stream quietly, so a torn-down
            // view used to log "0 routes" here and skew the failure stats.
            // Leave the state as it is; nobody is looking at it any more.
            if Task.isCancelled { return }
            logger.info("Loaded \(collected.count) routes for \(walkDurationMinutes) min walk")
            analytics.track(.routeGenerated(count: collected.count, minutes: walkDurationMinutes))
            if collected.isEmpty {
                fail(.noRoutes)
                return
            }
        } catch is CancellationError {
            return
        } catch {
            if Task.isCancelled { return }
            logger.error("Route generation failed: \(error)")
            routes = []
            if let routeError = error as? RouteError, routeError == .noRoutesFound {
                fail(.noRoutes)
            } else if let routeError = error as? RouteError, routeError == .cancelled {
                // Generator-level cancellation (e.g. superseded request).
            } else {
                fail(.generation(String(describing: error)))
            }
            return
        }
        isLoading = false
    }

    private func fail(_ reason: SearchFailure) {
        failure = reason
        isLoading = false
        analytics.track(.routeSearchFailed(minutes: walkDurationMinutes, reason: reason.analyticsReason))
    }
}
