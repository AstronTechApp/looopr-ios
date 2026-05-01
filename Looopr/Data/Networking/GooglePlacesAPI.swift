import CoreLocation
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
                URLQueryItem(name: "locationbias", value: "circle:2000@\(location)"),
                URLQueryItem(name: "fields", value: "place_id,name,geometry"),
                URLQueryItem(name: "key", value: apiKey),
            ]
        )
    }

    /// Google Places Nearby Search — strictly geographic, no text/keyword matching.
    static func nearbySearch(
        location: CLLocationCoordinate2D,
        radiusMeters: Double,
        type: String,
        apiKey: String
    ) -> Endpoint {
        Endpoint(
            baseURL: baseURL,
            path: "/nearbysearch/json",
            queryItems: [
                URLQueryItem(name: "location", value: "\(location.latitude),\(location.longitude)"),
                URLQueryItem(name: "radius", value: "\(Int(radiusMeters))"),
                URLQueryItem(name: "type", value: type),
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
                URLQueryItem(name: "fields", value: "name,rating,user_ratings_total,types,opening_hours,formatted_phone_number,website,url,price_level,editorial_summary"),
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

    // MARK: - Google Places (New) API — Nearby Search

    /// Google Places (New) Nearby Search endpoint.
    /// Uses `POST https://places.googleapis.com/v1/places:searchNearby` with
    /// JSON body and field mask header. One call returns both cafes and restaurants.
    static func nearbySearchNew(
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        includedTypes: [String],
        maxResultCount: Int,
        apiKey: String
    ) -> Endpoint {
        // Build JSON request body
        let body: [String: Any] = [
            "includedTypes": includedTypes,
            "maxResultCount": maxResultCount,
            "locationRestriction": [
                "circle": [
                    "center": [
                        "latitude": latitude,
                        "longitude": longitude
                    ],
                    "radius": radiusMeters
                ]
            ]
        ]
        let jsonData = try? JSONSerialization.data(withJSONObject: body)

        return Endpoint(
            baseURL: "https://places.googleapis.com",
            path: "/v1/places:searchNearby",
            method: .post,
            headers: [
                "Content-Type": "application/json",
                "X-Goog-Api-Key": apiKey,
                "X-Goog-FieldMask": "places.displayName,places.id,places.rating,places.regularOpeningHours,places.location,places.googleMapsUri,places.primaryType,places.types"
            ],
            body: jsonData
        )
    }

    // MARK: - Google Places (New) Response Models

    struct NearbySearchNewResponse: Decodable {
        let places: [NewPlace]?
    }

    struct NewPlace: Decodable {
        let id: String?
        let displayName: DisplayName?
        let rating: Double?
        let location: LatLngNew?
        let regularOpeningHours: RegularOpeningHours?
        let googleMapsUri: String?
        let primaryType: String?
        /// Full list of place types from Google Places (New).
        /// Used to detect misclassified venues (e.g. a pet groomer tagged as "cafe").
        let types: [String]?
    }

    struct DisplayName: Decodable {
        let text: String?
        let languageCode: String?
    }

    struct LatLngNew: Decodable {
        let latitude: Double?
        let longitude: Double?
    }

    struct RegularOpeningHours: Decodable {
        let openNow: Bool?
        let weekdayDescriptions: [String]?
        let periods: [Period]?
    }

    struct Period: Decodable {
        let open: Point?
        let close: Point?
    }

    struct Point: Decodable {
        let day: Int?
        let hour: Int?
        let minute: Int?
    }

    // MARK: - Response Models (Legacy)
    //
    // NOTE: No explicit CodingKeys needed — URLSessionAPIClient uses
    // keyDecodingStrategy = .convertFromSnakeCase, which automatically
    // converts JSON keys like "place_id" → placeId, "user_ratings_total"
    // → userRatingsTotal, etc. Adding explicit CodingKeys with snake_case
    // raw values CONFLICTS with convertFromSnakeCase and causes nil decoding.

    struct FindPlaceResponse: Decodable {
        let candidates: [Candidate]
        let status: String
        let errorMessage: String?

        struct Candidate: Decodable {
            let placeId: String?
            let name: String?
        }
    }

    /// Nearby Search response — results are strictly within the radius.
    struct NearbySearchResponse: Decodable {
        let results: [NearbyResult]
        let status: String

        struct NearbyResult: Decodable {
            let placeId: String?
            let name: String?
            let geometry: Geometry?
            let types: [String]?
            let rating: Double?
            let userRatingsTotal: Int?
            let vicinity: String?
            let openingHours: NearbyOpeningHours?
            let photos: [NearbyPhoto]?
        }

        struct Geometry: Decodable {
            let location: LatLng?
        }

        struct LatLng: Decodable {
            let lat: Double
            let lng: Double
        }

        struct NearbyOpeningHours: Decodable {
            let openNow: Bool?
        }

        struct NearbyPhoto: Decodable {
            let photoReference: String?
            let width: Int?
            let height: Int?
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
        }

        struct OpeningHours: Decodable {
            let openNow: Bool?
            let weekdayText: [String]?
        }

        struct Photo: Decodable {
            let photoReference: String?
            let width: Int?
            let height: Int?
        }

        struct EditorialSummary: Decodable {
            let overview: String?
        }
    }
}
