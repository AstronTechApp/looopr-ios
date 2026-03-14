import SwiftUI

@MainActor
@Observable
final class AppRouter {
    var path = NavigationPath()
    var presentedSheet: AppRoute?

    func navigate(to route: AppRoute) {
        path.append(route)
    }

    func present(_ route: AppRoute) {
        presentedSheet = route
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
