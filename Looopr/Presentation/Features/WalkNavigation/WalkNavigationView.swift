import SwiftUI
import MapKit

struct WalkNavigationView: View {
    @Environment(AppRouter.self) private var router
    @State private var viewModel: WalkNavigationViewModel
    @State private var offRoute = OffRouteViewModel()
    @State private var showStopConfirmation = false
    @State private var cameraPosition: MapCameraPosition
    @State private var isFollowingUser = true
    /// Counts in-flight programmatic camera updates. Each programmatic change
    /// increments this; each `.onMapCameraChange(frequency: .onEnd)` event
    /// decrements it. Only when it reaches 0 does a camera-end event count
    /// as a user-initiated pan (which disables follow mode).
    /// Starts at 1 to absorb the Map's own initial-render camera event.
    @State private var pendingCameraChanges: Int = 1
    /// Tracks the live map camera heading so the user-location arrow can be
    /// rotated relative to the map.
    @State private var currentMapHeading: CLLocationDirection = 0
    /// 0→1 cycling value that drives the "marching" wave along route arrows.
    @State private var arrowPhase: Double = 0

    private let routeColor = Color(hex: "#66BB6A")

    // MARK: - Camera constants (60-70° tilt, 500-800m distance)
    private let navigationDistance: CLLocationDistance = 600
    private let navigationPitch: Double = 65

    init(route: Route) {
        _viewModel = State(initialValue: WalkNavigationViewModel(route: route))
        _cameraPosition = State(initialValue: .camera(MapCamera(
            centerCoordinate: route.startLocation.clCoordinate,
            distance: 600,
            heading: 0,
            pitch: 65
        )))
    }

    // MARK: - Camera helpers

    private func navigationCamera(at coordinate: CLLocationCoordinate2D,
                                  heading: CLLocationDirection) -> MapCamera {
        MapCamera(centerCoordinate: coordinate,
                  distance: navigationDistance,
                  heading: heading,
                  pitch: navigationPitch)
    }

    private var nextStepBearing: Double { viewModel.currentRouteBearing }

    private func snapToNavigationCamera() {
        guard let location = viewModel.userLocation else {
            isFollowingUser = true
            return
        }
        pendingCameraChanges += 1
        withAnimation(.easeOut(duration: 0.6)) {
            cameraPosition = .camera(navigationCamera(at: location, heading: viewModel.heading))
        }
        isFollowingUser = true
    }

    // MARK: - Computed helpers

    private var progressFraction: Double {
        let total = viewModel.distanceWalked + viewModel.remainingMeters
        guard total > 0 else { return 0 }
        return min(1, viewModel.distanceWalked / total)
    }

    private var elapsedLabel: String {
        let total = Int(viewModel.elapsedSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Full-screen 3D map
            navigationMap
                .ignoresSafeArea()

            // Main overlay column
            VStack(spacing: 0) {
                // Turn instruction banner
                if !viewModel.isLoading && viewModel.error == nil {
                    turnInstructionBanner
                        .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                        .padding(.top, LoooprTheme.Spacing.md)
                }

                // POI approaching banner
                if let poi = viewModel.approachingPOI {
                    poiApproachingBanner(poi)
                        .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                        .padding(.top, LoooprTheme.Spacing.xs)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Off-route banner
                bannerStack
                    .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)

                Spacer()

                // Street name pill — floats just above the stats bar
                if !viewModel.currentStreetName.isEmpty {
                    streetLabel
                        .padding(.bottom, LoooprTheme.Spacing.xs)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                statsBar
            }
            .animation(LoooprTheme.Animation.standard, value: viewModel.approachingPOI != nil)

            // Re-center pill
            if !isFollowingUser && !viewModel.isLoading {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: snapToNavigationCamera) {
                            Image(systemName: "location.north.line.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(LoooprTheme.Colors.textOnPrimary)
                                .frame(width: 48, height: 48)
                                .background(LoooprTheme.Colors.primary, in: Circle())
                                .loooprShadow(LoooprTheme.Shadows.md)
                        }
                        .accessibilityLabel(Text("Re-center"))
                        .padding(.trailing, LoooprTheme.Spacing.md)
                        .padding(.bottom, LoooprTheme.Spacing.lg)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 140)
                }
                .transition(.scale.combined(with: .opacity))
                .animation(LoooprTheme.Animation.standard, value: isFollowingUser)
            }

            // Loading overlay
            if viewModel.isLoading { loadingOverlay }

            if viewModel.showWrongWayPrompt {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(20)

                VStack {
                    Spacer()
                    WrongWaySheetView(
                        onFlipRoute: {
                            viewModel.confirmWrongWayFlip()
                        },
                        onKeepGoing: {
                            viewModel.keepOriginalRouteAfterWrongWayPrompt()
                        }
                    )
                    .padding(.horizontal, LoooprTheme.Spacing.md)
                    .padding(.bottom, LoooprTheme.Spacing.md)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.keyboard)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(21)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar, .tabBar)
        .statusBarHidden()
        .confirmationDialog(L10n.WalkNavigation.endWalk, isPresented: $showStopConfirmation) {
            Button("Save & Finish") { viewModel.finish() }
            Button(L10n.WalkNavigation.endWalkButton, role: .destructive) {
                viewModel.stop()
                router.popToRoot()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(L10n.WalkNavigation.progressNotSaved)
        }
        .overlay(alignment: .top) {
            VStack(spacing: LoooprTheme.Spacing.xs) {
                if viewModel.showFoodCheckIn, let spot = viewModel.nearbyFoodSpot {
                    poiToast(name: spot.name, icon: spot.category.systemImage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if viewModel.showRouteUpdatedToast {
                    toastCapsule(icon: "arrow.triangle.2.circlepath",
                                 text: viewModel.routeToastMessage,
                                 color: viewModel.routeToastStyle.toastColor)
                }
            }
            .padding(.top, 100)
        }
        .animation(LoooprTheme.Animation.standard, value: viewModel.showFoodCheckIn)
        .animation(LoooprTheme.Animation.standard, value: viewModel.showRouteUpdatedToast)
        .animation(LoooprTheme.Animation.standard, value: viewModel.showWrongWayPrompt)
        .task { await viewModel.start() }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                arrowPhase = (arrowPhase + 0.033).truncatingRemainder(dividingBy: 1.0)
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: viewModel.userLocation) { _, location in
            guard let location else { return }
            offRoute.check(
                userLocation: location,
                horizontalAccuracy: viewModel.currentAccuracy,
                routePolyline: viewModel.activePolyline
            )
            if isFollowingUser {
                pendingCameraChanges += 1
                withAnimation(.easeOut(duration: 0.4)) {
                    cameraPosition = .camera(navigationCamera(at: location, heading: viewModel.heading))
                }
            }
        }
        .onChange(of: viewModel.heading) { _, heading in
            guard isFollowingUser, let location = viewModel.userLocation else { return }
            pendingCameraChanges += 1
            withAnimation(.easeOut(duration: 0.3)) {
                cameraPosition = .camera(navigationCamera(at: location, heading: heading))
            }
        }
        .onMapCameraChange(frequency: .continuous) { context in
            currentMapHeading = context.camera.heading
        }
        .onMapCameraChange(frequency: .onEnd) { _ in
            if pendingCameraChanges > 0 {
                pendingCameraChanges -= 1
            } else if isFollowingUser {
                isFollowingUser = false
            }
        }
        .onChange(of: offRoute.isOffRoute) { _, isOff in
            if isOff,
               !viewModel.isRerouting,
               !viewModel.isFlippingRoute,
               !viewModel.showWrongWayPrompt {
                viewModel.rerouteFromCurrentPosition()
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    offRoute.reset()
                }
            }
        }
        .onChange(of: viewModel.isFinished) { _, finished in
            if finished {
                router.navigate(to: .finishWalk(viewModel.session, viewModel.route))
            }
        }
    }

    // MARK: - Map

    private var navigationMap: some View {
        Map(position: $cameraPosition) {
            // Route polyline in Looopr green
            MapPolyline(coordinates: viewModel.activePolyline)
                .stroke(routeColor, lineWidth: 10)

            // Direction arrows along route
            ForEach(viewModel.routeArrows) { arrow in
                Annotation("", coordinate: arrow.coordinate) {
                    ZStack {
                        Circle()
                            .fill(routeColor)
                            .frame(width: 18, height: 18)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(arrow.bearing - 90 - currentMapHeading))
                    }
                    .opacity(arrowOpacity(for: arrow))
                }
            }

            // User location — directional arrow that lies flat on the map ground plane.
            // rotationEffect spins the arrow to face the heading; rotation3DEffect tilts
            // it backward by the camera pitch so it foreshortens correctly on the 3D map.
            if let location = viewModel.userLocation {
                Annotation("", coordinate: location) {
                    ZStack {
                        // White border (slightly larger)
                        NavigationArrowShape()
                            .fill(.white)
                            .frame(width: 44, height: 52)
                        // Dark green fill
                        NavigationArrowShape()
                            .fill(Color(hex: "#1B5E20"))
                            .frame(width: 36, height: 44)
                    }
                    // 1. Spin so tip faces the direction of travel
                    .rotationEffect(.degrees(viewModel.heading - currentMapHeading))
                    .animation(.easeOut(duration: 0.25), value: viewModel.heading)
                    .animation(.easeOut(duration: 0.25), value: currentMapHeading)
                    // 2. Tilt the arrow backward by the camera pitch so it lies flat
                    //    on the ground plane instead of standing upright in screen space
                    .rotation3DEffect(.degrees(-navigationPitch), axis: (x: 1, y: 0, z: 0))
                    // 3. Shadow of the foreshortened shape, cast downward onto the map
                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 4)
                }
            }

            // Next step target badge
            if let target = viewModel.currentStepCoordinate {
                Annotation("", coordinate: target) {
                    ZStack {
                        Circle().fill(.white).frame(width: 44, height: 44)
                            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                        Circle().fill(routeColor).frame(width: 36, height: 36)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(nextStepBearing - currentMapHeading))
                            .animation(.easeOut(duration: 0.25), value: nextStepBearing)
                            .animation(.easeOut(duration: 0.25), value: currentMapHeading)
                    }
                }
            }

            // Attraction POI markers
            ForEach(viewModel.route.attractions) { poi in
                Annotation(poi.name, coordinate: poi.location.clCoordinate) {
                    Image(systemName: "star.circle.fill")
                        .font(.caption)
                        .foregroundStyle(LoooprTheme.Colors.routeDot)
                        .background(Circle().fill(.white).padding(-1))
                }
            }

            // Food spot markers
            ForEach(viewModel.route.foodSpots) { poi in
                Annotation(poi.name, coordinate: poi.location.clCoordinate) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .background(Circle().fill(.white).padding(-2))
                        .shadow(color: .green.opacity(0.4), radius: 4)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls { MapCompass() }
    }

    // MARK: - Turn Instruction Banner

    private var turnInstructionBanner: some View {
        HStack(spacing: 12) {
            // Green square icon with turn arrow
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: "#1B5E20"))
                    .frame(width: 44, height: 44)
                Image(systemName: directionIcon(for: viewModel.currentInstruction))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                // Distance to next maneuver
                Text(viewModel.distanceToNextStep.formattedDistance())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                // Street / instruction
                Text(streetName(from: viewModel.currentInstruction))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)

                // Next instruction preview
                if let next = viewModel.nextInstruction {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Then \(next.lowercased())")
                            .lineLimit(1)
                    }
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                }
            }

            Spacer(minLength: 0)

            if viewModel.isRerouting {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.85)
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.118, green: 0.118, blue: 0.118).opacity(0.92))
        )
        .loooprShadow(LoooprTheme.Shadows.md)
    }

    // MARK: - POI Approaching Banner

    private func poiApproachingBanner(_ info: ApproachingPOIInfo) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("APPROACHING")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .tracking(0.5)
                Text(info.poi.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(info.distanceMeters.formattedDistance())
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("~\(info.estimatedMinutes) min")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "#1B5E20").opacity(0.92))
        )
        .loooprShadow(LoooprTheme.Shadows.md)
    }

    // MARK: - Off-route Banner

    private var bannerStack: some View {
        VStack(spacing: LoooprTheme.Spacing.xs) {
            OffRouteBannerView(
                isDetecting: offRoute.isDetecting,
                isRerouting: viewModel.isRerouting,
                distanceMeters: offRoute.offRouteDistanceMeters
            )
            .animation(.easeInOut, value: offRoute.isDetecting)
            .animation(.easeInOut, value: viewModel.isRerouting)
        }
    }

    // MARK: - Street Label

    private var streetLabel: some View {
        HStack {
            Spacer()
            Text(viewModel.currentStreetName)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(red: 0.118, green: 0.118, blue: 0.118).opacity(0.85))
                )
            Spacer()
        }
    }

    // MARK: - Stats Bar (bottom panel)

    private var statsBar: some View {
        VStack(spacing: 14) {
            // Progress bar + % label
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray5))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(
                                colors: [Color(hex: "#1B5E20"), Color(hex: "#66BB6A")],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: max(6, geo.size.width * progressFraction), height: 6)
                            .animation(.linear(duration: 1), value: progressFraction)
                    }
                }
                .frame(height: 6)

                HStack {
                    Spacer()
                    Text("\(Int(progressFraction * 100))% complete")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            // Stats row + stop button
            HStack(spacing: 0) {
                statItem(label: "Time", value: elapsedLabel)
                Divider().frame(height: 36)
                statItem(label: "Distance", value: viewModel.distanceWalked.formattedDistance())
                Divider().frame(height: 36)
                statItem(label: "Remaining", value: viewModel.remainingMeters.formattedDistance())
                Spacer(minLength: 12)
                stopButton
            }
        }
        .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 20, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 20,
                style: .continuous
            )
            .fill(LoooprTheme.Colors.surface)
            .loooprShadow(LoooprTheme.Shadows.sheet)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(LoooprTheme.Colors.textSecondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(LoooprTheme.Colors.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var stopButton: some View {
        Button { showStopConfirmation = true } label: {
            ZStack {
                Circle()
                    .fill(LoooprTheme.Colors.error)
                    .frame(width: 44, height: 44)
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            LoooprTheme.Colors.overlay.ignoresSafeArea()
            VStack(spacing: LoooprTheme.Spacing.sm) {
                ProgressView().tint(.white)
                Text(L10n.WalkNavigation.preparingNavigation)
                    .font(LoooprTheme.Typography.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(LoooprTheme.Spacing.lg)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.md))
        }
    }

    // MARK: - Food POI Toast

    private func poiToast(name: String, icon: String) -> some View {
        HStack(spacing: LoooprTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: LoooprTheme.Typography.lg))
                .foregroundStyle(LoooprTheme.Colors.routeDot)

            VStack(alignment: .leading, spacing: LoooprTheme.Spacing.xxs) {
                Text(name)
                    .font(LoooprTheme.Typography.headline)
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)
                Text(L10n.WalkNavigation.nearby)
                    .font(LoooprTheme.Typography.caption)
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
            }

            Spacer()

            HStack(spacing: LoooprTheme.Spacing.xs) {
                Button { viewModel.checkInFoodSpot() } label: {
                    Text(L10n.WalkNavigation.checkIn)
                        .font(LoooprTheme.Typography.subheadline)
                        .foregroundStyle(LoooprTheme.Colors.textOnPrimary)
                        .padding(.horizontal, LoooprTheme.Spacing.sm)
                        .padding(.vertical, LoooprTheme.Spacing.xs)
                        .background(LoooprTheme.Colors.primary)
                        .clipShape(Capsule())
                }
                Button { viewModel.dismissFoodCheckIn() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: LoooprTheme.Typography.xs, weight: .bold))
                        .foregroundStyle(LoooprTheme.Colors.textTertiary)
                }
            }
        }
        .padding(LoooprTheme.Spacing.md)
        .background(LoooprTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.md))
        .loooprShadow(LoooprTheme.Shadows.md)
        .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
    }

    // MARK: - Toast Capsule

    private func toastCapsule(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: LoooprTheme.Spacing.xxs) {
            Image(systemName: icon)
            Text(text)
        }
        .font(LoooprTheme.Typography.subheadline)
        .foregroundStyle(LoooprTheme.Colors.textOnPrimary)
        .padding(.horizontal, LoooprTheme.Spacing.md)
        .padding(.vertical, LoooprTheme.Spacing.sm)
        .background(color, in: Capsule())
        .loooprShadow(LoooprTheme.Shadows.sm)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Arrow animation

    private func arrowOpacity(for arrow: RouteArrow) -> Double {
        let count = viewModel.routeArrows.count
        let normalizedPos = count > 1 ? Double(arrow.index) / Double(count - 1) : 0.5
        var dist = abs(arrowPhase - normalizedPos)
        if dist > 0.5 { dist = 1.0 - dist }
        let brightness = max(0.0, 1.0 - dist / 0.18)
        return 0.70 + 0.30 * brightness
    }

    // MARK: - Instruction helpers

    private func directionIcon(for text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("sharp left") || lower.contains("sharply left") { return "arrow.turn.up.left" }
        if lower.contains("sharp right") || lower.contains("sharply right") { return "arrow.turn.up.right" }
        if lower.contains("slight left") || lower.contains("bear left") { return "arrow.up.left" }
        if lower.contains("slight right") || lower.contains("bear right") { return "arrow.up.right" }
        if lower.contains("left")  { return "arrow.turn.up.left" }
        if lower.contains("right") { return "arrow.turn.up.right" }
        if lower.contains("u-turn") || lower.contains("uturn") { return "arrow.uturn.down" }
        if lower.contains("arrive") || lower.contains("destination") { return "flag.fill" }
        if lower.contains("roundabout") || lower.contains("rotary") { return "arrow.triangle.turn.up.right.circle" }
        return "arrow.up"
    }

    private func streetName(from instruction: String) -> String {
        if let range = instruction.range(of: "onto ", options: .caseInsensitive) {
            return String(instruction[range.upperBound...])
        }
        return instruction
    }
}

private extension RouteToastStyle {
    var toastColor: Color {
        switch self {
        case .success:
            return LoooprTheme.Colors.success
        case .status:
            return LoooprTheme.Colors.warning
        case .error:
            return LoooprTheme.Colors.error
        }
    }
}

// MARK: - Navigation Arrow Shape

/// Pointed arrowhead with a notched tail — tip points UP at 0° rotation.
/// Designed to be paired with rotationEffect (heading) + rotation3DEffect (pitch)
/// so it foreshortens correctly and appears to lie flat on the map ground plane.
private struct NavigationArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tip    = CGPoint(x: rect.midX, y: rect.minY)
        let botL   = CGPoint(x: rect.minX, y: rect.maxY)
        let botR   = CGPoint(x: rect.maxX, y: rect.maxY)
        let notch  = CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.28)
        p.move(to: tip)
        p.addLine(to: botR)
        p.addLine(to: notch)
        p.addLine(to: botL)
        p.closeSubpath()
        return p
    }
}
