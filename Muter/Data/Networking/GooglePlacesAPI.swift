import Foundation

enum GooglePlacesAPI {
    private static let baseURL = "https://maps.googleapis.com/maps/api/place"

    static func findPlace(query: String, location: String, apiKey: String) -> Endpoint {
        Endpoint(
            baseURL: baseURL,
            path: "/findplacefromtext/json",
            queryItems: [
                URLQueryItem(name: "input", value: query),
                URLQueryItem(name: "inputtype", value: "textquery"),
                URLQueryItem(name: "locationbias", value: "circle:500@\(location)"),
                URLQueryItem(name: "fields", value: "place_id,name,geometry"),
                URLQueryItem(name: "key", value: apiKey),
            ]
        )
    }

    static func placeDetails(placeId: String, apiKey: String) -> Endpoint {
        Endpoint(
            baseURL: baseURL,
            path: "/details/json",
            queryItems: [
                URLQueryItem(name: "place_id", value: placeId),
                URLQueryItem(name: "fields", value: "name,rating,user_ratings_total,types,opening_hours,formatted_phone_number,website,url,price_level,photos,editorial_summary"),
                URLQueryItem(name: "key", value: apiKey),
            ]
        )
    }

    static func photoURL(reference: String, maxWidth: Int, apiKey: String) -> URL? {
        var components = URLComponents(string: "\(baseURL)/photo")
        components?.queryItems = [
            URLQueryItem(name: "maxwidth", value: "\(maxWidth)"),
            URLQueryItem(name: "photo_reference", value: reference),
            URLQueryItem(name: "key", value: apiKey),
        ]
        return components?.url
    }

    // MARK: - Response Models

    struct FindPlaceResponse: Decodable {
        let candidates: [Candidate]
        let status: String

        struct Candidate: Decodable {
            let placeId: String?
            let name: String?

            enum CodingKeys: String, CodingKey {
                case placeId = "place_id"
                case name
            }
        }
    }

    struct PlaceDetailsResponse: Decodable {
        let result: PlaceResult?
        let status: String

        struct PlaceResult: Decodable {
            let name: String?
            let rating: Double?
            let userRatingsTotal: Int?
            let types: [String]?
            let openingHours: OpeningHours?
            let formattedPhoneNumber: String?
            let website: String?
            let url: String?
            let priceLevel: Int?
            let photos: [Photo]?
            let editorialSummary: EditorialSummary?

            enum CodingKeys: String, CodingKey {
                case name, rating, types, website, url, photos
                case userRatingsTotal = "user_ratings_total"
                case openingHours = "opening_hours"
                case formattedPhoneNumber = "formatted_phone_number"
                case priceLevel = "price_level"
                case editorialSummary = "editorial_summary"
            }
        }

        struct OpeningHours: Decodable {
            let openNow: Bool?
            let weekdayText: [String]?

            enum CodingKeys: String, CodingKey {
                case openNow = "open_now"
                case weekdayText = "weekday_text"
            }
        }

        struct Photo: Decodable {
            let photoReference: String?
            let width: Int?
            let height: Int?

            enum CodingKeys: String, CodingKey {
                case photoReference = "photo_reference"
                case width, height
            }
        }

        struct EditorialSummary: Decodable {
            let overview: String?
        }
    }
}
