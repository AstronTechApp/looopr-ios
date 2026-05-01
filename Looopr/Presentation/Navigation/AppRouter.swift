import SwiftUI

@MainActor
@Observable
final class AppRouter {
    var path = NavigationPath()
    var presentedSheet: AppRoute?

    /// Tracks pushed routes so we can inspect the stack (NavigationPath is type-erased).
    private(set) var routeStack: [AppRoute] = []

    /// Remembers the last route-selection parameters so switching tabs can restore them.
    var lastExploreMinutes: Int = 30
    var lastExploreLocation: CustomRouteLocation?

    var isInFullScreenFlow: Bool {
        guard let last = routeStack.last else { return false }
        switch last {
        case .walkNavigation, .finishWalk:
            return true
        default:
            return false
        }
    }

    /// Returns true when a RouteSelectionView is anywhere on the navigation stack.
    var isOnRouteSelection: Bool {
        routeStack.contains { route in
            if case .routeSelection = route { return true }
            return false
        }
    }

    /// Returns the walk duration of the current RouteSelection route, if on that screen.
    var currentRouteSelectionMinutes: Int? {
        for route in routeStack.reversed() {
            if case .routeSelection(let minutes, _) = route {
                return minutes
            }
        }
        return nil
    }

    func navigate(to route: AppRoute) {
        // Remember explore parameters for tab restoration
        if case .routeSelection(let minutes, let location) = route {
            lastExploreMinutes = minutes
            lastExploreLocation = location
        }
        path.append(route)
        routeStack.append(route)
    }

    func present(_ route: AppRoute) {
        presentedSheet = route
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
        if !routeStack.isEmpty {
            routeStack.removeLast()
        }
    }

    func popToRoot() {
        path = NavigationPath()
        routeStack.removeAll()
    }
}
