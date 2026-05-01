import CoreLocation
import MapKit

/// Apple Maps fallback for POI discovery. Uses natural-language MKLocalSearch
/// queries against a region derived from the route polyline.
///
/// NOTE: This service is retained as a fallback but is NOT the default.
/// The primary discovery service is `GooglePlacesNearbyDiscoveryService`,
/// which uses strict geographic Nearby Search to avoid false positives
/// from text/keyword matching.
actor AppleMapsPOIDiscoveryService: POIDiscovering {
    private let logger = AppLogger(category: "POIDiscovery")

    /// Category groups: each entry is a natural-language query + the POICategory to assign.
    private static let attractionQueries: [(query: String, category: POICategory)] = [
        ("museum",           .museum),
        ("park",             .park),
        ("theater",          .theater),
        ("zoo",              .zoo),
        ("aquarium",         .aquarium),
        ("monument",         .monument),
        ("church",           .church),
        ("castle",           .castle),
        ("tourist attraction", .landmark)
    ]

    private static let foodQueries: [(query: String, category: POICategory)] = [
        ("restaurant", .restaurant),
        ("cafe",       .cafe),
        ("bakery",     .bakery)
    ]

    /// MKPointOfInterestCategories that are clearly NOT tourist attractions.
    /// Used to reject false positives from natural-language searches (e.g., "Toko Castellum"
    /// returned for "castle" when it's actually a store/restaurant).
    private static let nonAttractionMKCategories: Set<MKPointOfInterestCategory> = [
        .restaurant, .cafe, .bakery, .brewery, .winery,
        .store, .gasStation, .pharmacy, .laundry,
        .carRental, .hotel, .parking, .bank, .atm,
        .evCharger, .postOffice, .school, .university,
        .nightlife, .fitnessCenter
    ]

    func discoverPOIs(
        alongRoute polyline: [CLLocationCoordinate2D],
        searchIntervalMeters: Double,
        searchRadiusMeters: Double
    ) async throws -> [POI] {
        guard let center = polylineCenter(polyline) else {
            throw POIError.discoveryFailed
        }

        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: searchRadiusMeters * 2,
            longitudinalMeters: searchRadiusMeters * 2
        )

        // Run attraction and food searches independently — a failure in one
        // category should not prevent the other from returning results.
        async let attractions = searchAll(queries: Self.attractionQueries, region: region, isAttraction: true)
        async let food = searchAll(queries: Self.foodQueries, region: region, isAttraction: false)

        let allPOIs = await attractions + food

        if allPOIs.isEmpty {
            throw POIError.discoveryFailed
        }

        logger.info("Discovered \(allPOIs.count) POIs along route")
        return allPOIs
    }

    /// Runs multiple natural-language searches in parallel, collecting results.
    /// Individual search failures are logged and skipped (never thrown).
    private func searchAll(
        queries: [(query: String, category: POICategory)],
        region: MKCoordinateRegion,
        isAttraction: Bool
    ) async -> [POI] {
        await withTaskGroup(of: [POI].self) { group in
            for entry in queries {
                group.addTask {
                    await self.searchPOIs(
                        query: entry.query,
                        category: entry.category,
                        region: region,
                        isAttraction: isAttraction
                    )
                }
            }
            var results: [POI] = []
            for await pois in group {
                results.append(contentsOf: pois)
            }
            return results
        }
    }

    /// Single natural-language search. Returns empty array on failure instead of throwing.
    private func searchPOIs(
        query: String,
        category: POICategory,
        region: MKCoordinateRegion,
        isAttraction: Bool
    ) async -> [POI] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        request.resultTypes = .pointOfInterest

        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            let pois = response.mapItems.compactMap { item -> POI? in
                guard let name = item.name, !name.isEmpty else { return nil }

                // Reject false positives: if searching for attractions and the
                // MKMapItem has a food/shopping/service category, skip it.
                if isAttraction, let mkCategory = item.pointOfInterestCategory {
                    if Self.nonAttractionMKCategories.contains(mkCategory) {
                        return nil
                    }
                }

                return POI(
                    name: name,
                    summary: item.placemark.title ?? "",
                    location: Location(item.placemark.coordinate),
                    category: category,
                    websiteURL: item.url,
                    phoneNumber: item.phoneNumber,
                    locality: item.placemark.locality
                )
            }
            if pois.count < response.mapItems.count {
                let filtered = response.mapItems.count - pois.count
                logger.debug("'\(query)': filtered out \(filtered) false positives")
            }
            return pois
        } catch {
            logger.debug("Search '\(query)' failed: \(error.localizedDescription)")
            return []
        }
    }

    private func polylineCenter(_ polyline: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        guard !polyline.isEmpty else { return nil }
        return polyline[polyline.count / 2]
    }
}
