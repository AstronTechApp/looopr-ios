import SwiftUI

struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @State private var viewModel = HomeViewModel()
    @State private var showPaceSheet = false
    @State private var showLocationSearch = false

    var body: some View {
        ZStack {
            LoooprTheme.Colors.background
                .ignoresSafeArea()

            homeContent
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.loadSavedRoutes()
            viewModel.loadNearbyExperiences()
        }
        // Reload saved routes whenever we return to this root view.
        // `onAppear` alone is unreliable inside a NavigationStack;
        // watching the route stack guarantees a refresh after saving.
        .onChange(of: router.routeStack) { _, stack in
            if stack.isEmpty {
                viewModel.loadSavedRoutes()
            }
        }
    }

    /// Navigate to route selection, passing custom location if set.
    private func navigateToRouteSelection() {
        let customLocation: CustomRouteLocation? = {
            guard let selected = viewModel.selectedLocation, !viewModel.isUsingCurrentLocation else {
                return nil
            }
            return CustomRouteLocation(from: selected)
        }()
        router.navigate(to: .routeSelection(
            walkMinutes: Int(viewModel.walkDuration),
            customLocation: customLocation
        ))
    }

    // MARK: - Home Content

    private var homeContent: some View {
        ScrollView {
            VStack(spacing: LoooprTheme.Spacing.xxl) {
                headerSection
                locationField
                durationCard
                findRouteButton
                savedRoutesSection
                recentWalksSection
                experiencesSection
            }
            .padding(.bottom, LoooprTheme.Layout.navBarHeight)
        }
        .sheet(isPresented: $showPaceSheet) {
            WalkingPaceSelectionView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLocationSearch) {
            LocationSearchView(
                onSelectLocation: { location in
                    viewModel.selectLocation(location)
                },
                onSelectCurrentLocation: {
                    viewModel.selectCurrentLocation()
                }
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: LoooprTheme.Spacing.xs) {
                    Image("LoooprLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)

                    Text(viewModel.greeting)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(LoooprTheme.Colors.textSecondary)
                }

                Text(L10n.Home.readyToLooopr)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)
            }

            Spacer()

            // Profile icon — tonal circle
            Button {
                NotificationCenter.default.post(
                    name: Notification.Name("SwitchToProfileTab"),
                    object: nil
                )
            } label: {
                Circle()
                    .fill(LoooprTheme.Colors.surfaceContainer)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(LoooprTheme.Colors.textTertiary)
                    )
            }
        }
        .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal + 4)
        .padding(.top, LoooprTheme.Spacing.md)
    }

    // MARK: - Location Field

    private var locationField: some View {
        Button {
            showLocationSearch = true
        } label: {
            HStack(spacing: LoooprTheme.Spacing.sm) {
                Image(systemName: viewModel.isUsingCurrentLocation ? "location.fill" : "mappin.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(LoooprTheme.Colors.primary)

                Text(viewModel.locationDisplayName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        viewModel.isUsingCurrentLocation
                            ? LoooprTheme.Colors.textSecondary
                            : LoooprTheme.Colors.textPrimary
                    )
                    .lineLimit(1)

                Spacer()

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(LoooprTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(LoooprTheme.Colors.surfaceContainerHigh)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
    }

    // MARK: - Duration Card (Tonal — no shadow)

    private var durationCard: some View {
        VStack(spacing: LoooprTheme.Spacing.lg) {
            // Duration header: question on left, big number on right
            HStack(alignment: .bottom) {
                Text(L10n.Home.howLongWalk)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
                    .frame(maxWidth: 130, alignment: .leading)

                Spacer()

                // Hero stat — editorial large number
                VStack(alignment: .trailing, spacing: 2) {
                    Text(viewModel.durationNumberOnly)
                        .font(.system(size: 68, weight: .heavy, design: .rounded))
                        .tracking(-2)
                        .foregroundStyle(LoooprTheme.Colors.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                        .animation(LoooprTheme.Animation.snappy, value: viewModel.walkDuration)

                    Text(viewModel.durationUnitOnly)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundStyle(LoooprTheme.Colors.primary.opacity(0.6))
                }
            }

            // Slider
            VStack(spacing: LoooprTheme.Spacing.xxs) {
                DurationSlider(value: $viewModel.walkDuration, range: 15...180)
                    .frame(height: 44)
                    .onChange(of: viewModel.walkDuration) { _, _ in
                        viewModel.snapDuration()
                    }

                HStack {
                    Text(L10n.Home.duration15min)
                    Spacer()
                    Text(L10n.Home.duration3h)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(LoooprTheme.Colors.textTertiary)
                .padding(.horizontal, 4)
            }

            // Pace chips — inline selection
            paceChips
        }
        .padding(LoooprTheme.Spacing.xl)
        .background(LoooprTheme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.xl))
        .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
    }

    // MARK: - Pace Chips

    private var paceChips: some View {
        let currentPace = SettingsManager.shared.walkingPace
        let useMetric = SettingsManager.shared.preferredUnits == .kilometres

        return VStack(spacing: 10) {
            Text(L10n.Home.walkingPace)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(LoooprTheme.Colors.textTertiary)

            HStack(spacing: 10) {
                ForEach(SettingsManager.WalkingPace.allCases, id: \.self) { pace in
                    let isActive = pace == currentPace
                    Button {
                        SettingsManager.shared.walkingPace = pace
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: paceIcon(for: pace))
                                .font(.system(size: 24, weight: isActive ? .semibold : .regular))
                                .symbolVariant(isActive ? .fill : .none)

                            Text(pace.label)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .textCase(.uppercase)
                                .tracking(0.8)

                            Text(paceSpeedLabel(pace: pace, metric: useMetric))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .opacity(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            isActive
                                ? AnyShapeStyle(LoooprTheme.Colors.primary)
                                : AnyShapeStyle(LoooprTheme.Colors.surfaceContainer)
                        )
                        .foregroundStyle(
                            isActive
                                ? LoooprTheme.Colors.textOnPrimary
                                : LoooprTheme.Colors.textSecondary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
                        .overlay(
                            isActive
                                ? RoundedRectangle(cornerRadius: LoooprTheme.Radius.card)
                                    .strokeBorder(LoooprTheme.Colors.primaryLight, lineWidth: 3)
                                : nil
                        )
                        .shadow(
                            color: isActive ? LoooprTheme.Colors.primary.opacity(0.25) : .clear,
                            radius: isActive ? 8 : 0,
                            y: isActive ? 4 : 0
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func paceIcon(for pace: SettingsManager.WalkingPace) -> String {
        switch pace {
        case .leisure:  return "figure.mind.and.body"
        case .moderate: return "figure.walk"
        case .brisk:    return "bolt"
        }
    }

    private func paceSpeedLabel(pace: SettingsManager.WalkingPace, metric: Bool) -> String {
        let units: SettingsManager.Units = metric ? .kilometres : .miles
        return pace.kilometresPerHour.formattedSpeed(units: units)
    }

    // MARK: - Find Route CTA (Gradient)

    private var findRouteButton: some View {
        Button {
            navigateToRouteSelection()
        } label: {
            HStack(spacing: 10) {
                Text(L10n.Home.findMyLooopr)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .tracking(-0.3)

                Image(systemName: "arrow.forward")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#1B5E20"), Color(hex: "#66BB6A")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: LoooprTheme.Colors.primary.opacity(0.2), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
    }

    // MARK: - Saved Routes

    @ViewBuilder
    private var savedRoutesSection: some View {
        VStack(alignment: .leading, spacing: LoooprTheme.Spacing.sm + 2) {
            // Section header — editorial style
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.Home.savedLoooprs)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .tracking(-0.6)
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)

                Spacer()

                if !viewModel.savedRoutes.isEmpty {
                    Text(L10n.Home.viewAll)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(LoooprTheme.Colors.primary)
                }
            }
            .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)

            if viewModel.savedRoutes.isEmpty {
                // Empty state — tonal card, no dashed border
                VStack(spacing: LoooprTheme.Spacing.sm) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 28))
                        .foregroundStyle(LoooprTheme.Colors.textTertiary)

                    Text(L10n.Home.noSavedRoutes)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(LoooprTheme.Colors.textSecondary)

                    Text(L10n.Home.bookmarkRoutesDescription)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(LoooprTheme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .background(LoooprTheme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.xl))
                .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(viewModel.savedRoutes) { route in
                            RouteCardMini(route: route) {
                                router.navigate(to: .routeDetail(route))
                            }
                        }
                    }
                    .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                }
            }
        }
    }

    // MARK: - Recent Walks

    @ViewBuilder
    private var recentWalksSection: some View {
        if !viewModel.recentRoutes.isEmpty {
            VStack(alignment: .leading, spacing: LoooprTheme.Spacing.sm + 2) {
                Text(L10n.Home.recentLoooprs)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .tracking(-0.6)
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)
                    .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(viewModel.recentRoutes) { route in
                            RouteCardMini(route: route) {
                                router.navigate(to: .routeDetail(route))
                            }
                        }
                    }
                    .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                }
            }
        }
    }

    // MARK: - Nearby Experiences

    @ViewBuilder
    private var experiencesSection: some View {
        if viewModel.isLoadingExperiences {
            HStack(spacing: LoooprTheme.Spacing.xs) {
                ProgressView().scaleEffect(0.8)
                Text(L10n.Home.findingNearbyExperiences)
                    .font(LoooprTheme.Typography.subheadline)
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
            }
            .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
        } else if !viewModel.nearbyExperiences.isEmpty {
            NearbyExperiencesWidget(experiences: viewModel.nearbyExperiences)
        }
    }
}

// MARK: - Duration Slider (Redesigned — tonal track with white thumb)

private struct DurationSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let fraction = (value - range.lowerBound)
                / (range.upperBound - range.lowerBound)
            let thumbX = fraction * width

            ZStack(alignment: .leading) {
                // Track container — tonal capsule
                Capsule()
                    .fill(LoooprTheme.Colors.surfaceContainer)
                    .frame(height: 44)

                // Track background (inside the capsule)
                Capsule()
                    .fill(LoooprTheme.Colors.surfaceContainerHigh)
                    .frame(height: 6)
                    .padding(.horizontal, 8)

                // Filled track
                Capsule()
                    .fill(LoooprTheme.Colors.primary)
                    .frame(width: max(0, thumbX), height: 6)
                    .padding(.leading, 8)

                // Thumb — white circle with green border
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .strokeBorder(LoooprTheme.Colors.primary, lineWidth: 3.5)
                    )
                    .overlay(
                        Circle()
                            .fill(LoooprTheme.Colors.primary)
                            .frame(width: 4, height: 4)
                    )
                    .shadow(color: LoooprTheme.Colors.primary.opacity(0.15), radius: 6, y: 2)
                    .scaleEffect(isDragging ? 1.15 : 1.0)
                    .offset(x: thumbX - 14)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isDragging = true
                        let fraction = max(0, min(1, drag.location.x / width))
                        let raw = range.lowerBound
                            + fraction * (range.upperBound - range.lowerBound)
                        value = (raw / 5).rounded() * 5
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .animation(LoooprTheme.Animation.snappy, value: isDragging)
        }
    }
}
