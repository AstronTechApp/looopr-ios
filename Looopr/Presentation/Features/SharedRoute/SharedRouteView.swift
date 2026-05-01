import SwiftUI

struct SharedRouteView: View {
    let routeID: UUID

    @State private var route: Route?
    @State private var error: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                LoadingStateView(message: "Loading shared route...")
            } else if let route {
                RouteDetailView(route: route)
            } else {
                EmptyStateView(
                    title: "Route Not Found",
                    subtitle: error ?? "This route may have expired or been removed.",
                    systemImage: "map.fill"
                )
            }
        }
        .task {
            await loadRoute()
        }
    }

    private func loadRoute() async {
        guard let service = ServiceContainer.shared.resolveOptional(RouteShareService.self) else {
            error = "Sharing is not configured."
            isLoading = false
            return
        }

        do {
            route = try await service.fetchSharedRoute(id: routeID)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
