import Foundation

extension ServiceContainer {
    func registerProductionServices() {
        let config = AppConfiguration.current

        // Supabase — failable init returns nil when credentials are missing,
        // so the app launches gracefully without Supabase features instead of crashing.
        var supabaseProvider: SupabaseClientProvider?
        if let provider = SupabaseClientProvider() {
            supabaseProvider = provider
            registerSingleton(SupabaseClientProvider.self, instance: provider)

            let authService = AuthService(supabase: provider)
            registerSingleton(AuthService.self, instance: authService)
            registerSingleton(AuthProviding.self, instance: authService)
        }

        // Persistence — file-backed, with transparent one-time migration of
        // existing UserDefaults data (walk history with GPS tracks would
        // bloat UserDefaults, which loads fully into memory at launch).
        let persistenceStore = FileStore()
        registerSingleton(PersistenceStoring.self, instance: persistenceStore)

        // Repositories
        let routeRepository = RouteRepository(store: persistenceStore, supabase: supabaseProvider)
        registerSingleton(RouteRepository.self, instance: routeRepository)
        let walkHistoryRepository = WalkHistoryRepository(store: persistenceStore, supabase: supabaseProvider)
        registerSingleton(WalkHistoryRepository.self, instance: walkHistoryRepository)

        // Networking
        let apiClient = URLSessionAPIClient()
        registerSingleton(APIClient.self, instance: apiClient)

        // Location
        let locationService = LiveLocationService()
        registerSingleton(LocationProviding.self, instance: locationService)

        // Subscription — RevenueCat when a key is configured, otherwise a
        // permissive stub. Note: `paywallEnabled` in AppConfiguration.Freemium
        // is the master switch; while false everyone is premium either way.
        if Secrets.hasRevenueCatKey {
            let subscriptionService = RevenueCatSubscriptionService(
                apiKey: Secrets.revenueCatAPIKey,
                paywallEnabled: config.freemium.paywallEnabled
            )
            registerSingleton(RevenueCatSubscriptionService.self, instance: subscriptionService)
            registerSingleton(SubscriptionProviding.self, instance: subscriptionService)
        } else {
            let subscriptionService = LiveSubscriptionService()
            registerSingleton(SubscriptionProviding.self, instance: subscriptionService)
        }

        // Route Generation — freemium tier (MKDirections, quadrilateral loops)
        let routeGeneration = LiveRouteGenerationService(configuration: config)
        registerSingleton(RouteGenerating.self, instance: routeGeneration)

        // Route Generation — paid tier (Mapbox, pentagon loops, parallel)
        // Registered by concrete type so ViewModels can resolve it optionally.
        if Secrets.hasMapboxToken {
            let mapboxGeneration = MapboxRouteGenerationService(
                configuration: config,
                accessToken: Secrets.mapboxAccessToken
            )
            registerSingleton(MapboxRouteGenerationService.self, instance: mapboxGeneration)
        }

        // POI Discovery — Apple MapKit (primary, fast, no API key needed).
        // Uses MKLocalSearch with category filters at multiple points along
        // the route for full coverage. Replaces Overpass as primary source.
        let poiDiscovery = AppleMapKitDiscoveryService(configuration: config)
        registerSingleton(POIDiscovering.self, instance: poiDiscovery)

        // Fallback: OpenStreetMap Overpass API (churches, heritage sites that
        // MapKit doesn't cover). Uncomment and wire as a secondary source if needed.
        // let overpassDiscovery = OverpassPOIDiscoveryService(
        //     apiClient: apiClient,
        //     configuration: config
        // )

        // Legacy: Google Places Nearby Search (uncomment to restore)
        // let googleDiscovery = GooglePlacesNearbyDiscoveryService(
        //     apiClient: apiClient,
        //     apiKey: Secrets.googlePlacesAPIKey,
        //     configuration: config
        // )

        let poiEnrichment = GooglePlacesEnrichmentService(
            apiClient: apiClient,
            apiKey: Secrets.googlePlacesAPIKey,
            configuration: config
        )
        registerSingleton(POIEnriching.self, instance: poiEnrichment)

        // Food discovery via Google Places (New) API — on-demand when user taps Food & Drinks tab.
        // Replaces OSM food discovery with a single Google Places API call for cafes + restaurants.
        if Secrets.hasGooglePlacesKey {
            let foodService = GooglePlacesNewFoodService(
                apiClient: apiClient,
                apiKey: Secrets.googlePlacesAPIKey,
                configuration: config
            )
            registerSingleton(GooglePlacesNewFoodService.self, instance: foodService)
        }

        // Tickets — only register providers with configured API keys
        var ticketProviders: [TicketProviding] = []
        if Secrets.hasViatorKey {
            ticketProviders.append(ViatorTicketProvider(apiClient: apiClient, apiKey: Secrets.viatorAPIKey))
        }
        if Secrets.hasGetYourGuideKey {
            ticketProviders.append(GetYourGuideTicketProvider(apiClient: apiClient, apiKey: Secrets.getYourGuideAPIKey))
        }
        if Secrets.hasTiqetsKey {
            ticketProviders.append(TiqetsTicketProvider(apiClient: apiClient, apiKey: Secrets.tiqetsAPIKey))
        }
        if Secrets.hasMusementKey {
            ticketProviders.append(MusementTicketProvider(apiClient: apiClient, apiKey: Secrets.musementAPIKey))
        }
        if Secrets.hasKlookKey {
            ticketProviders.append(KlookTicketProvider(apiClient: apiClient, apiKey: Secrets.klookAPIKey))
        }
        let ticketAggregator = TicketAggregatorService(providers: ticketProviders)
        registerSingleton(TicketAggregating.self, instance: ticketAggregator)

        // POI discovery — one shared instance so the 5-minute POI cache
        // survives navigation instead of dying with each RouteDetail screen.
        let poiAggregator = POIAggregatorService(configuration: config)
        registerSingleton(POIAggregatorService.self, instance: poiAggregator)

        // Sharing
        if supabaseProvider != nil {
            let routeShareService = RouteShareService()
            registerSingleton(RouteShareService.self, instance: routeShareService)
        }

        // Navigation
        let navigationDirections = LiveNavigationDirectionsService()
        registerSingleton(NavigationDirecting.self, instance: navigationDirections)

        // Pedometer
        let pedometerService = LivePedometerService()
        registerSingleton(PedometerProviding.self, instance: pedometerService)

        // Elevation — barometric, not GPS. GPS altitude drifts by 5-10 m in a
        // way that is indistinguishable from gentle terrain, so it cannot
        // measure a climb; the barometer is accurate to about a metre.
        registerSingleton(ElevationProviding.self, instance: LiveElevationService())

        // Apple Health — write-only export of finished walks as workouts
        // (distance + GPS route). Never reads health data.
        registerSingleton(HealthWorkoutSaving.self, instance: LiveHealthWorkoutService())

        // Analytics — events are persisted to Supabase (analytics_events table)
        let analytics = LiveAnalyticsService(supabase: supabaseProvider)
        registerSingleton(AnalyticsTracking.self, instance: analytics)

        // Live Activity
        registerSingleton(LiveActivityManager.self, instance: LiveActivityManager.shared)
    }
}
