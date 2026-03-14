import Foundation

actor GooglePlacesEnrichmentService: POIEnriching {
    private let apiClient: APIClient
    private let apiKey: String
    private let configuration: AppConfiguration
    private let logger = AppLogger(category: "GooglePlaces")

    init(
        apiClient: APIClient,
        apiKey: String,
        configuration: AppConfiguration = .current
    ) {
        self.apiClient = apiClient
        self.apiKey = apiKey
        self.configuration = configuration
    }

    func enrich(poi: POI, minRating: Double?) async -> POI? {
        // Full implementation in Sprint 3
        logger.info("Enriching POI: \(poi.name)")
        return nil
    }
}
