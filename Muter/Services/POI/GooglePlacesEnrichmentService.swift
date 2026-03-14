import Foundation

actor GooglePlacesEnrichmentService: POIEnriching {
    private let apiClient: APIClient
    private let apiKey: String
    private let configuration: AppConfiguration
    private let logger = AppLogger(category: "GooglePlaces")
    private let cache: CacheManager<String, POI>

    init(
        apiClient: APIClient,
        apiKey: String,
        configuration: AppConfiguration = .current
    ) {
        self.apiClient = apiClient
        self.apiKey = apiKey
        self.configuration = configuration
        self.cache = CacheManager(ttl: configuration.poi.googlePlacesCacheTTLSeconds)
    }

    func enrich(poi: POI, minRating: Double?) async -> POI? {
        // Check cache
        if let cached = await cache.get(poi.name) {
            return cached
        }

        // Step 1: Find Google Place ID
        guard let placeId = await findPlaceId(for: poi) else {
            logger.debug("No Google Place ID for: \(poi.name)")
            return nil
        }

        // Step 2: Fetch place details
        guard let details = await fetchDetails(placeId: placeId) else {
            return nil
        }

        // Step 3: Apply rating filter
        if let minRating, let rating = details.rating, rating < minRating {
            logger.debug("\(poi.name) rating \(rating) below min \(minRating)")
            return nil
        }

        // Step 4: Build enriched POI
        var enriched = poi
        enriched.rating = details.rating
        enriched.reviewCount = details.userRatingsTotal
        enriched.phoneNumber = details.formattedPhoneNumber ?? poi.phoneNumber
        enriched.priceLevel = details.priceLevel
        enriched.isOpenNow = details.openingHours?.openNow
        enriched.detailedDescription = details.editorialSummary?.overview
        enriched.googlePlaceTypes = details.types ?? []

        if let weekdayText = details.openingHours?.weekdayText {
            enriched.openingHours = weekdayText.joined(separator: "\n")
        }

        if let websiteStr = details.website, let url = URL(string: websiteStr) {
            enriched.websiteURL = url
        }

        if let photoRef = details.photos?.first?.photoReference {
            enriched.imageURL = GooglePlacesAPI.photoURL(
                reference: photoRef,
                maxWidth: 400,
                apiKey: apiKey
            )
        }

        // Validate category via Google types
        if !enriched.googlePlaceTypes.isEmpty {
            let googleCategory = POICategory.from(googleTypes: enriched.googlePlaceTypes)
            if googleCategory == .other {
                logger.debug("\(poi.name) has no valid Google category, skipping")
                return nil
            }
        }

        await cache.set(poi.name, value: enriched)
        return enriched
    }

    // MARK: - Private

    private func findPlaceId(for poi: POI) async -> String? {
        let location = "\(poi.location.latitude),\(poi.location.longitude)"
        let endpoint = GooglePlacesAPI.findPlace(
            query: poi.name,
            location: location,
            apiKey: apiKey
        )

        do {
            let response = try await apiClient.request(endpoint, responseType: GooglePlacesAPI.FindPlaceResponse.self)
            return response.candidates.first?.placeId
        } catch {
            logger.warning("Find place failed for \(poi.name): \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchDetails(placeId: String) async -> GooglePlacesAPI.PlaceDetailsResponse.PlaceResult? {
        let endpoint = GooglePlacesAPI.placeDetails(placeId: placeId, apiKey: apiKey)

        do {
            let response = try await apiClient.request(endpoint, responseType: GooglePlacesAPI.PlaceDetailsResponse.self)
            return response.result
        } catch {
            logger.warning("Place details failed: \(error.localizedDescription)")
            return nil
        }
    }
}
