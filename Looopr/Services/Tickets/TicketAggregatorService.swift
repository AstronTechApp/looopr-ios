import Foundation

actor TicketAggregatorService: TicketAggregating {
    private let providers: [TicketProviding]
    private let cache: CacheManager<UUID, TicketResult>
    private let logger = AppLogger(category: "Tickets")

    init(providers: [TicketProviding]) {
        self.providers = providers
        self.cache = CacheManager(ttl: 3600)
    }

    func findBestTicket(for poi: POI) async -> TicketResult {
        if let cached = await cache.get(poi.id) {
            return cached
        }

        guard poi.category.isTouristAttraction else {
            return .empty
        }

        // Query API-based providers in parallel
        var allOffers: [TicketOffer] = []
        if !providers.isEmpty {
            allOffers = await withTaskGroup(of: [TicketOffer].self) { group in
                for provider in providers {
                    group.addTask {
                        do {
                            return try await provider.searchTickets(for: poi)
                        } catch {
                            return []
                        }
                    }
                }

                var results: [TicketOffer] = []
                for await offers in group {
                    results.append(contentsOf: offers)
                }
                return results
            }
        }

        // Only use search-URL fallbacks when no API providers are configured.
        // If API providers exist and returned nothing, that means no tickets
        // are actually available — don't send users to empty search pages.
        if allOffers.isEmpty && providers.isEmpty {
            logger.debug("No API providers configured for '\(poi.name)', using search-URL fallback")
            allOffers = Self.searchURLOffers(for: poi)
        }

        let sorted = allOffers.sorted { $0.commissionRate > $1.commissionRate }
        let best = sorted.first

        if let best {
            logger.info("Best ticket for '\(poi.name)': \(best.providerName) (\(Int(best.commissionRate * 100))% commission)")
        } else {
            logger.debug("No tickets found for '\(poi.name)'")
        }

        let result = TicketResult(
            offers: sorted,
            bestOffer: best,
            fallbackURL: best == nil ? poi.websiteURL : nil
        )

        await cache.set(poi.id, value: result)
        return result
    }

    // MARK: - Search URL Fallback

    /// Generates search-URL based ticket offers for OTA sites.
    /// These don't require API keys — they link to the provider's search page.
    /// Ranked by commission rate so the highest-paying provider is shown first.
    ///
    /// Uses the POI's city/locality + coordinates for geographically relevant
    /// results instead of the POI name (which returns globally irrelevant hits).
    private static func searchURLOffers(for poi: POI) -> [TicketOffer] {
        let lat = poi.location.latitude
        let lng = poi.location.longitude

        // Build search query: "POI name + city" if city is known, otherwise just POI name
        // Avoids duplicating the name when locality is nil
        let textQuery: String
        if let city = poi.locality {
            textQuery = "\(poi.name) \(city)"
        } else {
            textQuery = poi.name
        }

        guard let encodedTextQuery = textQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }

        let searchProviders: [(name: String, commission: Double, urlTemplate: String)] = [
            // GYG: attraction name + city + coordinates for specific results
            ("GetYourGuide", 0.08, "https://www.getyourguide.com/s/?q=\(encodedTextQuery)&lat=\(lat)&lng=\(lng)&lc=en-US"),
            ("Viator",       0.08, "https://www.viator.com/searchResults/all?text=\(encodedTextQuery)"),
            ("Tiqets",       0.07, "https://www.tiqets.com/en/search?q=\(encodedTextQuery)"),
            ("Musement",     0.06, "https://www.musement.com/search/?q=\(encodedTextQuery)"),
            ("Klook",        0.05, "https://www.klook.com/search/result/?keyword=\(encodedTextQuery)"),
        ]

        return searchProviders.compactMap { provider in
            guard let url = URL(string: provider.urlTemplate) else { return nil }
            return TicketOffer(
                providerName: provider.name,
                productName: "Search \(provider.name) for tickets",
                price: nil,
                bookingURL: url,
                commissionRate: provider.commission
            )
        }
    }
}
