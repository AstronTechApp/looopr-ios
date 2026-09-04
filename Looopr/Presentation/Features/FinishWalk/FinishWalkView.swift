import SwiftUI
import MapKit

struct FinishWalkView: View {
    @Environment(AppRouter.self) private var router
    @State private var viewModel: FinishWalkViewModel
    @State private var showShareSheet = false
    @State private var showShareError = false
    @State private var showGPXShareSheet = false
    @State private var showGPXError = false
    @State private var appear = false
    @State private var statsAppeared = false

    init(session: WalkSession, route: Route) {
        _viewModel = State(initialValue: FinishWalkViewModel(session: session, route: route))
    }

    // MARK: - Computed

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: viewModel.session.startedAt)
    }

    private var avgPaceLabel: String {
        let distanceInUnit = viewModel.session.distanceKilometers.inPreferredUnit
        let minutes = viewModel.session.durationSeconds / 60
        guard distanceInUnit > 0 else { return "--" }
        let pace = minutes / distanceInUnit
        let paceMinutes = Int(pace)
        let paceSeconds = Int((pace - Double(paceMinutes)) * 60)
        return String(format: "%d:%02d /\(Double.distanceUnit)", paceMinutes, paceSeconds)
    }

    /// Elevation measured by the barometer during this walk. An em dash on
    /// hardware without one — better than a number nobody measured, which is
    /// what this showed before.
    private var elevationLabel: String {
        guard let gain = viewModel.session.elevationGainMeters else { return "—" }
        return gain.formattedElevation()
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            LoooprTheme.Colors.background
                .ignoresSafeArea()

            // Teal fill behind status bar — sits underneath ScrollView
            LoooprTheme.Colors.primary
                .frame(height: 0)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(spacing: 0) {
                    // Celebration header with confetti
                    celebrationHeader

                    // Stats card (overlaps header)
                    statsCard
                        .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                        .offset(y: -LoooprTheme.Spacing.lg)

                    // Content below stats
                    VStack(spacing: LoooprTheme.Spacing.lg) {
                        // Route map preview
                        routeMapSection
                            .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)

                        // Food stops
                        if viewModel.hasVisitedFoodStops {
                            foodStopsSection
                        }

                        // Feedback
                        feedbackSection
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 30)

                        // Action buttons
                        actionButtons
                            .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                    }
                    .padding(.bottom, LoooprTheme.Spacing.xxxl)
                }
            }

            // Confetti overlay
            if appear {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar, .tabBar)
        // Save immediately — a swipe-back, crash, or force-quit on this
        // screen must never lose the walk.
        .onAppear { viewModel.persistWalkIfNeeded() }
        .onDisappear { viewModel.finalizeFeedbackIfNeeded() }
        .task {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appear = true
            }
            // Stagger stats
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3)) {
                statsAppeared = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = viewModel.shareURL {
                ShareSheetView(items: [
                    viewModel.shareText(),
                    url
                ] as [Any])
            } else {
                ShareSheetView(items: [viewModel.shareText()])
            }
        }
        .alert("Couldn't Share", isPresented: $showShareError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.shareError ?? "Something went wrong. Please try again.")
        }
        .sheet(isPresented: $showGPXShareSheet) {
            if let url = viewModel.gpxFileURL {
                ShareSheetView(items: [url])
            }
        }
        .alert(L10n.GPX.exportFailed, isPresented: $showGPXError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.gpxError ?? L10n.GPX.noTrack)
        }
    }

    // MARK: - Celebration Header

    private var celebrationHeader: some View {
        VStack(spacing: LoooprTheme.Spacing.sm) {
            Spacer().frame(height: LoooprTheme.Spacing.xxxl)

            // Logo with scale animation
            Image("LoooprLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .colorMultiply(.white)
                .scaleEffect(appear ? 1 : 0.3)
                .opacity(appear ? 1 : 0)

            Text(L10n.FinishWalk.title)
                .font(LoooprTheme.Typography.largeTitle)
                .foregroundStyle(.white)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)

            Text("\(viewModel.route.displayName) · \(formattedDate)")
                .font(LoooprTheme.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .opacity(appear ? 1 : 0)

            Spacer()
        }
        .frame(height: 320)
        .frame(maxWidth: .infinity)
        .background(LoooprTheme.Colors.primary)
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: LoooprTheme.Spacing.md) {
            statCell(
                icon: "figure.walk",
                value: viewModel.formattedDistance,
                label: L10n.FinishWalk.distance,
                index: 0
            )
            statCell(
                icon: "clock",
                value: viewModel.formattedDuration,
                label: L10n.FinishWalk.duration,
                index: 1
            )
            statCell(
                icon: "speedometer",
                value: avgPaceLabel,
                label: L10n.FinishWalk.avgPace,
                index: 2
            )
            statCell(
                icon: "arrow.up.right",
                value: elevationLabel,
                label: L10n.FinishWalk.elevation,
                index: 3
            )
        }
        .padding(LoooprTheme.Spacing.md)
        .background(LoooprTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
        .loooprShadow(LoooprTheme.Shadows.md)
    }

    private func statCell(icon: String, value: String, label: String, index: Int) -> some View {
        VStack(spacing: LoooprTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(LoooprTheme.Colors.primary)

            Text(value)
                .font(LoooprTheme.Typography.title)
                .foregroundStyle(LoooprTheme.Colors.textPrimary)

            Text(label)
                .font(LoooprTheme.Typography.caption)
                .foregroundStyle(LoooprTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LoooprTheme.Spacing.sm)
        .scaleEffect(statsAppeared ? 1 : 0.8)
        .opacity(statsAppeared ? 1 : 0)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.1),
            value: statsAppeared
        )
    }

    // MARK: - Route Map Preview

    /// Draws the GPS track that was actually walked, with the planned loop
    /// dashed faintly beneath it for comparison. Walks with no recorded
    /// track (before track recording existed) show the planned loop alone.
    private var routeMapSection: some View {
        let planned = viewModel.route.pathCoordinates
        let shown = viewModel.session.displayCoordinates

        return Map {
            if viewModel.session.hasTrack, planned.count >= 2 {
                MapPolyline(coordinates: planned)
                    .stroke(
                        viewModel.routeColor.opacity(0.35),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 6])
                    )
            }

            MapPolyline(coordinates: shown)
                .stroke(viewModel.routeColor, lineWidth: 3)

            if let start = shown.first {
                Annotation("", coordinate: start) {
                    Circle()
                        .fill(LoooprTheme.Colors.primary)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
    }

    // MARK: - Food Stops

    private var foodStopsSection: some View {
        VStack(alignment: .leading, spacing: LoooprTheme.Spacing.sm) {
            Text(L10n.FinishWalk.breaks)
                .font(LoooprTheme.Typography.label)
                .foregroundStyle(LoooprTheme.Colors.textTertiary)
                .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)

            VStack(spacing: LoooprTheme.Spacing.xs) {
                ForEach(viewModel.visitedFoodStops) { visit in
                    HStack(spacing: LoooprTheme.Spacing.sm) {
                        Image(systemName: "fork.knife.circle.fill")
                            .foregroundStyle(LoooprTheme.Colors.routeDot)
                        Text(L10n.FinishWalk.breakAt(visit.name))
                            .font(LoooprTheme.Typography.subheadline)
                            .foregroundStyle(LoooprTheme.Colors.textPrimary)
                        Spacer()
                    }
                    .padding(LoooprTheme.Spacing.sm)
                    .background(LoooprTheme.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.sm))
                }
            }
            .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 30)
    }

    // MARK: - Feedback

    private var feedbackSection: some View {
        FeedbackSectionView(
            rating: Bindable(viewModel).rating,
            selectedTags: Bindable(viewModel).selectedTags,
            comment: Bindable(viewModel).feedbackComment,
            accentColor: LoooprTheme.Colors.primary,
            onToggleTag: { viewModel.toggleTag($0) }
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: LoooprTheme.Spacing.sm) {
            // Save route (bookmark for future walks)
            Button {
                viewModel.toggleSavedRoute()
            } label: {
                Label(
                    viewModel.isRouteSaved ? L10n.FinishWalk.routeSaved : L10n.FinishWalk.saveRoute,
                    systemImage: viewModel.isRouteSaved ? "bookmark.fill" : "bookmark"
                )
            }
            .buttonStyle(.loooprPrimary)
            .sensoryFeedback(.success, trigger: viewModel.isRouteSaved)

            // Share route (upload + system share sheet)
            Button {
                Task {
                    if let _ = await viewModel.shareRoute() {
                        showShareSheet = true
                    } else {
                        showShareError = true
                    }
                }
            } label: {
                HStack(spacing: LoooprTheme.Spacing.xs) {
                    if viewModel.isSharingRoute {
                        ProgressView().tint(LoooprTheme.Colors.primary)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text(L10n.FinishWalk.shareRoute)
                }
            }
            .buttonStyle(.loooprSecondary)
            .disabled(viewModel.isSharingRoute)

            // Export the walked GPS track as GPX (Strava, Komoot, Files …).
            // Only offered when a track was actually recorded.
            if viewModel.canExportGPX {
                Button {
                    if viewModel.exportGPX() != nil {
                        showGPXShareSheet = true
                    } else {
                        showGPXError = true
                    }
                } label: {
                    Label(L10n.FinishWalk.exportGPX, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                }
                .buttonStyle(.loooprSecondary)
            }

            // Apple Health — only shown once an automatic save has happened
            // (or failed), so the screen stays quiet for users who have it off.
            healthStatusLine

            // Go Home (feedback is attached to the already-saved walk here)
            Button {
                viewModel.finalizeFeedbackIfNeeded()
                router.popToRoot()
            } label: {
                Text(L10n.FinishWalk.goHome)
                    .font(LoooprTheme.Typography.subheadline)
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
            }
            .padding(.top, LoooprTheme.Spacing.xs)
        }
    }

    // MARK: - Apple Health status

    @ViewBuilder
    private var healthStatusLine: some View {
        switch viewModel.healthSaveState {
        case .idle:
            EmptyView()
        case .saving:
            Label(L10n.Health.saving, systemImage: "heart")
                .font(LoooprTheme.Typography.caption)
                .foregroundStyle(LoooprTheme.Colors.textTertiary)
        case .saved:
            Label(L10n.Health.savedTitle, systemImage: "heart.fill")
                .font(LoooprTheme.Typography.caption)
                .foregroundStyle(LoooprTheme.Colors.textSecondary)
        case .failed(let message):
            Label(message, systemImage: "heart.slash")
                .font(LoooprTheme.Typography.caption)
                .foregroundStyle(LoooprTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Confetti View

private struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    private static let colors: [Color] = [
        LoooprTheme.Colors.primary,
        LoooprTheme.Colors.routeDot,
        LoooprTheme.Colors.primaryLight,
        LoooprTheme.Colors.warning,
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                particles = (0..<30).map { _ in
                    ConfettiParticle(
                        color: Self.colors.randomElement()!,
                        size: CGFloat.random(in: 4...10),
                        position: CGPoint(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: -50...geo.size.height * 0.3)
                        ),
                        opacity: 1
                    )
                }

                // Animate particles falling and fading
                withAnimation(.easeOut(duration: 2.5)) {
                    particles = particles.map { p in
                        var updated = p
                        updated.position = CGPoint(
                            x: p.position.x + CGFloat.random(in: -60...60),
                            y: p.position.y + CGFloat.random(in: 200...500)
                        )
                        updated.opacity = 0
                        return updated
                    }
                }
            }
        }
    }
}

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    var position: CGPoint
    var opacity: Double
}
