import SwiftUI
import MapKit

struct RouteSelectionView: View {
    @Environment(AppRouter.self) private var router
    @State private var viewModel: RouteSelectionViewModel
    @State private var hasAppeared = false

    init(walkDurationMinutes: Int = 30, customLocation: CustomRouteLocation? = nil) {
        _viewModel = State(
            initialValue: RouteSelectionViewModel(
                walkDurationMinutes: walkDurationMinutes,
                customLocation: customLocation
            )
        )
    }

    var body: some View {
        ZStack {
            LoooprTheme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: LoooprTheme.Spacing.lg) {
                    headerSection
                    durationChip
                    // TODO: v2 — Route filter tabs (Quiet, Parks, Scenic, Cafés)
                    // Restore when route generation tags routes by character type
                    routeList
                }
                .padding(.bottom, LoooprTheme.Spacing.huge + LoooprTheme.Spacing.xxl)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadRoutes()
            withAnimation(LoooprTheme.Animation.gentle) {
                hasAppeared = true
            }
        }
        // Routes stream in one at a time. Reveal the list on the first
        // arrival instead of waiting for generation to finish — on the
        // free tier that can be a minute or more of serial MKDirections
        // calls, and the user was staring at skeletons the whole time.
        .onChange(of: viewModel.routes.isEmpty) { _, isEmpty in
            if !isEmpty && !hasAppeared {
                withAnimation(LoooprTheme.Animation.gentle) {
                    hasAppeared = true
                }
            }
        }
    }

    // MARK: - Header (Glassmorphic)

    private var headerSection: some View {
        HStack(spacing: 14) {
            Button {
                router.pop()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(LoooprTheme.Colors.surfaceSecondary)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.RouteSelection.yourRoutes)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .tracking(-0.5)
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)

                Text(viewModel.subtitle.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(LoooprTheme.Colors.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
        .padding(.top, LoooprTheme.Spacing.xs)
    }

    // MARK: - Duration Context Chip

    private var durationChip: some View {
        HStack {
            Text("\(RouteSelectionViewModel.formattedMinutes(viewModel.walkDurationMinutes)) \(L10n.RouteSelection.walkLabel)")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Color(hex: "#7b3100"))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(LoooprTheme.Colors.secondaryContainer)
                .clipShape(Capsule())

            Spacer()
        }
        .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
    }

    // MARK: - Route List

    @ViewBuilder
    private var routeList: some View {
        // Skeletons only while nothing has arrived yet. Once the first
        // route streams in, show it — the rest fill in underneath.
        if viewModel.isLoading && viewModel.routes.isEmpty {
            VStack(spacing: LoooprTheme.Spacing.xl) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonRouteCard()
                }
            }
            .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
        } else if viewModel.routes.isEmpty {
            VStack(spacing: LoooprTheme.Spacing.sm) {
                Image(systemName: "map")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(LoooprTheme.Colors.textTertiary)

                Text(L10n.RouteSelection.noRoutesFound)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, LoooprTheme.Spacing.huge)
        } else {
            LazyVStack(spacing: LoooprTheme.Spacing.xl) {
                ForEach(Array(viewModel.routes.enumerated()), id: \.element.id) { index, route in
                    RouteSelectionCard(
                        route: route,
                        onTapCard: {
                            ServiceContainer.shared.resolve(AnalyticsTracking.self).track(
                                .routeSelected(
                                    routeId: route.id,
                                    durationMinutes: route.durationMinutes,
                                    distanceKm: route.distanceKilometers
                                )
                            )
                            router.navigate(to: .routeDetail(route))
                        },
                        onStartWalk: { router.navigate(to: .walkNavigation(route)) }
                    )
                    .offset(y: hasAppeared ? 0 : 40)
                    .opacity(hasAppeared ? 1 : 0)
                    .animation(
                        LoooprTheme.Animation.gentle.delay(Double(index) * 0.08),
                        value: hasAppeared
                    )
                }

                if viewModel.isLoading {
                    findingMoreRow
                } else if viewModel.isFreeTier {
                    UpgradeCard {
                        // PaywallView tracks `.paywallShown` itself on appear.
                        router.presentPaywall()
                    }
                }
            }
            .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
        }
    }

    private var findingMoreRow: some View {
        HStack(spacing: LoooprTheme.Spacing.sm) {
            ProgressView()
                .tint(LoooprTheme.Colors.primary)
            Text(L10n.RouteSelection.findingMore)
                .font(LoooprTheme.Typography.subheadline)
                .foregroundStyle(LoooprTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LoooprTheme.Spacing.md)
    }
}

// MARK: - Upgrade Card (free tier)

/// Shown under the free-tier routes once generation finishes. Deliberately
/// a card in the same family as the route cards rather than a banner: it
/// reads as "here's what the next slot would be", not as an ad.
private struct UpgradeCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: LoooprTheme.Spacing.md) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(LoooprTheme.Colors.primary)
                    .frame(width: 44, height: 44)
                    .background(LoooprTheme.Colors.primaryLight)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: LoooprTheme.Spacing.xxs) {
                    Text(L10n.RouteSelection.upgradeTitle)
                        .font(LoooprTheme.Typography.headline)
                        .foregroundStyle(LoooprTheme.Colors.textPrimary)

                    Text(L10n.RouteSelection.upgradeBody)
                        .font(LoooprTheme.Typography.subheadline)
                        .foregroundStyle(LoooprTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 4) {
                        Text(L10n.RouteSelection.upgradeCTA)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(LoooprTheme.Typography.button)
                    .foregroundStyle(LoooprTheme.Colors.primary)
                    .padding(.top, LoooprTheme.Spacing.xs)
                }

                Spacer(minLength: 0)
            }
            .padding(LoooprTheme.Spacing.md)
            .background(LoooprTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: LoooprTheme.Radius.lg)
                    .strokeBorder(LoooprTheme.Colors.primaryLight, lineWidth: 1.5)
            )
            .loooprShadow(LoooprTheme.Shadows.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Route Selection Card (Organic Editorial)

private struct RouteSelectionCard: View {
    let route: Route
    let onTapCard: () -> Void
    let onStartWalk: () -> Void

    private var routeColor: Color {
        AppTheme.routeColor(for: route.colorIndex)
    }

    private var difficultyLabel: String {
        route.difficulty.localizedLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Map Image with Difficulty Badge ──
            Button(action: onTapCard) {
                ZStack(alignment: .topTrailing) {
                    RouteMapPreview(route: route, color: routeColor)
                        .frame(height: 200)
                        .clipped()

                    // Subtle bottom gradient for depth
                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.12),
                                Color.clear
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .frame(height: 60)
                    }

                    // Glassmorphic difficulty badge
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(L10n.RouteSelection.difficulty)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(LoooprTheme.Colors.textSecondary)

                        Text(difficultyLabel)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(LoooprTheme.Colors.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(14)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ── Content Area ──
            VStack(alignment: .leading, spacing: LoooprTheme.Spacing.md) {
                // Route name — editorial bold
                Text(route.displayName)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .tracking(-0.5)
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)
                    .lineLimit(2)

                // Description
                Text("\(route.paceAdjustedDurationLabel) \(L10n.RouteSelection.loopLabel)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)

                // Ferry notice — shown when the route includes a ferry crossing
                if route.containsFerry {
                    HStack(spacing: 6) {
                        Image(systemName: "ferry")
                            .font(.system(size: 12, weight: .semibold))
                        Text(L10n.RouteSelection.includesFerry)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.3)
                    }
                    .foregroundStyle(Color(hex: "#0D47A1"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#BBDEFB").opacity(0.5))
                    .clipShape(Capsule())
                }

                // ── Stats Grid ──
                HStack(spacing: 0) {
                    RouteStatItem(
                        icon: "figure.walk",
                        label: L10n.RouteSelection.statDistance,
                        value: route.distanceKilometers.formattedDistanceFromKm()
                    )

                    RouteStatItem(
                        icon: "clock",
                        label: L10n.RouteSelection.statTime,
                        value: route.paceAdjustedDurationLabel
                    )

                    RouteStatItem(
                        icon: "arrow.up.right",
                        label: L10n.RouteSelection.statElevation,
                        value: Double(RouteSelectionViewModel.estimatedElevation(for: route)).formattedElevation()
                    )
                }
                .padding(.vertical, LoooprTheme.Spacing.md)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(LoooprTheme.Colors.border)
                        .frame(height: 1)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(LoooprTheme.Colors.border)
                        .frame(height: 1)
                }

                // ── Start Walk CTA (Gradient) ──
                Button(action: onStartWalk) {
                    HStack(spacing: 10) {
                        Text(L10n.RouteSelection.startWalk)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .tracking(-0.3)

                        Image(systemName: "play.fill")
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
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
        }
        .background(LoooprTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(
            color: Color(hex: "#176a21").opacity(0.08),
            radius: 32,
            x: 0,
            y: 12
        )
    }
}

// MARK: - Route Stat Item

private struct RouteStatItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(LoooprTheme.Colors.primary.opacity(0.7))

            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(-0.2)
                .textCase(.uppercase)
                .foregroundStyle(LoooprTheme.Colors.textSecondary)

            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .tracking(-0.3)
                .foregroundStyle(LoooprTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Skeleton Card (Organic Editorial)

private struct SkeletonRouteCard: View {
    @State private var shimmerPhase: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image placeholder
            RoundedRectangle(cornerRadius: 0)
                .fill(LoooprTheme.Colors.surfaceContainer)
                .frame(height: 200)

            // Content placeholder
            VStack(alignment: .leading, spacing: 14) {
                // Title
                RoundedRectangle(cornerRadius: LoooprTheme.Radius.sm)
                    .fill(LoooprTheme.Colors.surfaceContainer)
                    .frame(width: 200, height: 22)

                // Description
                RoundedRectangle(cornerRadius: LoooprTheme.Radius.sm)
                    .fill(LoooprTheme.Colors.surfaceContainer)
                    .frame(width: 120, height: 14)

                // Stats row
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LoooprTheme.Colors.surfaceContainer)
                                .frame(width: 22, height: 22)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LoooprTheme.Colors.surfaceContainer)
                                .frame(width: 60, height: 10)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LoooprTheme.Colors.surfaceContainer)
                                .frame(width: 50, height: 18)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, LoooprTheme.Spacing.sm)

                // Button placeholder
                RoundedRectangle(cornerRadius: 16)
                    .fill(LoooprTheme.Colors.surfaceContainer)
                    .frame(height: 56)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
        }
        .background(LoooprTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(
            color: Color(hex: "#176a21").opacity(0.08),
            radius: 32,
            x: 0,
            y: 12
        )
        .opacity(shimmerPhase ? 0.55 : 1.0)
        .animation(
            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
            value: shimmerPhase
        )
        .onAppear { shimmerPhase = true }
    }
}
