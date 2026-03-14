import SwiftUI
import MapKit

struct RouteDetailView: View {
    @Environment(AppRouter.self) private var router
    @State private var viewModel: RouteDetailViewModel

    init(route: Route) {
        _viewModel = State(initialValue: RouteDetailViewModel(route: route))
    }

    private var routeColor: Color {
        AppTheme.routeColor(for: viewModel.route.colorIndex)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Map
                routeMap
                    .frame(height: 280)

                // Route info header
                routeInfoHeader
                    .padding(AppTheme.spacingMedium)

                Divider()

                // Start walk button
                startWalkButton
                    .padding(AppTheme.spacingMedium)

                Divider()

                // POI sections
                poiContent
                    .padding(.top, AppTheme.spacingSmall)
            }
        }
        .navigationTitle(viewModel.route.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.loadPOIsIfNeeded() }
    }

    // MARK: - Map

    private var routeMap: some View {
        Map {
            MapPolyline(coordinates: viewModel.route.pathCoordinates)
                .stroke(routeColor, lineWidth: 4)

            if let start = viewModel.route.pathCoordinates.first {
                Annotation("Start", coordinate: start) {
                    ZStack {
                        Circle().fill(routeColor).frame(width: 14, height: 14)
                        Circle().stroke(.white, lineWidth: 2).frame(width: 14, height: 14)
                    }
                }
            }

            ForEach(viewModel.attractions) { poi in
                Annotation(poi.name, coordinate: poi.location.clCoordinate) {
                    Image(systemName: "star.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                        .background(Circle().fill(.white).padding(-2))
                }
            }

            ForEach(viewModel.foodSpots) { poi in
                Annotation(poi.name, coordinate: poi.location.clCoordinate) {
                    Image(systemName: poi.category.systemImage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(4)
                        .background(Circle().fill(.white))
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
    }

    // MARK: - Info Header

    private var routeInfoHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack(spacing: AppTheme.spacingMedium) {
                StatBadge(icon: "clock", value: "\(viewModel.route.durationMinutes) min")
                StatBadge(icon: "figure.walk", value: String(format: "%.1f km", viewModel.route.distanceKilometers))
                DifficultyBadge(difficulty: viewModel.route.difficulty)
                Spacer()
            }

            if !viewModel.route.description.isEmpty {
                Text(viewModel.route.description)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Start Walk

    private var startWalkButton: some View {
        Button {
            router.navigate(to: .walkNavigation(viewModel.route))
        } label: {
            Label("Start Walk", systemImage: "figure.walk")
                .font(AppTheme.headlineFont)
                .frame(maxWidth: .infinity)
                .padding()
                .background(routeColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
    }

    // MARK: - POI Content

    @ViewBuilder
    private var poiContent: some View {
        if viewModel.isLoadingPOIs {
            LoadingStateView(message: "Finding nearby attractions...")
                .frame(height: 120)
        } else if viewModel.hasLoadedPOIs {
            POIListView(
                attractions: viewModel.attractions,
                foodSpots: viewModel.foodSpots
            )
        }
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(value)
        }
        .font(AppTheme.captionFont)
        .foregroundStyle(.secondary)
    }
}
