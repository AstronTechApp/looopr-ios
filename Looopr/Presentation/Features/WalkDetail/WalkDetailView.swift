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

    init(session: WalkSession) {
        _viewModel = State(initialValue: WalkDetailViewModel(session: session))
    }

    @State private var showSheet = false

    var body: some View {
        ZStack(alignment: .top) {
            // Full-screen map
            routeMap
                .ignoresSafeArea()

            // Floating top buttons
            floatingButtons
        }
        .sheet(isPresented: $showSheet) {
            // If the sheet is dismissed by swipe, navigate back
            dismiss()
        } content: {
            sheetContent
                .presentationDetents(
                    [.fraction(0.12), .fraction(0.45), .fraction(0.85)],
                    selection: $sheetDetent
                )
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.45)))
                .presentationCornerRadius(LoooprTheme.Radius.sheet)
        }
        .alert("Couldn't Share", isPresented: $showShareError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.shareError ?? "Something went wrong. Please try again.")
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            fitMapToRoute()
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

    private var routeMap: some View {
        Map(position: $mapCameraPosition, interactionModes: [.pan, .zoom, .rotate]) {
            MapPolyline(coordinates: viewModel.session.pathCoordinates)
                .stroke(viewModel.routeColor, lineWidth: 6)

            // Start dot
            if let start = viewModel.session.pathCoordinates.first {
                Annotation("Start", coordinate: start) {
                    ZStack {
                        Circle().fill(LoooprTheme.Colors.primary).frame(width: 14, height: 14)
                        Circle().stroke(.white, lineWidth: 2).frame(width: 14, height: 14)
                    }
                }
            }

            // End dot
            if let end = viewModel.session.pathCoordinates.last,
               viewModel.session.pathCoordinates.count > 1 {
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
        let coords = viewModel.session.pathCoordinates
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
            }
            .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
            .padding(.top, LoooprTheme.Spacing.sm)
            .padding(.bottom, LoooprTheme.Spacing.huge)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheetView(items: [
                    "Check out the \(viewModel.routeName) I walked on Looopr! 🚶‍♂️",
                    url
                ] as [Any])
            }
        }
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
                label: "Distance"
            )

            WalkStatCard(
                icon: "clock",
                value: viewModel.formattedDuration,
                label: "Duration"
            )

            if viewModel.hasElevation {
                WalkStatCard(
                    icon: "arrow.up.right",
                    value: viewModel.formattedElevation,
                    label: "Elevation"
                )
            }

            if viewModel.hasSteps {
                WalkStatCard(
                    icon: "shoe.2",
                    value: viewModel.formattedSteps,
                    label: "Steps"
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
                Text("Share This Looopr")
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
        return "Checked in at \(formatter.string(from: date))"
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

