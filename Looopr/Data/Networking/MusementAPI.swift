import Foundation

enum MusementAPI {
    private static let baseURL = "https://api.musement.com/api/v3"

    static func searchActivities(query: String, latitude: Double, longitude: Double, apiKey: String) -> Endpoint {
        Endpoint(
            baseURL: baseURL,
            path: "/activities",
            queryItems: [
                URLQueryItem(name: "text", value: query),
                URLQueryItem(name: "coordinates", value: "\(latitude),\(longitude)"),
                URLQueryItem(name: "distance", value: "5"),
                URLQueryItem(name: "limit", value: "5"),
            ],
            headers: [
                "Accept": "application/json",
                "X-Musement-Application": apiKey
            ]
        )
    }

    // MARK: - Response Models

    struct SearchResponse: Decodable {
        let data: [Activity]?
    }

    struct Activity: Decodable {
        let uuid: String?
        let title: String?
        let retailPrice: RetailPrice?
        let reviewsAvg: Double?
        let reviewsNum: Int?
        let url: String?
        let coverImageUrl: String?
    }

    struct RetailPrice: Decodable {
        let formattedValue: String?
        let value: Double?
        let currencyCode: String?
    }
}
