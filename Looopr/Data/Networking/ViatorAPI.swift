import Foundation

enum ViatorAPI {
    private static let baseURL = "https://api.viator.com/partner"

    static func searchProducts(query: String, latitude: Double, longitude: Double, apiKey: String) -> Endpoint {
        let body: [String: Any] = [
            "filtering": [
                "searchTerm": query,
                "destination": [
                    "coordinates": [
                        "latitude": latitude,
                        "longitude": longitude
                    ],
                    "radius": 5,
                    "unit": "km"
                ]
            ],
            "sorting": ["sort": "RELEVANCE", "order": "DESCENDING"],
            "pagination": ["start": 1, "count": 5],
            "currency": "EUR"
        ]

        let bodyData = try? JSONSerialization.data(withJSONObject: body)

        return Endpoint(
            baseURL: baseURL,
            path: "/products/search",
            method: .post,
            headers: [
                "Accept": "application/json;version=2.0",
                "Content-Type": "application/json",
                "exp-api-key": apiKey
            ],
            body: bodyData
        )
    }

    // MARK: - Response Models

    struct SearchResponse: Decodable {
        let products: [Product]?
        let totalCount: Int?
    }

    struct Product: Decodable {
        let productCode: String?
        let title: String?
        let pricing: Pricing?
        let reviews: Reviews?
        let images: [ProductImage]?
        let productUrl: String?
    }

    struct Pricing: Decodable {
        let summary: PricingSummary?
    }

    struct PricingSummary: Decodable {
        let fromPrice: String?
        let fromPriceBeforeDiscount: String?
    }

    struct Reviews: Decodable {
        let combinedAverageRating: Double?
        let totalReviews: Int?
    }

    struct ProductImage: Decodable {
        let imageSource: String?

        enum CodingKeys: String, CodingKey {
            case imageSource
        }
    }
}
