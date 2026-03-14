import CoreLocation
import MapKit

actor AppleMapsPOIDiscoveryService: POIDiscovering {
    private let logger = AppLogger(category: "POIDiscovery")

    private static let attractionCategories: [MKPointOfInterestCategory] = [
        .museum, .park, .nationalPark, .theater, .zoo, .aquarium, .library
    ]

    private static let foodCategories: [MKPointOfInterestCategory] = [
        .restaurant, .cafe, .bakery
    ]

    func discoverPOIs(
        center: CLLocationCoordinate2D,
        radiusMeters: Double
    ) async throws -> [POI] {
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radiusMeters * 2,
            longitudinalMeters: radiusMeters * 2
        )

        async let attractions = searchPOIs(
            region: region,
            categories: Self.attractionCategories
        )
        async let food = searchPOIs(
            region: region,
            categories: Self.foodCategories
        )

        let allPOIs = try await attractions + food
        logger.info("Discovered \(allPOIs.count) POIs near (\(center.latitude), \(center.longitude))")
        return allPOIs
    }

    private func searchPOIs(
        region: MKCoordinateRegion,
        categories: [MKPointOfInterestCategory]
    ) async throws -> [POI] {
        let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: categories)

        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            return response.mapItems.compactMap { item -> POI? in
                guard let name = item.name, !name.isEmpty else { return nil }

                let category = POICategory.from(mapKitCategory: item.pointOfInterestCategory)
                guard category != .other else { return nil }

                return POI(
                    name: name,
                    summary: item.placemark.title ?? "",
                    location: Location(item.placemark.coordinate),
                    category: category,
                    websiteURL: item.url,
                    phoneNumber: item.phoneNumber
                )
            }
        } catch {
            logger.warning("POI search failed: \(error.localizedDescription)")
            throw POIError.discoveryFailed
        }
    }
}
