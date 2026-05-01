import Foundation

enum GetYourGuideAPI {
    private static let baseURL = "https://api.getyourguide.com/1"

    static func searchActivities(query: String, latitude: Double, longitude: Double, apiKey: String) -> Endpoint {
        Endpoint(
            baseURL: baseURL,
            path: "/activities",
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "lat", value: String(latitude)),
                URLQueryItem(name: "lng", value: String(longitude)),
                URLQueryItem(name: "limit", value: "5"),
                URLQueryItem(name: "currency", value: "EUR"),
            ],
            headers: [
                "Accept": "application/json",
                "X-Access-Token": apiKey
            ]
        )
    }

    // MARK: - Response Models

    struct SearchResponse: Decodable {
        let data: DataContainer?
    }

    struct DataContainer: Decodable {
        let activities: [Activity]?
    }

    struct Activity: Decodable {
        let activityId: Int?
        let title: String?
        let abstract: String?
        let price: Price?
        let rating: Double?
        let reviewsCount: Int?
        let url: String?
        let pictures: [Picture]?
    }

    struct Price: Decodable {
        let values: PriceValues?
    }

    struct PriceValues: Decodable {
        let amount: Double?
        let currencyCode: String?
    }

    struct Picture: Decodable {
        let url: String?
    }
}
