import SwiftUI
import MapKit

struct SavedRoutesView: View {
    @State private var viewModel = SavedRoutesViewModel()
    @Environment(AppRouter.self) private var router

    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var shareTitle: String = ""
    @State private var showShareError = false
    @State private var showRemoveAlert = false

    var body: some View {
        ZStack {
            LoooprTheme.Colors.background
                .ignoresSafeArea()

            if viewModel.isEmpty {
                emptyState
            } else {
                routeList
            }
        }
        .navigationTitle(L10n.SavedRoutes.title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.load()
        }
        .refreshable {
            viewModel.load()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheetView(items: [shareTitle, url] as [Any])
            }
        }
        .alert(L10n.SavedRoutes.removeQuestion,
               isPresented: $showRemoveAlert,
               presenting: viewModel.routePendingDeletion) { route in
            Button(L10n.SavedRoutes.remove, role: .destructive) {
                viewModel.confirmPendingDeletion()
            }
            Button(L10n.SavedRoutes.cancel, role: .cancel) {
                viewModel.routePendingDeletion = nil
            }
        } message: { route in
            Text(L10n.SavedRoutes.willBeRemoved(route.baseName))
        }
        .alert(L10n.SavedRoutes.shareErrorTitle, isPresented: $showShareError) {
            Button(L10n.Misc.okay, role: .cancel) {}
        } message: {
            Text(viewModel.shareError ?? L10n.SavedRoutes.shareErrorMessage)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: LoooprTheme.Spacing.md) {
            Image(systemName: "bookmark")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(LoooprTheme.Colors.textTertiary)

            Text(L10n.SavedRoutes.empty)
                .font(LoooprTheme.Typography.headline)
                .foregroundStyle(LoooprTheme.Colors.textPrimary)

            Text(L10n.SavedRoutes.emptyDescription)
                .font(LoooprTheme.Typography.subheadline)
                .foregroundStyle(LoooprTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, LoooprTheme.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Route List

    private var routeList: some View {
        ScrollView {
            LazyVStack(spacing: LoooprTheme.Spacing.md) {
                ForEach(viewModel.savedRoutes) { route in
                    SavedRouteCard(
                        route: route,
                        isSharing: viewModel.isSharing,
                        onTap: {
                            router.navigate(to: .routeDetail(route))
                        },
                        onStartWalk: {
                            router.navigate(to: .walkNavigation(route))
                        },
                        onShare: {
                            Task { await share(route) }
                        },
                        onRemove: {
                            viewModel.routePendingDeletion = route
                            showRemoveAlert = true
                        }
                    )
                }
            }
            .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
            .padding(.top, LoooprTheme.Spacing.sm)
            .padding(.bottom, LoooprTheme.Spacing.huge)
        }
    }

    // MARK: - Share

    private func share(_ route: Route) async {
        if let url = await viewModel.shareRoute(route) {
            shareURL = url
            shareTitle = L10n.SavedRoutes.shareTitle(route.baseName)
            showShareSheet = true
        } else {
            showShareError = true
        }
    }
}

// MARK: - Saved Route Card

private struct SavedRouteCard: View {
    let route: Route
    let isSharing: Bool
    let onTap: () -> Void
    let onStartWalk: () -> Void
    let onShare: () -> Void
    let onRemove: () -> Void

    private var routeColor: Color {
        AppTheme.routeColor(for: route.colorIndex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tappable hero area — map preview + route name and chips
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        RouteMapPreview(route: route, color: routeColor)
                            .frame(height: 160)
                            .clipped()

                        LinearGradient(
                            colors: [.black.opacity(0.55), .clear],
                            startPoint: .bottom,
                            endPoint: .center
                        )

                        HStack(spacing: 6) {
                            chip(
                                text: route.distanceKilometers.formattedDistanceFromKm(),
                                foreground: Color(hex: "#005c15"),
                                background: LoooprTheme.Colors.primaryLight.opacity(0.92)
                            )

                            chip(
                                text: route.paceAdjustedDurationLabel,
                                foreground: Color(hex: "#7b3100"),
                                background: LoooprTheme.Colors.secondaryContainer.opacity(0.92)
                            )
                        }
                        .padding(12)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(route.displayName)
                            .font(LoooprTheme.Typography.headline)
                            .foregroundStyle(LoooprTheme.Colors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if !route.description.isEmpty {
                            Text(route.description)
                                .font(LoooprTheme.Typography.subheadline)
                                .foregroundStyle(LoooprTheme.Colors.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, LoooprTheme.Spacing.md)
                    .padding(.top, LoooprTheme.Spacing.sm)
                    .padding(.bottom, LoooprTheme.Spacing.xs)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Action row
            HStack(spacing: LoooprTheme.Spacing.sm) {
                Button(action: onStartWalk) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                        Text(L10n.SavedRoutes.startWalk)
                    }
                    .font(LoooprTheme.Typography.button)
                    .foregroundStyle(LoooprTheme.Colors.textOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(LoooprTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.md))
                }
                .buttonStyle(.plain)

                Button(action: onShare) {
                    Group {
                        if isSharing {
                            ProgressView().tint(LoooprTheme.Colors.primary)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .font(LoooprTheme.Typography.button)
                    .foregroundStyle(LoooprTheme.Colors.primary)
                    .frame(width: 44, height: 40)
                    .background(LoooprTheme.Colors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: LoooprTheme.Radius.md)
                            .stroke(LoooprTheme.Colors.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.md))
                }
                .buttonStyle(.plain)
                .disabled(isSharing)

                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(LoooprTheme.Typography.button)
                        .foregroundStyle(LoooprTheme.Colors.error)
                        .frame(width: 44, height: 40)
                        .background(LoooprTheme.Colors.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: LoooprTheme.Radius.md)
                                .stroke(LoooprTheme.Colors.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.md))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, LoooprTheme.Spacing.md)
            .padding(.top, LoooprTheme.Spacing.xs)
            .padding(.bottom, LoooprTheme.Spacing.md)
        }
        .background(LoooprTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.lg))
        .loooprShadow(LoooprTheme.Shadows.sm)
    }

    private func chip(text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(-0.3)
            .textCase(.uppercase)
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(Capsule())
    }
}
