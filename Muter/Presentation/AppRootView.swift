import SwiftUI

struct AppRootView: View {
    @State private var router = AppRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            DiscoveryView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .discovery:
                        DiscoveryView()
                    case .routeDetail(let route):
                        RouteDetailView(route: route)
                    case .walkNavigation(let route):
                        Text("Walking: \(route.name)") // Sprint 4
                    case .finishWalk(let session):
                        Text("Finished! \(session.durationMinutes) min") // Sprint 5
                    case .locationSearch:
                        Text("Search Location") // Sprint 2
                    case .settings:
                        Text("Settings") // Sprint 8
                    case .paywall:
                        Text("Upgrade to Premium") // Sprint 7
                    }
                }
        }
        .environment(router)
    }
}
