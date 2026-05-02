import SwiftUI

struct AppRootView: View {
    @State private var router = AppRouter()
    @State private var authService: AuthService = ServiceContainer.shared.resolve(AuthService.self)
    @State private var localization = LocalizationManager.shared
    @State private var hasCheckedSession = false
    @State private var selectedTab: LoooprTab = .home

    var body: some View {
        Group {
            if !hasCheckedSession {
                ZStack {
                    LoooprTheme.Colors.background.ignoresSafeArea()
                    VStack(spacing: LoooprTheme.Spacing.md) {
                        Image("LoooprLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                        ProgressView()
                            .tint(LoooprTheme.Colors.primary)
                    }
                }
            } else if !authService.isSignedIn {
                AuthView(authService: authService)
            } else {
                mainContent
            }
        }
        .task {
            await authService.restoreSession()
            authService.observeAuthChanges()
            hasCheckedSession = true
        }
        .environment(\.locale, localization.currentLocale)
        // Force light color scheme app-wide.
        // The LoooprTheme palette uses hardcoded hex colors that don't adapt to dark mode,
        // which causes invisible system components (e.g. wheel DatePicker) and tab-bar flicker
        // when iOS is in dark mode. Until the theme is refactored with dynamic colors,
        // we lock the app to light mode for visual consistency.
        .preferredColorScheme(.light)
    }

    // MARK: - Main Content (version branching)

    @ViewBuilder
    private var mainContent: some View {
        if #available(iOS 26, *) {
            liquidGlassContent
        } else {
            legacyContent
        }
    }

    // MARK: - Shared Navigation Destination

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .home:
            HomeView()
        case .routeSelection(let minutes, let customLocation):
            RouteSelectionView(walkDurationMinutes: minutes, customLocation: customLocation)
        case .routeDetail(let route):
            RouteDetailView(route: route)
        case .walkNavigation(let route):
            WalkNavigationView(route: route)
        case .finishWalk(let session, let walkRoute):
            FinishWalkView(session: session, route: walkRoute)
        case .walkDetail(let session):
            WalkDetailView(session: session)
        case .sharedRoute(let routeID):
            SharedRouteView(routeID: routeID)
        case .locationSearch:
            Text("Search Location")
        case .settings:
            SettingsView()
        case .paywall:
            Text("Upgrade to Premium")
        }
    }

    // MARK: - iOS 26+ · Native Liquid Glass TabView

    @available(iOS 26, *)
    private var liquidGlassContent: some View {
        TabView(selection: $selectedTab) {
            Tab(L10n.Tab.home, systemImage: "house", value: LoooprTab.home) {
                NavigationStack(path: $router.path) {
                    HomeView()
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                        }
                }
            }

            Tab(L10n.Tab.explore, systemImage: "location", value: LoooprTab.explore) {
                NavigationStack(path: $router.path) {
                    HomeView()
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                        }
                }
            }

            Tab(L10n.Tab.savedRoutes, systemImage: "bookmark", value: LoooprTab.savedRoutes) {
                NavigationStack(path: $router.path) {
                    SavedRoutesView()
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                        }
                }
            }

            Tab(L10n.Tab.profile, systemImage: "person", value: LoooprTab.profile) {
                NavigationStack(path: $router.path) {
                    ProfileView()
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                        }
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(LoooprTheme.Colors.primary)
        .environment(router)
        .environment(authService)
        .onChange(of: selectedTab) { _, tab in
            if tab == .explore {
                if router.isOnRouteSelection { return }
                router.popToRoot()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    router.navigate(to: .routeSelection(
                        walkMinutes: router.lastExploreMinutes,
                        customLocation: router.lastExploreLocation
                    ))
                }
            } else {
                router.popToRoot()
            }
        }
        .onChange(of: router.routeStack) { _, stack in
            let isOnRoutes = stack.contains { route in
                if case .routeSelection = route { return true }
                return false
            }
            if isOnRoutes && selectedTab != .explore {
                selectedTab = .explore
            } else if !isOnRoutes && selectedTab == .explore {
                selectedTab = .home
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SwitchToProfileTab"))) { _ in
            selectedTab = .profile
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    // MARK: - iOS 17–25 · Custom Floating Pill Tab Bar

    private var shouldShowTabBar: Bool {
        !router.isInFullScreenFlow
    }

    private var legacyContent: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case .home, .explore:
                    NavigationStack(path: $router.path) {
                        HomeView()
                            .navigationDestination(for: AppRoute.self) { route in
                                destinationView(for: route)
                            }
                    }
                case .savedRoutes:
                    NavigationStack(path: $router.path) {
                        SavedRoutesView()
                            .navigationDestination(for: AppRoute.self) { route in
                                destinationView(for: route)
                            }
                    }
                case .profile:
                    NavigationStack(path: $router.path) {
                        ProfileView()
                            .navigationDestination(for: AppRoute.self) { route in
                                destinationView(for: route)
                            }
                    }
                }
            }
            // Floating pill tab bar — hidden during walk navigation and finish walk
            if shouldShowTabBar {
                LoooprTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: shouldShowTabBar)
        .environment(router)
        .environment(authService)
        .onChange(of: selectedTab) { _, tab in
            if tab == .explore {
                if router.isOnRouteSelection { return }
                router.popToRoot()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    router.navigate(to: .routeSelection(
                        walkMinutes: router.lastExploreMinutes,
                        customLocation: router.lastExploreLocation
                    ))
                }
            } else {
                router.popToRoot()
            }
        }
        .onChange(of: router.routeStack) { _, stack in
            let isOnRoutes = stack.contains { route in
                if case .routeSelection = route { return true }
                return false
            }
            if isOnRoutes && selectedTab != .explore {
                selectedTab = .explore
            } else if !isOnRoutes && selectedTab == .explore {
                selectedTab = .home
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SwitchToProfileTab"))) { _ in
            selectedTab = .profile
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    // MARK: - Deep Linking

    private func handleDeepLink(_ url: URL) {
        if url.host() == "looopr.app",
           url.pathComponents.count >= 3,
           url.pathComponents[1] == "route",
           let routeID = UUID(uuidString: url.pathComponents[2]) {
            router.popToRoot()
            router.navigate(to: .sharedRoute(routeID))
            return
        }
    }
}
