import Foundation

actor GetYourGuideTicketProvider: TicketProviding {
    let providerName = "GetYourGuide"
    let commissionRate = 0.08

    private let apiClient: APIClient
    private let apiKey: String
    private let logger = AppLogger(category: "GYGTickets")

    init(apiClient: APIClient, apiKey: String) {
        self.apiClient = apiClient
        self.apiKey = apiKey
    }

    func searchTickets(for poi: POI) async throws -> [TicketOffer] {
        // Step 1: Search by attraction name + city for specific results
        // e.g. "Dom Tower Amsterdam" instead of just "Amsterdam"
        let specificQuery: String
        if let city = poi.locality {
            specificQuery = "\(poi.name) \(city)"
        } else {
            specificQuery = poi.name
        }

        let specificEndpoint = GetYourGuideAPI.searchActivities(
            query: specificQuery,
            latitude: poi.location.latitude,
            longitude: poi.location.longitude,
            apiKey: apiKey
        )

        let specificResponse = try await apiClient.request(specificEndpoint, responseType: GetYourGuideAPI.SearchResponse.self)
        var activities = filterGeographically(
            specificResponse.data?.activities ?? [],
            locality: poi.locality
        )

        // Step 2: If no geographically relevant results, fall back to city-level search
        if activities.isEmpty {
            logger.debug("No relevant results for '\(specificQuery)', falling back to city search")
            if let cityQuery = poi.locality {
                let cityEndpoint = GetYourGuideAPI.searchActivities(
                    query: cityQuery,
                    latitude: poi.location.latitude,
                    longitude: poi.location.longitude,
                    apiKey: apiKey
                )
                let cityResponse = try await apiClient.request(cityEndpoint, responseType: GetYourGuideAPI.SearchResponse.self)
                activities = filterGeographically(
                    cityResponse.data?.activities ?? [],
                    locality: poi.locality
                )
            }
        }

        guard !activities.isEmpty else { return [] }

        return activities.compactMap { activity -> TicketOffer? in
            guard let title = activity.title,
                  let urlString = activity.url,
                  let url = URL(string: urlString) else { return nil }

            let priceStr = activity.price?.values.map { values -> String? in
                guard let amount = values.amount else { return nil }
                let currency = values.currencyCode ?? "EUR"
                return String(format: "%@ %.2f", currency, amount)
            } ?? nil

            return TicketOffer(
                providerName: providerName,
                productName: title,
                price: priceStr,
                bookingURL: url,
                commissionRate: commissionRate,
                imageURL: activity.pictures?.first?.url.flatMap(URL.init(string:)),
                providerRating: activity.rating
            )
        }
    }

    // MARK: - Geographic Relevance Filter

    /// Filters GYG activities to only those geographically relevant to the POI's locality.
    /// GYG activity URLs contain city slugs (e.g. getyourguide.com/amsterdam-l36/...).
    /// If the POI has a locality, only keep activities whose URL contains a matching slug.
    /// If no locality is set, let all results through (they're anchored by lat/lng).
    private func filterGeographically(
        _ activities: [GetYourGuideAPI.Activity],
        locality: String?
    ) -> [GetYourGuideAPI.Activity] {
        guard let locality, !locality.isEmpty else {
            // No locality to validate against — trust lat/lng anchoring
            return activities
        }

        let citySlug = locality
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: " ", with: "-")

        let filtered = activities.filter { activity in
            guard let urlString = activity.url?.lowercased() else { return false }
            return urlString.contains(citySlug)
        }

        if filtered.isEmpty && !activities.isEmpty {
            logger.debug("Filtered out \(activities.count) geographically irrelevant results for '\(locality)'")
        }

        return filtered
    }
}
