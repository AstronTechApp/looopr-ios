import Foundation

/// Endpoint builder for the **Overpass API** (OpenStreetMap).
///
/// The Overpass API returns OSM data matching a declarative query language.
/// We use it for POI discovery: given a bounding box or radius around
/// search points, we fetch nodes tagged with tourism/amenity/leisure/historic
/// keys and convert them into POI objects.
///
/// Cost: **$0** — the public Overpass endpoint is free. For production
/// throughput, swap `baseURL` to a self-hosted instance (~$30/month VPS).
enum OverpassAPI {

    /// Public Overpass endpoint. Replace with your own instance for production.
    static let defaultBaseURL = "https://overpass-api.de/api"

    // MARK: - Query Builder

    /// Build an Overpass QL query that searches for POI nodes within
    /// `radiusMeters` of each search point, filtered to the OSM tags
    /// that map to the app's POI categories.
    ///
    /// A single Overpass query replaces the ~112 individual Google API calls
    /// (8 search points × 14 types) with **1 HTTP request**.
    ///
    /// **Timeout**: Dense cities like London have millions of OSM objects.
    /// 25s was too short for routes with 20+ search points — the query
    /// would time out on the public Overpass endpoint, returning zero POIs.
    /// Bumped to 45s which handles even the densest European cities.
    static func poiQuery(
        searchPoints: [(lat: Double, lon: Double)],
        radiusMeters: Double
    ) -> String {
        // Build an "around" set from all search points.
        // Overpass "around" syntax: (around:radius,lat1,lon1,lat2,lon2,...)
        let coords = searchPoints.map { "\($0.lat),\($0.lon)" }.joined(separator: ",")
        let r = Int(radiusMeters)

        // Query for nodes, ways, AND relations matching our POI tags.
        // Many POIs (restaurants, cafes, buildings) are mapped as ways (building
        // outlines) or relations in OSM, not just nodes. Using "nwr" (node/way/
        // relation) catches all of them.
        // "out center" returns the centroid for ways/relations so we always get coords.
        // [out:json] gives us JSON; [timeout:45] accommodates dense cities.
        return """
        [out:json][timeout:45];
        (
          nwr["tourism"~"museum|viewpoint|attraction|zoo|aquarium|theme_park"](around:\(r),\(coords));
          nwr["amenity"~"place_of_worship|theatre"](around:\(r),\(coords));
          nwr["leisure"~"park|garden|nature_reserve"](around:\(r),\(coords));
          nwr["historic"~"monument|memorial|castle|ruins|archaeological_site|fort|church"](around:\(r),\(coords));
        );
        out center;
        """
    }

    // MARK: - Endpoint

    /// Build an `Endpoint` for the Overpass interpreter.
    /// Overpass accepts the query as a POST body or as a `data` query parameter.
    /// We use POST to avoid URL-length issues with many search points.
    static func interpreter(
        query: String,
        baseURL: String = defaultBaseURL
    ) -> Endpoint {
        // Use a restrictive character set for form encoding. `.urlQueryAllowed`
        // is too permissive — it leaves `+`, `&`, and `=` unencoded, which are
        // special delimiters in application/x-www-form-urlencoded bodies.
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) ?? query

        return Endpoint(
            baseURL: baseURL,
            path: "/interpreter",
            method: .post,
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            body: "data=\(encoded)".data(using: .utf8)
        )
    }

    // MARK: - Response Models

    struct OverpassResponse: Decodable {
        let elements: [Element]
    }

    struct Element: Decodable {
        let id: Int
        let type: String?
        let lat: Double?
        let lon: Double?
        /// For ways/relations, `out center` puts the centroid here.
        let center: Center?
        let tags: Tags?

        /// Resolved latitude: direct for nodes, center for ways/relations.
        var resolvedLat: Double? { lat ?? center?.lat }
        /// Resolved longitude: direct for nodes, center for ways/relations.
        var resolvedLon: Double? { lon ?? center?.lon }
    }

    struct Center: Decodable {
        let lat: Double
        let lon: Double
    }

    /// Flexible tag container. OSM tags are key-value pairs; we decode the
    /// ones relevant for POI display and classification.
    struct Tags: Decodable {
        let name: String?
        let tourism: String?
        let amenity: String?
        let leisure: String?
        let historic: String?
        let cuisine: String?
        let openingHours: String?
        let website: String?
        let phone: String?
        let wheelchair: String?
        let description: String?
        let wikidata: String?

        private enum CodingKeys: String, CodingKey {
            case name, tourism, amenity, leisure, historic, cuisine
            case openingHours = "opening_hours"
            case website, phone, wheelchair, description, wikidata
        }
    }

    // MARK: - OSM → POICategory Mapping

    /// Map an Overpass element's tags to the app's `POICategory`.
    static func category(for tags: Tags) -> POICategory {
        // Check amenity first (food wins over attraction, same logic as Google mapping)
        if let amenity = tags.amenity {
            switch amenity {
            case "cafe":                return .cafe
            case "bakery":              return .bakery
            case "restaurant", "fast_food":  return .restaurant
            case "bar", "pub":          return .bar
            case "place_of_worship":    return .church
            case "theatre": return .theater
            default: break
            }
        }
        if let tourism = tags.tourism {
            switch tourism {
            case "museum":              return .museum
            case "viewpoint":           return .viewpoint
            case "zoo":                 return .zoo
            case "aquarium":            return .aquarium
            case "attraction", "theme_park": return .landmark
            default: break
            }
        }
        if let historic = tags.historic {
            switch historic {
            case "castle", "fort":      return .castle
            case "monument", "memorial": return .monument
            case "church":              return .church
            case "ruins", "archaeological_site": return .historicSite
            default:                    return .historicSite
            }
        }
        if let leisure = tags.leisure {
            switch leisure {
            case "park", "nature_reserve": return .park
            case "garden":              return .garden
            default: break
            }
        }
        return .landmark
    }

    /// Build a list of pseudo "Google types" from OSM tags so the existing
    /// `POICategory.from(googleTypes:)` and `placeDescription(for:)` helpers
    /// still work downstream.
    static func googleTypeEquivalents(for tags: Tags) -> [String] {
        var types: [String] = ["point_of_interest"]
        if let t = tags.tourism {
            switch t {
            case "museum": types.append("museum")
            case "zoo": types.append("zoo")
            case "aquarium": types.append("aquarium")
            case "attraction", "theme_park": types.append("tourist_attraction")
            case "viewpoint": types.append("tourist_attraction")
            default: break
            }
        }
        if let a = tags.amenity {
            switch a {
            case "restaurant", "fast_food": types.append("restaurant")
            case "cafe": types.append("cafe")
            case "bakery": types.append("bakery")
            case "bar", "pub": types.append("bar")
            case "place_of_worship": types.append("church")
            case "theatre": types.append("tourist_attraction")
            default: break
            }
        }
        if let h = tags.historic {
            switch h {
            case "castle", "fort": types.append("tourist_attraction")
            case "monument", "memorial": types.append("tourist_attraction")
            default: types.append("tourist_attraction")
            }
        }
        if let l = tags.leisure {
            switch l {
            case "park", "nature_reserve": types.append("park")
            case "garden": types.append("park")
            default: break
            }
        }
        return types
    }
}
