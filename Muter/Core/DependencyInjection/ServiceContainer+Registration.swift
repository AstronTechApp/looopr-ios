import Foundation

extension ServiceContainer {
    func registerProductionServices() {
        let config = AppConfiguration.current

        // Persistence
        let persistenceStore = UserDefaultsStore()
        registerSingleton(PersistenceStoring.self, instance: persistenceStore)

        // Networking
        let apiClient = URLSessionAPIClient()
        registerSingleton(APIClient.self, instance: apiClient)

        // Location
        let locationService = LiveLocationService()
        registerSingleton(LocationProviding.self, instance: locationService)

        // Route Generation
        let routeGeneration = LiveRouteGenerationService(configuration: config)
        registerSingleton(RouteGenerating.self, instance: routeGeneration)

        // POI
        let poiDiscovery = AppleMapsPOIDiscoveryService()
        registerSingleton(POIDiscovering.self, instance: poiDiscovery)

        let poiEnrichment = GooglePlacesEnrichmentService(
            apiClient: apiClient,
            apiKey: Secrets.googlePlacesAPIKey,
            configuration: config
        )
        registerSingleton(POIEnriching.self, instance: poiEnrichment)

        // Navigation
        let navigationDirections = LiveNavigationDirectionsService()
        registerSingleton(NavigationDirecting.self, instance: navigationDirections)

        // Photo
        let photoStorage = PhotoStorageService(store: persistenceStore)
        registerSingleton(PhotoManaging.self, instance: photoStorage)

        // Analytics
        let analytics = LiveAnalyticsService()
        registerSingleton(AnalyticsTracking.self, instance: analytics)
    }
}
