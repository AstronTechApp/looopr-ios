import Foundation

enum TiqetsAPI {
    private static let baseURL = "https://api.tiqets.com/v2"

    static func searchProducts(query: String, latitude: Double, longitude: Double, apiKey: String) -> Endpoint {
        Endpoint(
            baseURL: baseURL,
            path: "/products",
            queryItems: [
                URLQueryItem(name: "search", value: query),
                URLQueryItem(name: "lat", value: String(latitude)),
                URLQueryItem(name: "lng", value: String(longitude)),
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
        let products: [Product]?
    }

    struct Product: Decodable {
        let id: Int?
        let title: String?
        let price: ProductPrice?
        let rating: ProductRating?
        let url: String?
        let imageUrl: String?
    }

    struct ProductPrice: Decodable {
        let value: Double?
        let currency: String?
    }

    struct ProductRating: Decodable {
        let average: Double?
        let total: Int?
    }
}
