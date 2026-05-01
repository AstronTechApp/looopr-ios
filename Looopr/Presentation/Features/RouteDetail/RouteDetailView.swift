import SwiftUI
import MapKit

struct RouteDetailView: View {
    @Environment(AppRouter.self) private var router
    @State private var viewModel: RouteDetailViewModel
    @State private var localization = LocalizationManager.shared
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var sheetExpanded: Bool = true
    @State private var showLeavingTimeSheet = false
    @State private var draftLeavingTime = Date()
    @GestureState private var dragOffset: CGFloat = 0

    /// Active POI category — shared between the POI list filter and the map.
    /// Map pins for the active category are highlighted; others are dimmed.
    @State private var selectedPOITab: POICategoryFilter = .onRoute
    /// POI currently focused via list-tap or map-tap. Drives both the list
    /// scroll-to-card and the map pin pulse + recenter.
    @State private var focusedPOIID: UUID? = nil

    init(route: Route) {
        _viewModel = State(initialValue: RouteDetailViewModel(route: route))
    }

    private var routeColor: Color {
        AppTheme.routeColor(for: viewModel.route.colorIndex)
    }

    /// Top safe area inset from the key window (Dynamic Island / notch).
    private var safeAreaTop: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.top) ?? 0
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Full-bleed interactive map — fills entire screen behind the sheet
            routeMap
                .ignoresSafeArea(edges: .top)

            // Bottom sheet — overlaps map, draggable between expanded/collapsed
            VStack(spacing: 0) {
                Spacer()
                    .frame(minHeight: 0)
                    .layoutPriority(-1)

                bottomSheet
            }

            // Floating CTA button — hovers just above the tab bar
            VStack {
                Spacer()
                Button {
                    router.navigate(to: .walkNavigation(viewModel.routeWithAddedStops))
                } label: {
                    Label(L10n.RouteDetail.startThisLooopr, systemImage: "figure.walk")
                }
                .buttonStyle(.loooprPrimary)
                .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                .padding(.bottom, LoooprTheme.Spacing.xs)
            }

            // Floating buttons — positioned BELOW safe area
            VStack {
                HStack {
                    backButton
                    Spacer()
                    toolbarButtons
                }
                .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                .padding(.top, safeAreaTop + LoooprTheme.Spacing.xs)
                Spacer()
            }

        }
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.loadPOIsIfNeeded()
            fitMapToRoute()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheetView(items: [
                    "Check out this walking route on Looopr! \u{1F6B6}",
                    url
                ] as [Any])
            }
        }
        .sheet(isPresented: $showLeavingTimeSheet) {
            leavingTimeSheet
        }
        .overlay(alignment: .bottom) {
            if viewModel.showFoodProximityWarning {
                Text(L10n.RouteDetail.foodStopNearby)
                    .font(LoooprTheme.Typography.subheadline)
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)
                    .padding(.horizontal, LoooprTheme.Spacing.md)
                    .padding(.vertical, LoooprTheme.Spacing.sm)
                    .background(LoooprTheme.Colors.surface)
                    .clipShape(Capsule())
                    .loooprShadow(LoooprTheme.Shadows.md)
                    .padding(.bottom, 140) // Above the CTA button
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: viewModel.showFoodProximityWarning)
            }
        }
    }

    // MARK: - Map Camera

    /// Fits the map camera to show the entire route polyline with padding.
    private func fitMapToRoute() {
        let coords = viewModel.route.pathCoordinates
        guard !coords.isEmpty else { return }

        var minLat = coords[0].latitude
        var maxLat = coords[0].latitude
        var minLng = coords[0].longitude
        var maxLng = coords[0].longitude

        for coord in coords {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLng = min(minLng, coord.longitude)
            maxLng = max(maxLng, coord.longitude)
        }

        let rawLatDelta = maxLat - minLat
        let rawLngDelta = maxLng - minLng

        // The bottom sheet covers roughly the lower 65% of the screen.
        // The route must fit entirely in the visible top portion (~35%).
        // Strategy: scale the latitude span so the route occupies only the
        // visible fraction, then add generous padding within that portion.
        let visibleFraction = 0.35          // top 35% of the map is unobstructed
        let paddingMultiplier = 1.4         // 40% padding around the route within the visible area

        // Latitude span sized so the padded route fills the visible fraction
        let latDelta = max((rawLatDelta * paddingMultiplier) / visibleFraction, 0.006)
        // Longitude gets its own generous padding (no sheet occlusion horizontally)
        let lngDelta = max(rawLngDelta * 2.0, 0.006)

        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)

        // Place the route's midpoint in the center of the visible top portion.
        // The visible portion's center sits at (1 - visibleFraction/2) from the
        // bottom, i.e. ~81% up from the bottom of the map, which is 31% above
        // the geometric center.  Shift the map center south by that offset so
        // the route lands in the visible area.
        let routeMidLat = (minLat + maxLat) / 2
        let routeMidLng = (minLng + maxLng) / 2
        let verticalOffset = span.latitudeDelta * (0.5 - visibleFraction / 2)

        let adjustedCenter = CLLocationCoordinate2D(
            latitude: routeMidLat - verticalOffset,
            longitude: routeMidLng
        )

        let region = MKCoordinateRegion(center: adjustedCenter, span: span)
        mapCameraPosition = .region(region)
    }

    // MARK: - Map

    private var routeMap: some View {
        Map(position: $mapCameraPosition, interactionModes: [.pan, .zoom, .rotate]) {
            MapPolyline(coordinates: viewModel.route.pathCoordinates)
                .stroke(routeColor, lineWidth: 6)

            // Start dot — teal
            if let start = viewModel.route.pathCoordinates.first {
                Annotation("Start", coordinate: start) {
                    ZStack {
                        Circle().fill(LoooprTheme.Colors.primary).frame(width: 14, height: 14)
                        Circle().stroke(.white, lineWidth: 2).frame(width: 14, height: 14)
                    }
                }
            }

            // End dot — coral
            if let end = viewModel.route.pathCoordinates.last,
               viewModel.route.pathCoordinates.count > 1 {
                Annotation("End", coordinate: end) {
                    ZStack {
                        Circle().fill(LoooprTheme.Colors.routeDot).frame(width: 14, height: 14)
                        Circle().stroke(.white, lineWidth: 2).frame(width: 14, height: 14)
                    }
                }
            }

            // On-route attractions (distributed to avoid bunching)
            ForEach(viewModel.distributedOnRouteAnnotations) { poi in
                Annotation(poi.name, coordinate: poi.location.clCoordinate) {
                    POIMapPin(
                        icon: "star.circle.fill",
                        tint: .yellow,
                        size: .standard,
                        name: poi.name,
                        isActive: selectedPOITab == .onRoute,
                        isFocused: focusedPOIID == poi.id
                    ) {
                        handleMapPinTap(poiID: poi.id, category: .onRoute)
                    }
                }
            }

            // Near-route attractions (distributed to avoid bunching)
            ForEach(viewModel.distributedNearRouteAnnotations) { poi in
                Annotation(poi.name, coordinate: poi.location.clCoordinate) {
                    POIMapPin(
                        icon: poi.category.systemImage,
                        tint: .orange,
                        size: .compact,
                        name: poi.name,
                        isActive: selectedPOITab == .nearRoute,
                        isFocused: focusedPOIID == poi.id
                    ) {
                        handleMapPinTap(poiID: poi.id, category: .nearRoute)
                    }
                }
            }

            // Added food stops — prominent green (always visible regardless of active tab)
            ForEach(viewModel.foodSpots.filter { viewModel.addedFoodStops.contains($0.id) }) { poi in
                Annotation(poi.name, coordinate: poi.location.clCoordinate) {
                    POIMapPin(
                        icon: "fork.knife.circle.fill",
                        tint: .green,
                        size: .standard,
                        name: poi.name,
                        isActive: true, // added stops always at full opacity
                        isFocused: focusedPOIID == poi.id,
                        accentShadow: true
                    ) {
                        handleMapPinTap(poiID: poi.id, category: .food)
                    }
                }
            }

            // Non-added food spots — small orange (distributed)
            ForEach(viewModel.distributedFoodAnnotations.filter { !viewModel.addedFoodStops.contains($0.id) }) { poi in
                Annotation(poi.name, coordinate: poi.location.clCoordinate) {
                    POIMapPin(
                        icon: poi.category.systemImage,
                        tint: .orange,
                        size: .tiny,
                        name: poi.name,
                        isActive: selectedPOITab == .food,
                        isFocused: focusedPOIID == poi.id
                    ) {
                        handleMapPinTap(poiID: poi.id, category: .food)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .onChange(of: focusedPOIID) { _, newValue in
            recenterMap(onPOIID: newValue)
        }
    }

    /// Handles a tap on a map pin: switch the list filter to the matching
    /// category, mark this POI as focused (which scrolls the list + pulses
    /// the pin), and recenter the camera (via the focused-POI onChange).
    private func handleMapPinTap(poiID: UUID, category: POICategoryFilter) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedPOITab = category
            focusedPOIID = poiID
            // Make sure the sheet is open so the user can see the card scroll into view
            if !sheetExpanded { sheetExpanded = true }
        }
    }

    /// Recenters the map camera over the focused POI at a tight, consistent
    /// zoom. The center is pushed slightly south so the POI sits in the
    /// visible top portion of the map (above the bottom sheet).
    private func recenterMap(onPOIID poiID: UUID?) {
        guard let poiID,
              let coordinate = coordinate(forPOIID: poiID) else { return }

        // Tight default zoom — close enough to read the labels around the
        // focused pin, but not so close we lose context of the route.
        let span = MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)

        // Bias the center south so the POI lands in the visible top portion
        // above the bottom sheet (~35% of screen visible).
        let visibleFraction = 0.35
        let verticalOffset = span.latitudeDelta * (0.5 - visibleFraction / 2)
        let adjustedCenter = CLLocationCoordinate2D(
            latitude: coordinate.latitude - verticalOffset,
            longitude: coordinate.longitude
        )

        withAnimation(.easeInOut(duration: 0.4)) {
            mapCameraPosition = .region(MKCoordinateRegion(center: adjustedCenter, span: span))
        }
    }

    /// Looks up a POI's coordinate by id across every annotation source.
    private func coordinate(forPOIID poiID: UUID) -> CLLocationCoordinate2D? {
        if let poi = viewModel.distributedOnRouteAnnotations.first(where: { $0.id == poiID }) {
            return poi.location.clCoordinate
        }
        if let poi = viewModel.distributedNearRouteAnnotations.first(where: { $0.id == poiID }) {
            return poi.location.clCoordinate
        }
        if let poi = viewModel.distributedFoodAnnotations.first(where: { $0.id == poiID }) {
            return poi.location.clCoordinate
        }
        if let poi = viewModel.foodSpots.first(where: { $0.id == poiID }) {
            return poi.location.clCoordinate
        }
        if let poi = viewModel.onRouteAttractions.first(where: { $0.id == poiID }) {
            return poi.location.clCoordinate
        }
        if let poi = viewModel.nearRouteAttractions.first(where: { $0.id == poiID }) {
            return poi.location.clCoordinate
        }
        if let poi = viewModel.cafesAndRestaurants.first(where: { $0.id == poiID }) {
            return poi.location.clCoordinate
        }
        return nil
    }

    // MARK: - Back Button

    private var backButton: some View {
        Button { router.pop() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: LoooprTheme.Typography.md, weight: .semibold))
                .foregroundStyle(LoooprTheme.Colors.textPrimary)
                .frame(width: 40, height: 40)
                .background(LoooprTheme.Colors.surface)
                .clipShape(Circle())
                .loooprShadow(LoooprTheme.Shadows.sm)
        }
    }

    // MARK: - Toolbar Buttons

    private var toolbarButtons: some View {
        HStack(spacing: LoooprTheme.Spacing.xs) {
            // Share
            Button {
                Task {
                    if let url = await viewModel.shareRoute() {
                        shareURL = url
                        showShareSheet = true
                    }
                }
            } label: {
                Group {
                    if viewModel.isSharing {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: LoooprTheme.Typography.md, weight: .medium))
                    }
                }
                .foregroundStyle(LoooprTheme.Colors.textPrimary)
                .frame(width: 40, height: 40)
                .background(LoooprTheme.Colors.surface)
                .clipShape(Circle())
                .loooprShadow(LoooprTheme.Shadows.sm)
            }
            .disabled(viewModel.isSharing)

            // Bookmark
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    viewModel.toggleSave()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: viewModel.isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: LoooprTheme.Typography.md, weight: .medium))
                    .foregroundStyle(
                        viewModel.isSaved
                            ? LoooprTheme.Colors.routeDot
                            : LoooprTheme.Colors.textPrimary
                    )
                    .frame(width: 40, height: 40)
                    .background(LoooprTheme.Colors.surface)
                    .clipShape(Circle())
                    .loooprShadow(LoooprTheme.Shadows.sm)
            }
        }
    }

    // MARK: - Bottom Sheet

    /// Height fractions for expanded/collapsed sheet states.
    /// 65% info card / 35% map split when expanded.
    private var expandedHeight: CGFloat { UIScreen.main.bounds.height * 0.65 }
    private var collapsedHeight: CGFloat { UIScreen.main.bounds.height * 0.28 }

    private var currentSheetHeight: CGFloat {
        sheetExpanded ? expandedHeight : collapsedHeight
    }

    private var bottomSheet: some View {
        VStack(spacing: 0) {
            // Draggable header area: handle + route name + stats
            sheetHeader

            // Expandable content — only visible when sheet is expanded
            if sheetExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: LoooprTheme.Spacing.md) {
                        // Divider
                        Rectangle()
                            .fill(LoooprTheme.Colors.border)
                            .frame(height: 1)

                        // About section
                        aboutSection

                        leavingTimeControl

                        // Full POI section with filter tabs + card list
                        poiSection

                        // Food stops badge
                        if !viewModel.addedFoodStops.isEmpty {
                            Text(L10n.RouteDetail.foodStopsAdded(viewModel.addedFoodStops.count))
                                .font(LoooprTheme.Typography.caption)
                                .foregroundStyle(LoooprTheme.Colors.routeDot)
                        }
                    }
                    .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                    .padding(.bottom, 80) // Clear floating CTA + tab bar
                }
                .transition(.opacity)
            }

        }
        .frame(maxHeight: currentSheetHeight, alignment: .top)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: LoooprTheme.Radius.sheet,
                topTrailingRadius: LoooprTheme.Radius.sheet
            )
            .fill(LoooprTheme.Colors.surface)
            .loooprShadow(LoooprTheme.Shadows.sheet)
            .ignoresSafeArea(edges: .bottom)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: sheetExpanded)
    }

    // MARK: - Sheet Header (draggable)

    private var sheetHeader: some View {
        VStack(spacing: 0) {
            // Drag handle pill
            Capsule()
                .fill(LoooprTheme.Colors.borderStrong)
                .frame(width: 36, height: 5)
                .padding(.top, LoooprTheme.Spacing.xs)
                .padding(.bottom, LoooprTheme.Spacing.xs)

            // Route name + stat chips — always visible
            VStack(alignment: .leading, spacing: LoooprTheme.Spacing.md) {
                Text(viewModel.route.displayName)
                    .font(LoooprTheme.Typography.title)
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)

                statRow
            }
            .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
            .padding(.bottom, LoooprTheme.Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                .onEnded { value in
                    let verticalMovement = value.translation.height
                    let threshold: CGFloat = 60
                    if sheetExpanded && verticalMovement > threshold {
                        sheetExpanded = false
                    } else if !sheetExpanded && verticalMovement < -threshold {
                        sheetExpanded = true
                    }
                }
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                sheetExpanded.toggle()
            }
        }
    }

    // MARK: - Stat Row

    private var statRow: some View {
        HStack(spacing: LoooprTheme.Spacing.xs) {
            DetailStatChip(
                icon: "figure.walk",
                value: viewModel.route.distanceKilometers.formattedDistanceFromKm()
            )
            DetailStatChip(
                icon: "clock",
                value: viewModel.route.paceAdjustedDurationLabel
            )
            DetailStatChip(
                icon: "arrow.up.right",
                value: Double(RouteSelectionViewModel.estimatedElevation(for: viewModel.route)).formattedElevation()
            )
        }
    }

    // MARK: - About Section

    @ViewBuilder
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: LoooprTheme.Spacing.xs) {
            if !viewModel.route.description.isEmpty {
                Text(L10n.RouteDetail.aboutThisRoute)
                    .font(LoooprTheme.Typography.label)
                    .foregroundStyle(LoooprTheme.Colors.textTertiary)

                Text("\(viewModel.route.paceAdjustedDurationLabel) \(L10n.RouteDetail.loopDuration)")
                    .font(LoooprTheme.Typography.body)
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
            }

            // Ferry notice
            if viewModel.route.containsFerry {
                HStack(spacing: 6) {
                    Image(systemName: "ferry")
                        .font(.system(size: 13, weight: .semibold))
                    Text(L10n.RouteDetail.includeFerryDescription)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color(hex: "#0D47A1"))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#BBDEFB").opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Leaving Time

    private var leavingTimeControl: some View {
        Button {
            draftLeavingTime = viewModel.effectiveDepartureDate
            showLeavingTimeSheet = true
        } label: {
            HStack(spacing: LoooprTheme.Spacing.sm) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LoooprTheme.Colors.primary)
                    .frame(width: 32, height: 32)
                    .background(LoooprTheme.Colors.primaryLight)
                    .clipShape(Circle())

                Text(L10n.RouteDetail.leavingTime)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)

                Spacer()

                Text(viewModel.leavingTimeValueLabel)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LoooprTheme.Colors.textTertiary)
            }
            .padding(.horizontal, LoooprTheme.Spacing.md)
            .padding(.vertical, LoooprTheme.Spacing.sm)
            .background(LoooprTheme.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: LoooprTheme.Radius.md)
                    .strokeBorder(LoooprTheme.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var leavingTimeSheet: some View {
        VStack(spacing: LoooprTheme.Spacing.md) {
            Capsule()
                .fill(LoooprTheme.Colors.borderStrong)
                .frame(width: 36, height: 5)
                .padding(.top, LoooprTheme.Spacing.sm)

            Text(L10n.RouteDetail.leavingTime)
                .font(LoooprTheme.Typography.title)
                .foregroundStyle(LoooprTheme.Colors.textPrimary)

            DatePicker(
                L10n.RouteDetail.leavingTime,
                selection: $draftLeavingTime,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.locale, localization.currentLocale)

            HStack(spacing: LoooprTheme.Spacing.sm) {
                Button {
                    viewModel.setLeavingNow()
                    showLeavingTimeSheet = false
                } label: {
                    Text(L10n.Misc.now)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.loooprSecondary)

                Button {
                    viewModel.setLeavingTime(draftLeavingTime)
                    showLeavingTimeSheet = false
                } label: {
                    Text(L10n.Misc.done)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.loooprPrimary)
            }
            .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
            .padding(.bottom, LoooprTheme.Spacing.md)
        }
        .presentationDetents([.height(390)])
        .presentationDragIndicator(.hidden)
        .background(LoooprTheme.Colors.surface)
    }

    // MARK: - POI Section (filter tabs + card list)

    @ViewBuilder
    private var poiSection: some View {
        if viewModel.isLoadingPOIs {
            HStack(spacing: LoooprTheme.Spacing.xs) {
                ProgressView().scaleEffect(0.8)
                Text(L10n.RouteDetail.findingNearbyAttractions)
                    .font(LoooprTheme.Typography.subheadline)
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
            }
            .padding(.vertical, LoooprTheme.Spacing.md)
        } else if viewModel.hasPOIs || viewModel.hasCompletedInitialPOILoad {
            VStack(alignment: .leading, spacing: LoooprTheme.Spacing.xs) {
                Text(L10n.RouteDetail.pointsOfInterest)
                    .font(LoooprTheme.Typography.label)
                    .foregroundStyle(LoooprTheme.Colors.textTertiary)

                // Full POI list with filter tabs and cards
                POIListView(
                    onRouteAttractions: viewModel.onRouteAttractions,
                    nearRouteAttractions: viewModel.nearRouteAttractions,
                    cafesAndRestaurants: viewModel.cafesAndRestaurants,
                    onAddFoodStop: { viewModel.toggleFoodStop($0) },
                    addedFoodStopIDs: viewModel.addedFoodStops,
                    onFoodTabSelected: { viewModel.loadFoodIfNeeded() },
                    isLoadingFood: viewModel.isLoadingFood,
                    hasFetchedFood: viewModel.hasFetchedFood,
                    departureDate: viewModel.plannedDepartureDate,
                    selectedTab: $selectedPOITab,
                    focusedPOIID: $focusedPOIID
                )
            }
        }
    }
}

// MARK: - Detail Stat Chip

private struct DetailStatChip: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: LoooprTheme.Spacing.xxs) {
            Image(systemName: icon)
            Text(value)
        }
        .font(LoooprTheme.Typography.subheadline)
        .foregroundStyle(LoooprTheme.Colors.primary)
        .padding(.horizontal, LoooprTheme.Spacing.sm)
        .padding(.vertical, LoooprTheme.Spacing.xs)
        .background(LoooprTheme.Colors.primaryLight)
        .clipShape(Capsule())
    }
}

// MARK: - Stat Badge (backward compatibility for POIListView)

struct StatBadge: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: LoooprTheme.Spacing.xxs) {
            Image(systemName: icon)
            Text(value)
        }
        .font(LoooprTheme.Typography.caption)
        .foregroundStyle(LoooprTheme.Colors.textSecondary)
    }
}

// MARK: - POI Map Pin

/// A single POI annotation rendered inside the route map.
///
/// - Active vs inactive: when the user picks a category in the POI list, only
///   pins from that category are at full opacity + show a name label below.
///   Pins from other categories are dimmed and label-less so the active
///   selection stands out.
/// - Focused: when a specific POI is tapped (in the list or on the map), its
///   pin pulses + grows + gets an accent ring so the user can find it at a
///   glance even in dense areas.
private struct POIMapPin: View {
    enum Size {
        case standard       // .title3-ish — on-route stars, food stops
        case compact        // .caption-ish — near-route attractions
        case tiny           // .caption2-ish — non-added food spots

        var iconFont: Font {
            switch self {
            case .standard: return .title3
            case .compact:  return .caption
            case .tiny:     return .caption2
            }
        }

        var iconPadding: CGFloat {
            switch self {
            case .standard: return -2
            case .compact:  return 5
            case .tiny:     return 4
            }
        }
    }

    let icon: String
    let tint: Color
    let size: Size
    let name: String
    let isActive: Bool
    let isFocused: Bool
    var accentShadow: Bool = false
    var onTap: () -> Void = {}

    /// Pulse scale for the focused pin.
    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 3) {
            iconBubble
                .scaleEffect(isFocused ? (pulse ? 1.18 : 1.0) : 1.0)
                .animation(
                    isFocused
                        ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                        : .default,
                    value: pulse
                )
                .onChange(of: isFocused) { _, newValue in
                    if newValue {
                        pulse = true
                    } else {
                        pulse = false
                    }
                }
                .onAppear { if isFocused { pulse = true } }

            if isActive {
                Text(truncatedName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.92))
                    )
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.4), lineWidth: 0.5)
                    )
                    .lineLimit(1)
                    .fixedSize()
                    .transition(.opacity)
            }
        }
        .opacity(isActive ? 1.0 : 0.35)
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .onTapGesture {
            onTap()
        }
    }

    private var iconBubble: some View {
        Image(systemName: icon)
            .font(size.iconFont)
            .foregroundStyle(tint)
            .padding(size.iconPadding)
            .background(
                Group {
                    switch size {
                    case .standard:
                        Circle().fill(.white).padding(-2)
                    case .compact, .tiny:
                        Circle().fill(.white)
                    }
                }
            )
            .overlay(
                Circle()
                    .stroke(
                        isFocused ? tint : (size == .compact ? tint.opacity(0.3) : .clear),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .shadow(
                color: accentShadow ? tint.opacity(0.4) : (isFocused ? tint.opacity(0.5) : .clear),
                radius: accentShadow || isFocused ? 4 : 0
            )
    }

    /// Pin labels are short to keep the map readable; full name stays in the card.
    private var truncatedName: String {
        if name.count <= 18 { return name }
        return String(name.prefix(17)) + "…"
    }
}
