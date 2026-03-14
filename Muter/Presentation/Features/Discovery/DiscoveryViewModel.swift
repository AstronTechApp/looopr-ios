import CoreLocation
import Combine
import SwiftUI

struct SearchedLocation: Hashable {
    let name: String
    let coordinate: CLLocationCoordinate2D
}

@MainActor
@Observable
final class DiscoveryViewModel {
    // MARK: - Published State

    private(set) var routes: [Route] = []
    private(set) var loadingState: LoadingState = .idle
    var selectedTimeMinutes: Int = 60
    var customLocation: SearchedLocation?
    var showLocationSearch = false

    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
        case throttled(retryAfterSeconds: Int)
    }

    // MARK: - Dependencies

    private let routeGeneration: RouteGenerating
    private let locationService: LocationProviding
    private let configuration: AppConfiguration
    private let logger = AppLogger(category: "Discovery")

    // MARK: - Task Management

    private var debounceTask: Task<Void, Never>?
    private var generationTask: Task<Void, Never>?
    private var locationCancellable: AnyCancellable?

    var locationDescription: String {
        if let custom = customLocation {
            return custom.name
        }
        if locationService.isAuthorized {
            return "Current Location"
        }
        return "Location unavailable"
    }

    var hasLocation: Bool {
        customLocation != nil || (locationService.isAuthorized && locationService.currentCoordinate != nil)
    }

    // MARK: - Init

    init(
        routeGeneration: RouteGenerating? = nil,
        locationService: LocationProviding? = nil,
        configuration: AppConfiguration = .current
    ) {
        self.routeGeneration = routeGeneration ?? ServiceContainer.shared.resolve(RouteGenerating.self)
        self.locationService = locationService ?? ServiceContainer.shared.resolve(LocationProviding.self)
        self.configuration = configuration
    }

    // MARK: - Lifecycle

    func onAppear() {
        locationService.requestAuthorization()
        locationService.startUpdating()

        locationCancellable = locationService.authorizationPublisher
            .sink { [weak self] _ in
                guard let self else { return }
                if self.routes.isEmpty && self.hasLocation {
                    self.generateRoutes()
                }
            }
    }

    // MARK: - Route Generation

    func generateRoutes() {
        debounceTask?.cancel()
        generationTask?.cancel()

        guard let start = resolveStartLocation() else {
            loadingState = .error("Enable location services or search for a location to get started.")
            return
        }

        loadingState = .loading

        debounceTask = Task { [weak self, minutes = selectedTimeMinutes] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(self.configuration.generation.debounceSeconds))
            guard !Task.isCancelled else { return }
            await self.performGeneration(start: start, minutes: minutes)
        }
    }

    func timeChanged() {
        generateRoutes()
    }

    func setCustomLocation(_ location: SearchedLocation) {
        customLocation = location
        generateRoutes()
    }

    func clearCustomLocation() {
        customLocation = nil
        generateRoutes()
    }

    // MARK: - Private

    private func performGeneration(start: CLLocationCoordinate2D, minutes: Int) {
        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let newRoutes = try await self.routeGeneration.generateLoopRoutes(
                    start: start,
                    minutes: minutes
                )
                guard !Task.isCancelled else { return }
                self.routes = newRoutes
                self.loadingState = .loaded
                self.logger.info("Loaded \(newRoutes.count) routes")
            } catch is CancellationError {
                self.logger.debug("Generation cancelled")
            } catch let error as RouteError {
                guard !Task.isCancelled else { return }
                switch error {
                case .throttled(let wait):
                    self.loadingState = .throttled(retryAfterSeconds: Int(wait))
                    try? await Task.sleep(for: .seconds(wait + 2))
                    guard !Task.isCancelled else { return }
                    await self.performGeneration(start: start, minutes: minutes)
                default:
                    self.loadingState = .error(error.userFacingMessage)
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.loadingState = .error("Something went wrong. Please try again.")
                self.logger.error("Generation failed: \(error.localizedDescription)")
            }
        }
    }

    private func resolveStartLocation() -> CLLocationCoordinate2D? {
        if let custom = customLocation {
            return custom.coordinate
        }
        guard locationService.isAuthorized else { return nil }
        return locationService.currentCoordinate
    }
}
