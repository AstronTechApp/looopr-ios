import Foundation

enum KlookAPI {
    private static let baseURL = "https://affiliate-api.klook.com/v1"

    static func searchActivities(query: String, latitude: Double, longitude: Double, apiKey: String) -> Endpoint {
        Endpoint(
            baseURL: baseURL,
            path: "/activities",
            queryItems: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "latitude", value: String(latitude)),
                URLQueryItem(name: "longitude", value: String(longitude)),
                URLQueryItem(name: "limit", value: "5"),
            ],
            headers: [
                "Accept": "application/json",
                "Authorization": "Bearer \(apiKey)"
            ]
        )
    }

    // MARK: - Response Models

    struct SearchResponse: Decodable {
        let result: [Activity]?
    }

    struct Activity: Decodable {
        let id: Int?
        let title: String?
        let price: String?
        let currencyCode: String?
        let score: Double?
        let reviewCount: Int?
        let url: String?
        let imageUrl: String?
    }
}
