import MapKit
import SwiftUI

struct WalkDetailView: View {
    @State private var viewModel: WalkDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var sheetDetent: PresentationDetent = .fraction(0.45)
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var showShareError = false
    @State private var showGPXShareSheet = false
    @State private var showGPXError = false
    @State private var showHealthError = false

    init(session: WalkSession) {
        _viewModel = State(initialValue: WalkDetailViewModel(session: session))
    }

    @State private var showSheet = false
    /// Flips to true once the details sheet has actually reached the screen.
    @State private var sheetHasPresented = false
    /// Guards the retry below so a genuinely broken presentation can't loop.
    @State private var sheetPresentAttempts = 0

    var body: some View {
        ZStack(alignment: .top) {
            // Full-screen map
            routeMap
                .ignoresSafeArea()

            // Floating top buttons
            floatingButtons
        }
        .sheet(isPresented: $showSheet) {
            // The sheet binding went back to false. That means one of two
            // things:
            //
            // 1. The sheet had been on screen and the user swiped it away or
            //    hit back — navigate back to the list, as intended.
            // 2. The sheet never made it on screen. UIKit refuses to present
            //    while the navigation push is still animating and SwiftUI
            //    writes the binding straight back to false, which fires this
            //    closure. Calling dismiss() there popped this screen the
            //    instant it opened — the "first tap bounces back" bug.
            if sheetHasPresented {
                dismiss()
            } else {
                presentSheetWhenSettled()
            }
        } content: {
            sheetContent
                .onAppear { sheetHasPresented = true }
                .presentationDetents(
                    [.fraction(0.12), .fraction(0.45), .fraction(0.85)],
                    selection: $sheetDetent
                )
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.45)))
                .presentationCornerRadius(LoooprTheme.Radius.sheet)
        }
        .alert("Couldn't Share", isPresented: $showShareError) {
            Button(L10n.Misc.okay, role: .cancel) {}
        } message: {
            Text(viewModel.shareError ?? L10n.SavedRoutes.shareErrorMessage)
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            fitMapToRoute()
            presentSheetWhenSettled()
        }
    }

    /// Presents the details sheet once the navigation push has settled.
    ///
    /// Presenting straight from `onAppear` races the push animation: on a cold
    /// Activities tab (maps still warming up) the presentation gets dropped,
    /// and the resulting dismiss callback used to bounce the user back.
    private func presentSheetWhenSettled() {
        guard !sheetHasPresented, sheetPresentAttempts < 3 else { return }
        sheetPresentAttempts += 1

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !sheetHasPresented else { return }
            showSheet = true
        }
    }

    // MARK: - Floating Buttons

    private var floatingButtons: some View {
        HStack {
            // Back button
            Button {
                showSheet = false
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Spacer()

            // Share button
            Button {
                Task {
                    if let url = await viewModel.shareRoute() {
                        shareURL = url
                        showShareSheet = true
                    } else {
                        showShareError = true
                    }
                }
            } label: {
                Group {
                    if viewModel.isSharing {
                        ProgressView()
                            .tint(LoooprTheme.Colors.textPrimary)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(LoooprTheme.Colors.textPrimary)
                    }
                }
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
            }
            .disabled(viewModel.isSharing)
        }
        .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
        .padding(.top, LoooprTheme.Spacing.xs)
    }

    // MARK: - Map

    /// The walked GPS track as the main line, with the planned loop dashed
    /// faintly beneath it; older walks with no track show the plan alone.
    private var routeMap: some View {
        let planned = viewModel.session.pathCoordinates
        let shown = viewModel.session.displayCoordinates

        return Map(position: $mapCameraPosition, interactionModes: [.pan, .zoom, .rotate]) {
            if viewModel.session.hasTrack, planned.count >= 2 {
                MapPolyline(coordinates: planned)
                    .stroke(
                        viewModel.routeColor.opacity(0.35),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [8, 8])
                    )
            }

            MapPolyline(coordinates: shown)
                .stroke(viewModel.routeColor, lineWidth: 6)

            // Start dot
            if let start = shown.first {
                Annotation("Start", coordinate: start) {
                    ZStack {
                        Circle().fill(LoooprTheme.Colors.primary).frame(width: 14, height: 14)
                        Circle().stroke(.white, lineWidth: 2).frame(width: 14, height: 14)
                    }
                }
            }

            // End dot
            if let end = shown.last, shown.count > 1 {
                Annotation("End", coordinate: end) {
                    ZStack {
                        Circle().fill(LoooprTheme.Colors.routeDot).frame(width: 14, height: 14)
                        Circle().stroke(.white, lineWidth: 2).frame(width: 14, height: 14)
                    }
                }
            }

        }
        .mapStyle(.standard(elevation: .flat))
    }

    // MARK: - Map Camera

    private func fitMapToRoute() {
        // Frame both the plan and the walked track so neither is cut off
        // when they diverge.
        let coords = viewModel.session.pathCoordinates + viewModel.session.trackCoordinates
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

        // The bottom sheet covers roughly the lower 55% of the map.
        // The route must fit entirely in the visible top portion.
        let visibleFraction = 0.38
        let paddingMultiplier = 1.4

        let latDelta = max((rawLatDelta * paddingMultiplier) / visibleFraction, 0.006)
        let lngDelta = max(rawLngDelta * 2.0, 0.006)

        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)

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

    // MARK: - Sheet Content

    private var sheetContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LoooprTheme.Spacing.lg) {
                // Header
                sheetHeader

                // Stats grid
                statsGrid

                // Food stops visited
                if !viewModel.session.visitedFoodStops.isEmpty {
                    foodStopsSection
                }

                // Share CTA
                shareCTA

                if viewModel.canExportGPX {
                    exportGPXButton
                }

                if viewModel.canSaveToHealth {
                    saveToHealthButton
                }
            }
            .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
            .padding(.top, LoooprTheme.Spacing.sm)
            .padding(.bottom, LoooprTheme.Spacing.huge)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheetView(items: [
                    "\(L10n.Share.walkedRoute(viewModel.routeName)) 🚶‍♂️",
                    url
                ] as [Any])
            }
        }
        .sheet(isPresented: $showGPXShareSheet) {
            if let url = viewModel.gpxFileURL {
                ShareSheetView(items: [url])
            }
        }
        .alert(L10n.GPX.exportFailed, isPresented: $showGPXError) {
            Button(L10n.Misc.okay, role: .cancel) {}
        } message: {
            Text(viewModel.gpxError ?? L10n.GPX.noTrack)
        }
        .alert(L10n.Health.saveFailedTitle, isPresented: $showHealthError) {
            Button(L10n.Misc.okay, role: .cancel) {}
        } message: {
            if case .failed(let message) = viewModel.healthSaveState {
                Text(message)
            }
        }
    }

    // MARK: - Apple Health

    private var saveToHealthButton: some View {
        let state = viewModel.healthSaveState
        let isSaved = state == .saved
        let isSaving = state == .saving

        return Button {
            Task {
                await viewModel.saveToHealth()
                if case .failed = viewModel.healthSaveState { showHealthError = true }
            }
        } label: {
            HStack(spacing: LoooprTheme.Spacing.sm) {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                Text(isSaved ? L10n.Health.savedTitle : (isSaving ? L10n.Health.saving : L10n.Health.saveTitle))
                    .font(LoooprTheme.Typography.button)
            }
            .foregroundStyle(isSaved ? LoooprTheme.Colors.textSecondary : LoooprTheme.Colors.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, LoooprTheme.Spacing.md)
            .background((isSaved ? LoooprTheme.Colors.textSecondary : LoooprTheme.Colors.primary).opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.button))
        }
        .disabled(isSaved || isSaving)
        .padding(.top, LoooprTheme.Spacing.sm)
    }

    // MARK: - GPX export

    private var exportGPXButton: some View {
        Button {
            if viewModel.exportGPX() != nil {
                showGPXShareSheet = true
            } else {
                showGPXError = true
            }
        } label: {
            HStack(spacing: LoooprTheme.Spacing.sm) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                Text(L10n.GPX.exportTitle)
                    .font(LoooprTheme.Typography.button)
            }
            .foregroundStyle(LoooprTheme.Colors.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, LoooprTheme.Spacing.md)
            .background(LoooprTheme.Colors.primary.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.button))
        }
        .padding(.top, LoooprTheme.Spacing.sm)
    }

    // MARK: - Sheet Header

    private var sheetHeader: some View {
        VStack(alignment: .leading, spacing: LoooprTheme.Spacing.xxs) {
            Text(viewModel.routeName)
                .font(LoooprTheme.Typography.title)
                .foregroundStyle(LoooprTheme.Colors.textPrimary)

            HStack(spacing: LoooprTheme.Spacing.xs) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(LoooprTheme.Colors.textTertiary)
                Text(viewModel.walkDate)
                    .font(LoooprTheme.Typography.subheadline)
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)

                Text("·")
                    .foregroundStyle(LoooprTheme.Colors.textTertiary)

                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(LoooprTheme.Colors.textTertiary)
                Text(viewModel.walkTime)
                    .font(LoooprTheme.Typography.subheadline)
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
            }
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: LoooprTheme.Spacing.sm),
            count: viewModel.hasSteps && viewModel.hasElevation ? 2 : 2
        )

        return LazyVGrid(columns: columns, spacing: LoooprTheme.Spacing.sm) {
            WalkStatCard(
                icon: "figure.walk",
                value: viewModel.formattedDistance,
                label: L10n.FinishWalk.distance
            )

            WalkStatCard(
                icon: "clock",
                value: viewModel.formattedDuration,
                label: L10n.FinishWalk.duration
            )

            if viewModel.hasElevation {
                WalkStatCard(
                    icon: "arrow.up.right",
                    value: viewModel.formattedElevation,
                    label: L10n.FinishWalk.elevation
                )
            }

            if viewModel.hasSteps {
                WalkStatCard(
                    icon: "shoe.2",
                    value: viewModel.formattedSteps,
                    label: L10n.Profile.steps
                )
            }
        }
    }

    // MARK: - Food Stops Section

    private var foodStopsSection: some View {
        VStack(alignment: .leading, spacing: LoooprTheme.Spacing.sm) {
            Label("Places Visited", systemImage: "fork.knife")
                .font(LoooprTheme.Typography.headline)
                .foregroundStyle(LoooprTheme.Colors.textPrimary)

            ForEach(viewModel.session.visitedFoodStops) { stop in
                HStack(spacing: LoooprTheme.Spacing.sm) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title3)
                        .foregroundStyle(LoooprTheme.Colors.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(stop.name)
                            .font(LoooprTheme.Typography.body)
                            .foregroundStyle(LoooprTheme.Colors.textPrimary)

                        Text(stopTimeFormatted(stop.checkedInAt))
                            .font(LoooprTheme.Typography.caption)
                            .foregroundStyle(LoooprTheme.Colors.textTertiary)
                    }

                    Spacer()
                }
                .padding(LoooprTheme.Spacing.sm)
                .background(LoooprTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.sm))
                .loooprShadow(LoooprTheme.Shadows.sm)
            }
        }
    }

    // MARK: - Share CTA

    private var shareCTA: some View {
        Button {
            Task {
                if let url = await viewModel.shareRoute() {
                    shareURL = url
                    showShareSheet = true
                } else {
                    showShareError = true
                }
            }
        } label: {
            HStack(spacing: LoooprTheme.Spacing.sm) {
                if viewModel.isSharing {
                    ProgressView()
                        .tint(LoooprTheme.Colors.textOnPrimary)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(L10n.Share.shareThisLooopr)
                    .font(LoooprTheme.Typography.button)
            }
            .foregroundStyle(LoooprTheme.Colors.textOnPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, LoooprTheme.Spacing.md)
            .background(LoooprTheme.Colors.primary)
            .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.button))
        }
        .disabled(viewModel.isSharing)
    }

    // MARK: - Helpers

    private func stopTimeFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return L10n.WalkDetail.checkedInAt(formatter.string(from: date))
    }
}

// MARK: - Walk Stat Card

private struct WalkStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: LoooprTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: LoooprTheme.Typography.lg))
                .foregroundStyle(LoooprTheme.Colors.primary)

            Text(value)
                .font(LoooprTheme.Typography.title)
                .foregroundStyle(LoooprTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(LoooprTheme.Typography.caption)
                .foregroundStyle(LoooprTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LoooprTheme.Spacing.md)
        .background(LoooprTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
        .loooprShadow(LoooprTheme.Shadows.sm)
    }
}

