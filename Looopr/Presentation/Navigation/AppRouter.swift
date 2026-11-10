import SwiftUI

@MainActor
@Observable
final class AppRouter {
    var path = NavigationPath() {
        didSet {
            // A swipe-back or system back button shortens `path` through the
            // NavigationStack binding without going through pop(). Trim the
            // shadow stack to match, so `routeStack.last` is always the
            // screen actually on top.
            if routeStack.count > path.count {
                routeStack.removeLast(routeStack.count - path.count)
            }
        }
    }
    var presentedSheet: AppRoute?

    /// The paywall is presented as a full-screen cover, never pushed.
    /// RevenueCat's paywall is designed edge-to-edge with its own close
    /// button; pushing it left a back chevron, a safe-area gap above the
    /// hero and the tab bar overlapping the footer links.
    var isPaywallPresented = false
    /// What opened the paywall, for the `paywall_shown` / `paywall_dismissed`
    /// events, so the funnel shows which entry point sells.
    private(set) var paywallSource: PaywallSource = .settings

    func presentPaywall(source: PaywallSource) {
        paywallSource = source
        isPaywallPresented = true
    }

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
        // A second tap on the same button before the push animation ends
        // used to stack an identical screen (and, for route search, start a
        // second paid search). Pushing the screen that is already on top is
        // never intended.
        if routeStack.last == route { return }
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

    /// Swaps the top of the stack for `route` without a visible pop — used
    /// to re-run a route search with a different duration from the empty
    /// state.
    func replaceTop(with route: AppRoute) {
        if case .routeSelection(let minutes, let location) = route {
            lastExploreMinutes = minutes
            lastExploreLocation = location
        }
        // Removing from `path` trims `routeStack` too (see didSet).
        if !path.isEmpty { path.removeLast() }
        path.append(route)
        routeStack.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast() // trims routeStack too (see didSet)
    }

    func popToRoot() {
        path = NavigationPath()
        routeStack.removeAll()
    }
}
