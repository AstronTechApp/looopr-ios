import Foundation
import SwiftUI

@MainActor @Observable
final class SavedRoutesViewModel {

    // MARK: - State

    private(set) var savedRoutes: [Route] = []
    private(set) var isLoading = false

    // Share state
    private(set) var isSharing = false
    private(set) var shareURL: URL?
    private(set) var shareError: String?

    // Pending deletion (used to drive the confirmation alert)
    var routePendingDeletion: Route?

    // MARK: - Dependencies

    private let routeRepository: RouteRepository
    private let routeShareService: RouteShareService
    private let logger = AppLogger(category: "SavedRoutes")

    init(
        routeRepository: RouteRepository = ServiceContainer.shared.resolve(RouteRepository.self),
        routeShareService: RouteShareService? = nil
    ) {
        self.routeRepository = routeRepository
        self.routeShareService = routeShareService
            ?? ServiceContainer.shared.resolveOptional(RouteShareService.self)
            ?? RouteShareService()
    }

    // MARK: - Load

    /// Loads saved routes from the repository. Idempotent — safe to call from
    /// `.onAppear` and pull-to-refresh.
    func load() {
        isLoading = true
        defer { isLoading = false }

        do {
            savedRoutes = try routeRepository.loadSavedRoutes()
        } catch {
            logger.error("Failed to load saved routes: \(error)")
            savedRoutes = []
        }
    }

    // MARK: - Remove

    /// Removes a route from the saved list and refreshes local state.
    func remove(_ route: Route) {
        do {
            try routeRepository.removeSavedRoute(route.id)
            savedRoutes.removeAll { $0.id == route.id }
            logger.info("Removed saved route: \(route.id)")
        } catch {
            logger.error("Failed to remove saved route: \(error)")
        }
    }

    /// Removes the route staged in `routePendingDeletion`, if any.
    func confirmPendingDeletion() {
        guard let route = routePendingDeletion else { return }
        remove(route)
        routePendingDeletion = nil
    }

    // MARK: - Share

    /// Uploads a saved route and returns a shareable URL, or nil on failure.
    func shareRoute(_ route: Route) async -> URL? {
        isSharing = true
        shareError = nil
        defer { isSharing = false }

        do {
            let url = try await routeShareService.uploadRoute(route)
            shareURL = url
            return url
        } catch {
            shareError = error.localizedDescription
            logger.error("Failed to share route: \(error)")
            return nil
        }
    }

    // MARK: - Derived

    var isEmpty: Bool {
        !isLoading && savedRoutes.isEmpty
    }
}
