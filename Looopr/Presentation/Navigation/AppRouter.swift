import SwiftUI

@MainActor
@Observable
final class AppRouter {
    /// Every tab has its own navigation path (iOS 26 TabView, where each
    /// tab has its own `NavigationStack`). `path` and `routeStack` are those
    /// of `activeTab`, the tab on screen.
    ///
    /// Until 1.5 all four stacks were bound to one shared path. A search
    /// started from Home then also landed in the (hidden) Home stack as a
    /// blank placeholder; hidden stacks don't always follow a pop, so after
    /// a search, going back to Home showed a blank screen with a back button
    /// first (13 Nov). With separate paths a stack only ever holds its own
    /// tab's screens.
    var activeTab: LoooprTab = .home

    private var paths: [LoooprTab: NavigationPath] = [:]
    private var stacks: [LoooprTab: [AppRoute]] = [:]

    /// Bumped whenever Explore's stack is reset for a new search, so its
    /// `NavigationStack` is rebuilt fresh rather than trusted to follow a
    /// change it may have made while hidden.
    private(set) var exploreStackID = 0

    var path: NavigationPath {
        get { path(for: activeTab) }
        set { setPath(newValue, for: activeTab) }
    }

    func path(for tab: LoooprTab) -> NavigationPath {
        paths[tab] ?? NavigationPath()
    }

    /// What a tab's `NavigationStack` writes back (a swipe-back or the
    /// system back button shortens it without going through pop()). The
    /// shadow stack is trimmed to match, so `routeStack.last` is always the
    /// screen actually on top.
    func setPath(_ newPath: NavigationPath, for tab: LoooprTab) {
        paths[tab] = newPath
        var stack = stacks[tab] ?? []
        if stack.count > newPath.count {
            stack.removeLast(stack.count - newPath.count)
            stacks[tab] = stack
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

    /// Pushed routes of the active tab, so the stack can be inspected
    /// (NavigationPath is type-erased).
    var routeStack: [AppRoute] { stacks[activeTab] ?? [] }

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
            // Route search always lives in Explore. Started from another
            // tab, it replaces whatever Explore held (an older search) and
            // Explore becomes the active tab; AppRootView follows.
            if activeTab != .explore {
                paths[.explore] = NavigationPath()
                stacks[.explore] = []
                exploreStackID += 1
                activeTab = .explore
            }
        }
        push(route)
    }

    private func push(_ route: AppRoute) {
        var newPath = path(for: activeTab)
        newPath.append(route)
        paths[activeTab] = newPath
        stacks[activeTab, default: []].append(route)
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
        // Removing from `path` trims `routeStack` too (see setPath).
        if !path.isEmpty { path.removeLast() }
        push(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast() // trims routeStack too (see setPath)
    }

    /// Pops the active tab back to its root screen. Other tabs keep theirs.
    func popToRoot() {
        paths[activeTab] = NavigationPath()
        stacks[activeTab] = []
    }
}
