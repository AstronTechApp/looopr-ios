import SwiftUI

struct DiscoveryView: View {
    @Environment(AppRouter.self) private var router
    @State private var viewModel = DiscoveryViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("Muter")
                    .font(.largeTitle.bold())
                Text("Discover the perfect walk")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, AppTheme.spacingMedium)

            // Location bar
            LocationBar(
                description: viewModel.locationDescription,
                hasCustomLocation: viewModel.customLocation != nil,
                onSearchTap: { viewModel.showLocationSearch = true },
                onClear: { viewModel.clearCustomLocation() }
            )
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.top, AppTheme.spacingSmall)

            // Time Selector
            TimeSelectorView(
                minutes: $viewModel.selectedTimeMinutes,
                onChange: { viewModel.timeChanged() }
            )
            .padding(.vertical, AppTheme.spacingMedium)

            Divider()

            // Route list
            routeContent
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.onAppear() }
        .sheet(isPresented: $viewModel.showLocationSearch) {
            LocationSearchView { location in
                viewModel.setCustomLocation(location)
            }
        }
    }

    @ViewBuilder
    private var routeContent: some View {
        switch viewModel.loadingState {
        case .idle:
            ScrollView {
                if viewModel.hasLocation {
                    generateButton
                } else {
                    EmptyStateView(
                        title: "Enable Location",
                        subtitle: "Allow location access or search for a place to generate walking routes.",
                        systemImage: "location.slash"
                    )
                }
            }

        case .loading:
            LoadingStateView(message: "Finding the best routes...")

        case .loaded:
            ScrollView {
                LazyVStack(spacing: AppTheme.spacingMedium) {
                    ForEach(viewModel.routes) { route in
                        RouteCardView(route: route) {
                            router.navigate(to: .routeDetail(route))
                        }
                    }
                }
                .padding(AppTheme.spacingMedium)
            }

        case .error(let message):
            ErrorStateView(message: message) {
                viewModel.generateRoutes()
            }

        case .throttled(let seconds):
            LoadingStateView(message: "Rate limited. Retrying in \(seconds)s...")
        }
    }

    private var generateButton: some View {
        Button {
            viewModel.generateRoutes()
        } label: {
            Label("Generate Routes", systemImage: "figure.walk")
                .font(AppTheme.headlineFont)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.primary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
        .padding(AppTheme.spacingLarge)
    }
}

// MARK: - Location Bar

private struct LocationBar: View {
    let description: String
    let hasCustomLocation: Bool
    let onSearchTap: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack {
            Image(systemName: hasCustomLocation ? "mappin.circle.fill" : "location.fill")
                .foregroundStyle(hasCustomLocation ? AppTheme.secondary : AppTheme.primary)

            Text(description)
                .font(AppTheme.captionFont)
                .foregroundStyle(.primary)

            Spacer()

            if hasCustomLocation {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: onSearchTap) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.primary)
            }
        }
        .padding(AppTheme.spacingSmall)
        .background(AppTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
    }
}

#Preview {
    AppRootView()
}
