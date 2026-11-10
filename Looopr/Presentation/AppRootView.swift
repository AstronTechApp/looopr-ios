import SwiftUI

struct AppRootView: View {
    @State private var router = AppRouter()
    @State private var authService: AuthService = ServiceContainer.shared.resolve(AuthService.self)
    @State private var localization = LocalizationManager.shared
    @State private var hasCheckedSession = false
    @State private var selectedTab: LoooprTab = .home
    @State private var onboarding = OnboardingState.shared
    @State private var guest = GuestSession.shared
    @State private var accountPrompt = AccountPrompt.shared

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
            } else if !authService.isSignedIn && !guest.isActive && !onboarding.hasCompleted {
                // First launch only: three intro pages, then straight to
                // Home as a guest. Since 1.5 there is no sign-in screen in
                // between: an account is only asked for when a feature needs
                // one (sharing, feedback, backup) or after the first walk.
                OnboardingView {
                    onboarding.markCompleted()
                    guest.continueAsGuest()
                }
                .transition(.opacity)
            } else {
                mainContent
            }
        }
        // A guest reached a feature that needs an account.
        .sheet(isPresented: Binding(
            get: { accountPrompt.reason != nil },
            set: { if !$0 { accountPrompt.dismiss() } }
        )) {
            AuthView(
                authService: authService,
                message: accountPromptMessage,
                onClose: { accountPrompt.dismiss() },
                analyticsReason: accountPrompt.reason?.analyticsName ?? "settings"
            )
        }
        .onChange(of: accountPrompt.reason) { _, reason in
            guard let reason else { return }
            ServiceContainer.shared.resolve(AnalyticsTracking.self)
                .track(.accountPromptShown(reason: reason.analyticsName))
        }
        .onChange(of: authService.isSignedIn) { _, signedIn in
            guard signedIn else {
                // Signed out (or account deleted): carry on as a guest.
                if onboarding.hasCompleted { guest.continueAsGuest() }
                return
            }
            guest.end()
            accountPrompt.dismiss()
        }
        .task {
            await authService.restoreSession()
            authService.observeAuthChanges()
            // Existing users updating to this version already have a session;
            // never show them the first-launch intro, even if they sign out later.
            if authService.isSignedIn {
                onboarding.markCompleted()
                guest.end()
            } else if onboarding.hasCompleted {
                // People from 1.4 and earlier who stopped at the sign-in
                // screen, or signed out: no more sign-in wall.
                guest.continueAsGuest()
            }
            hasCheckedSession = true
            // Fired after session restore so the event carries the signed-in
            // user when there is one; guests are counted by install ID.
            ServiceContainer.shared.resolve(AnalyticsTracking.self).track(.appOpened)
        }
        .animation(.easeInOut(duration: LoooprTheme.Animation.normal), value: onboarding.hasCompleted)
        .environment(\.locale, localization.currentLocale)
        // Light and dark mode follow the system since 1.5: every LoooprTheme
        // colour has a light and a dark value (Color(light:dark:)).
    }

    private var accountPromptMessage: String {
        switch accountPrompt.reason {
        case .shareRoute: L10n.Auth.signInToShare
        case .feedback: L10n.Auth.signInToSendFeedback
        case .settings, .afterWalk, nil: L10n.Auth.signInToSync
        }
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

    /// Every tab's `NavigationStack` is bound to the same `router.path`, so
    /// a push lands in all of them at once. On iOS 26's `TabView` the
    /// hidden tabs still build and run their destinations, which meant two
    /// `RouteSelectionView`s per search: two Mapbox requests, and a bogus
    /// "0 routes" event when the hidden copy was torn down. Only the tab
    /// that will show a destination hosts it; the others get a blank.
    /// Route selection always lives in Explore — `onChange(of: routeStack)`
    /// switches there the moment it is pushed.
    private func hosts(_ route: AppRoute, in tab: LoooprTab?) -> Bool {
        guard let tab else { return true }
        if case .routeSelection = route { return tab == .explore }
        return tab == selectedTab
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute, in tab: LoooprTab? = nil) -> some View {
        if hosts(route, in: tab) {
            hostedDestinationView(for: route)
        } else {
            LoooprTheme.Colors.background.ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func hostedDestinationView(for route: AppRoute) -> some View {
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
            Text(L10n.LocationSearch.searchLocation)
        case .settings:
            SettingsView()
        case .paywall:
            PaywallView(source: .settings)
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
                            destinationView(for: route, in: .home)
                        }
                }
            }

            Tab(L10n.Tab.explore, systemImage: "location", value: LoooprTab.explore) {
                NavigationStack(path: $router.path) {
                    HomeView()
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route, in: .explore)
                        }
                }
            }

            Tab(L10n.Tab.savedRoutes, systemImage: "bookmark", value: LoooprTab.savedRoutes) {
                NavigationStack(path: $router.path) {
                    SavedRoutesView()
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route, in: .savedRoutes)
                        }
                }
            }

            Tab(L10n.Tab.profile, systemImage: "person", value: LoooprTab.profile) {
                NavigationStack(path: $router.path) {
                    ProfileView()
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route, in: .profile)
                        }
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(LoooprTheme.Colors.primary)
        .modifier(sharedNavigation)
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
        .modifier(sharedNavigation)
    }

    // MARK: - Shared by both tab bars

    /// Tab ↔ route syncing, deep links and the paywall, identical for the
    /// iOS 26 TabView and the iOS 17–25 pill tab bar (was written out twice).
    private var sharedNavigation: SharedNavigation {
        SharedNavigation(router: router, authService: authService, selectedTab: $selectedTab, onDeepLink: handleDeepLink)
    }

    // MARK: - Deep Linking

    private func handleDeepLink(_ url: URL) {
        if url.host() == "looopr.app" || url.host() == "www.looopr.app",
           url.pathComponents.count >= 3,
           url.pathComponents[1] == "route",
           let routeID = UUID(uuidString: url.pathComponents[2]) {
            router.popToRoot()
            router.navigate(to: .sharedRoute(routeID))
            return
        }
    }
}

private struct SharedNavigation: ViewModifier {
    @Bindable var router: AppRouter
    let authService: AuthService
    @Binding var selectedTab: LoooprTab
    let onDeepLink: (URL) -> Void

    func body(content: Content) -> some View {
        content
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
                onDeepLink(url)
            }
            .fullScreenCover(isPresented: $router.isPaywallPresented) {
                PaywallView(source: router.paywallSource)
            }
    }
}

