import SwiftUI
import MapKit

struct WalkNavigationView: View {
    @Environment(AppRouter.self) private var router
    @State private var viewModel: WalkNavigationViewModel
    @State private var offRoute = OffRouteViewModel()
    @State private var showStopConfirmation = false
    @State private var cameraPosition: MapCameraPosition
    /// While true the camera tracks the user: centred just behind the puck
    /// and rotated to the compass heading, so "up" on screen is always the
    /// direction you're walking (Google Maps walking-mode behaviour).
    /// Cleared as soon as the user drags the map; restored by the re-center pill.
    @State private var isFollowingUser = true
    /// Camera distance used while following. Starts at `navigationDistance`
    /// and adopts whatever zoom the user pinches to, so following doesn't
    /// keep snapping their zoom level back.
    @State private var followDistance: CLLocationDistance = 600
    /// Tracks the live map camera heading so the user-location arrow can be
    /// rotated relative to the map.
    @State private var currentMapHeading: CLLocationDirection = 0
    /// 0→1 cycling value that drives the "marching" wave along route arrows.
    @State private var arrowPhase: Double = 0
    /// Drives `arrowPhase`. Stored so it can be invalidated in `onDisappear` —
    /// an anonymous scheduled timer would keep firing (and keep this view
    /// alive) for the rest of the app session.
    @State private var arrowTimer: Timer?

    private let routeColor = Color(hex: "#66BB6A")

    // MARK: - Camera constants (60-70° tilt, 500-800m distance)
    private let navigationDistance: CLLocationDistance = 600
    private let navigationPitch: Double = 65
    /// How far ahead of the user (along the heading) the camera aims, in
    /// metres. Pushes the puck into the lower part of the screen so more of
    /// the upcoming route is visible — the same framing Google Maps uses.
    private let navigationLookAhead: CLLocationDistance = 45

    init(route: Route) {
        let viewModel = WalkNavigationViewModel(route: route)
        _viewModel = State(initialValue: viewModel)
        // Face down the route from the very first frame, before GPS/compass
        // have reported anything.
        _cameraPosition = State(initialValue: .camera(MapCamera(
            centerCoordinate: route.startLocation.clCoordinate
                .coordinate(at: 45, bearing: viewModel.heading),
            distance: 600,
            heading: viewModel.heading,
            pitch: 65
        )))
    }

    // MARK: - Camera helpers

    private func navigationCamera(at coordinate: CLLocationCoordinate2D,
                                  heading: CLLocationDirection) -> MapCamera {
        MapCamera(centerCoordinate: coordinate.coordinate(at: navigationLookAhead, bearing: heading),
                  distance: followDistance,
                  heading: heading,
                  pitch: navigationPitch)
    }

    private var nextStepBearing: Double { viewModel.currentRouteBearing }

    /// Re-aims the camera at the user with the current compass heading.
    /// Called on every location *and* heading change while following, so
    /// the map keeps rotating with the user even when they stand still and
    /// turn around.
    private func updateFollowCamera(duration: Double) {
        guard isFollowingUser, let location = viewModel.userLocation else { return }
        withAnimation(.easeOut(duration: duration)) {
            cameraPosition = .camera(navigationCamera(at: location, heading: viewModel.heading))
        }
    }

    private func snapToNavigationCamera() {
        isFollowingUser = true
        followDistance = navigationDistance
        updateFollowCamera(duration: 0.6)
    }

    private func stopFollowingUser() {
        guard isFollowingUser else { return }
        isFollowingUser = false
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
                        .accessibilityLabel(Text(L10n.WalkNavigation.recenter))
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
            Button(L10n.WalkNavigation.saveAndFinish) { viewModel.finish() }
            Button(L10n.WalkNavigation.endWalkButton, role: .destructive) {
                viewModel.stop()
                router.popToRoot()
            }
            Button(L10n.Misc.cancel, role: .cancel) { }
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
            if arrowTimer == nil {
                arrowTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    arrowPhase = (arrowPhase + 0.033).truncatingRemainder(dividingBy: 1.0)
                }
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            arrowTimer?.invalidate()
            arrowTimer = nil
        }
        .onChange(of: viewModel.userLocation) { _, location in
            guard let location else { return }
            offRoute.check(
                userLocation: location,
                horizontalAccuracy: viewModel.currentAccuracy,
                routePolyline: viewModel.activePolyline
            )
            updateFollowCamera(duration: 0.4)
        }
        .onChange(of: viewModel.heading) { _, _ in
            updateFollowCamera(duration: 0.3)
        }
        .onMapCameraChange(frequency: .continuous) { context in
            currentMapHeading = context.camera.heading
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            guard isFollowingUser, let location = viewModel.userLocation else { return }
            // Safety net in case the drag gesture below doesn't fire: while
            // following, the camera always settles within `navigationLookAhead`
            // of the user, so a centre far away from them was a user pan.
            // (Threshold is deliberately generous so an interrupted
            // follow-animation or a GPS jump can never trip it.)
            if context.camera.centerCoordinate.distance(to: location) > 250 {
                stopFollowingUser()
                return
            }
            // Pinch-zoom while following: keep the user's chosen distance.
            // Our own follow moves never change distance, so any change
            // here came from the user.
            let distance = context.camera.distance
            if abs(distance - followDistance) > 15 {
                followDistance = min(max(distance, 150), 2_000)
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
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
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

            // User location — shaded "puck" marker (Google Maps style).
            // The chevron stays upright in screen space at constant size so it can
            // never distort with camera pitch; the pitch-squashed halo + shadow
            // ellipses on the ground plane beneath it are what anchor it in 3D.
            if let location = viewModel.userLocation {
                Annotation("", coordinate: location) {
                    UserPuckMarker(
                        rotation: viewModel.heading - currentMapHeading,
                        pitchSquash: cos(navigationPitch * .pi / 180)
                    )
                    .animation(.easeOut(duration: 0.25), value: viewModel.heading)
                    .animation(.easeOut(duration: 0.25), value: currentMapHeading)
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
        // Any finger drag on the map hands camera control to the user until
        // they tap the re-center pill. `simultaneousGesture` lets MapKit keep
        // handling the pan itself; we only observe it.
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { _ in stopFollowingUser() }
        )
    }

    // MARK: - Turn Instruction Banner

    private var turnInstructionBanner: some View {
        HStack(spacing: 12) {
            // Green square icon with turn arrow
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: "#1B5E20"))
                    .frame(width: 44, height: 44)
                Image(systemName: directionIcon(for: viewModel.currentInstruction, step: viewModel.currentStep))
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
                Text(streetName(from: viewModel.currentInstruction, step: viewModel.currentStep))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)

                // Next instruction preview
                if let next = viewModel.nextInstruction {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 10, weight: .semibold))
                        Text(L10n.WalkNavigation.thenInstruction(next.lowercased()))
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
                Text(L10n.WalkNavigation.approaching)
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
                Text(L10n.WalkNavigation.approximateMinutes(info.estimatedMinutes))
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
                    Text(L10n.WalkNavigation.percentComplete(Int(progressFraction * 100)))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            // Stats row + stop button
            HStack(spacing: 0) {
                statItem(label: L10n.WalkNavigation.statTime, value: elapsedLabel)
                Divider().frame(height: 36)
                statItem(label: L10n.WalkNavigation.statDistance, value: viewModel.distanceWalked.formattedDistance())
                Divider().frame(height: 36)
                statItem(label: L10n.WalkNavigation.statRemaining, value: viewModel.remainingMeters.formattedDistance())
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

    private func directionIcon(for text: String, step: NavigationStep?) -> String {
        let turn = step.map(NavigationSemantics.turn(for:)) ?? NavigationSemantics.turn(fromText: text)
        return NavigationSemantics.sfSymbol(for: turn)
    }

    private func streetName(from instruction: String, step: NavigationStep?) -> String {
        NavigationSemantics.streetLine(instruction: instruction, streetName: step?.streetName)
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

// MARK: - User Puck Marker

/// User-location marker: an upright, shaded chevron floating over a
/// pitch-squashed halo + contact shadow on the map's ground plane.
///
/// Design rationale: a flat shape tilted onto the ground plane reads as a
/// "sticker" next to 3D buildings because it has no volume or lighting.
/// Instead the chevron stays billboarded (constant screen size, never
/// distorted by pitch) and gets its 3D feel from (a) a tip→tail gradient
/// and top-edge highlight suggesting volume, and (b) squashed ground
/// ellipses beneath it that anchor it in the scene — the same trick
/// Google Maps uses for its navigation puck.
private struct UserPuckMarker: View {
    /// Degrees to spin the chevron so its tip faces the direction of travel
    /// (heading minus current camera heading).
    let rotation: Double
    /// cos(camera pitch in radians) — vertical squash factor applied to
    /// ground-plane elements so they foreshorten with the 3D camera.
    let pitchSquash: Double

    var body: some View {
        ZStack {
            // Soft "you are here" halo lying on the map surface.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#1B5E20").opacity(0.28), .clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: 26
                    )
                )
                .frame(width: 52, height: max(52 * pitchSquash, 10))

            // Contact shadow directly beneath the chevron.
            Ellipse()
                .fill(.black.opacity(0.30))
                .frame(width: 26, height: max(26 * pitchSquash, 6))
                .blur(radius: 3)
                .offset(y: 2)

            // The chevron itself — upright, floating just above its shadow.
            ZStack {
                // White outline (slightly larger, matches app marker style).
                NavigationArrowShape()
                    .fill(.white)
                    .frame(width: 40, height: 46)
                // Shaded green fill: lighter at the tip, darker at the tail,
                // so the marker reads as lit from above while it rotates.
                NavigationArrowShape()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#43A047"), Color(hex: "#1B5E20")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 32, height: 38)
                    .overlay(
                        // Faint highlight along the leading edges for volume.
                        NavigationArrowShape()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.55), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                ),
                                lineWidth: 1.5
                            )
                            .frame(width: 32, height: 38)
                    )
            }
            .rotationEffect(.degrees(rotation))
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
            .offset(y: -10)
        }
    }
}

// MARK: - Navigation Arrow Shape

/// Pointed arrowhead with a notched tail — tip points UP at 0° rotation.
/// Spin with rotationEffect (heading); used upright inside UserPuckMarker
/// and for the small direction arrows along the route.
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
