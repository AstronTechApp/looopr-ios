import Foundation

struct OpeningHoursPeriod: Codable, Sendable, Hashable {
    let openDay: Int?
    let openHour: Int
    let openMinute: Int
    let closeDay: Int?
    let closeHour: Int?
    let closeMinute: Int?
}

struct POI: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var name: String
    let summary: String
    let location: Location
    var category: POICategory
    let estimatedTimeMinutes: Int

    // Enriched data (from Google Places)
    var rating: Double?
    var reviewCount: Int?
    var imageURL: URL?
    var websiteURL: URL?
    var bookingURL: URL?
    var openingHours: String?
    /// Raw Google Places weekday_text array (index 0 = Monday ... 6 = Sunday).
    var openingHoursWeekdayText: [String]?
    /// Structured Google Places periods, where day 0 = Sunday ... 6 = Saturday.
    var openingHoursPeriods: [OpeningHoursPeriod]?
    var admissionFee: String?
    var phoneNumber: String?
    var accessibilityInfo: String?
    var priceLevel: Int?
    var isOpenNow: Bool?
    var detailedDescription: String?
    var googlePlaceTypes: [String]
    /// Google Places `place_id` — unique identifier, used for deduplication.
    var googlePlaceId: String?
    /// Address / vicinity from Google Places — used for co-location grouping.
    var vicinity: String?

    /// Whether this POI has been enriched with full Place Details (phone, website, hours, etc.).
    /// `false` means only Nearby Search data is available; tap to fetch full details on demand.
    var isEnriched: Bool

    /// Google Maps page URL for this place — from `googleMapsUri` in Google Places (New) API.
    /// Used for the "View on Google Maps" link on food cards.
    var googleMapsUri: URL?

    /// Apple Maps URL for this place — constructed from MKMapItem when discovered via MapKit.
    /// Used for "View in Apple Maps" deep link on attraction cards.
    var appleMapsURL: URL?

    /// Normalised attraction name for matching against third-party activity providers
    /// (e.g. GetYourGuide, Viator). Lowercased, stripped of "The", parenthetical suffixes,
    /// and common venue-type words so "The British Museum" → "british museum".
    var matchableName: String?

    // Locality (city name) from Apple Maps placemark — used for booking URL construction
    var locality: String?

    // Computed during aggregation — distance in meters from the nearest point on the route
    var distanceFromRoute: Double?

    /// Distance in metres along the route polyline from the start to the closest point near this POI.
    /// Used to show "how far into the walk" the user will encounter this POI.
    var distanceAlongRoute: Double?

    /// Whether this POI has a Wikidata entry in OpenStreetMap.
    /// Used as a notability signal: major galleries, museums, and landmarks
    /// almost always have Wikidata entries; small independent galleries don't.
    var hasWikidata: Bool

    private enum CodingKeys: String, CodingKey {
        case id, name, summary, location, category, estimatedTimeMinutes
        case rating, reviewCount, imageURL, websiteURL, bookingURL
        case openingHours, openingHoursWeekdayText, openingHoursPeriods, admissionFee
        case phoneNumber, accessibilityInfo, priceLevel, isOpenNow
        case detailedDescription, googlePlaceTypes, googlePlaceId
        case vicinity, isEnriched, locality, distanceFromRoute, distanceAlongRoute, googleMapsUri
        case appleMapsURL, matchableName
        case hasWikidata
    }

    /// Current opening status derived from `isOpenNow` and `openingHoursWeekdayText`.
    var openStatus: OpenStatus {
        openStatus(at: nil)
    }

    func openStatus(at date: Date?) -> OpenStatus {
        poiOpenStatus(
            isOpenNow: isOpenNow,
            weekdayText: openingHoursWeekdayText,
            periods: openingHoursPeriods,
            at: date
        )
    }

    var isBookable: Bool { bookingURL != nil }
    var isHighlighted: Bool { category.isTouristAttraction }

    /// Description for display: mapped from Google Places types if available,
    /// otherwise falls back to editorial summary, then to category generic description.
    var displayDescription: String {
        if !googlePlaceTypes.isEmpty {
            return placeDescription(for: googlePlaceTypes)
        }
        if let desc = detailedDescription, !desc.isEmpty { return desc }
        return category.genericDescription
    }

    /// Booking CTA strategy derived from Google Places types, review count, and name.
    var bookingCTAStrategy: BookingCTAStrategy {
        return bookingStrategy(for: googlePlaceTypes, reviewCount: reviewCount, name: name)
    }

    /// Formats the POI's distance from the route using the given unit system.
    /// Use this in views where `@MainActor` is available, passing
    /// `SettingsManager.shared.preferredUnits`.
    func distanceFromRouteFormatted(units: SettingsManager.Units) -> String? {
        guard let dist = distanceFromRoute else { return nil }
        return "\(dist.formattedDistance(units: units)) from route"
    }

    /// Formats the walking distance along the route and estimated walking time.
    /// e.g. "2.1 km · ~25min walk" or "1.3 mi · ~1h 40min walk"
    func walkingInfoFormatted(units: SettingsManager.Units, pace: SettingsManager.WalkingPace) -> String? {
        guard let dist = distanceAlongRoute else { return nil }
        let distanceText = dist.formattedDistance(units: units)
        let totalMinutes = Int((dist / pace.metresPerMinute).rounded())
        let timeText: String
        if totalMinutes < 1 {
            timeText = "<1min"
        } else if totalMinutes < 60 {
            timeText = "~\(totalMinutes)min"
        } else {
            let hours = totalMinutes / 60
            let remaining = totalMinutes % 60
            timeText = remaining == 0 ? "~\(hours)h" : "~\(hours)h \(remaining)min"
        }
        return "\(distanceText) · \(timeText) walk"
    }

    init(
        id: UUID = UUID(),
        name: String,
        summary: String = "",
        location: Location,
        category: POICategory,
        estimatedTimeMinutes: Int = 15,
        rating: Double? = nil,
        reviewCount: Int? = nil,
        imageURL: URL? = nil,
        websiteURL: URL? = nil,
        bookingURL: URL? = nil,
        openingHours: String? = nil,
        openingHoursWeekdayText: [String]? = nil,
        openingHoursPeriods: [OpeningHoursPeriod]? = nil,
        admissionFee: String? = nil,
        phoneNumber: String? = nil,
        accessibilityInfo: String? = nil,
        priceLevel: Int? = nil,
        isOpenNow: Bool? = nil,
        detailedDescription: String? = nil,
        googlePlaceTypes: [String] = [],
        googlePlaceId: String? = nil,
        vicinity: String? = nil,
        locality: String? = nil,
        distanceFromRoute: Double? = nil,
        distanceAlongRoute: Double? = nil,
        isEnriched: Bool = false,
        googleMapsUri: URL? = nil,
        appleMapsURL: URL? = nil,
        matchableName: String? = nil,
        hasWikidata: Bool = false
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.location = location
        self.category = category
        self.estimatedTimeMinutes = estimatedTimeMinutes
        self.rating = rating
        self.reviewCount = reviewCount
        self.imageURL = imageURL
        self.websiteURL = websiteURL
        self.bookingURL = bookingURL
        self.openingHours = openingHours
        self.openingHoursWeekdayText = openingHoursWeekdayText
        self.openingHoursPeriods = openingHoursPeriods
        self.admissionFee = admissionFee
        self.phoneNumber = phoneNumber
        self.accessibilityInfo = accessibilityInfo
        self.priceLevel = priceLevel
        self.isOpenNow = isOpenNow
        self.detailedDescription = detailedDescription
        self.googlePlaceTypes = googlePlaceTypes
        self.googlePlaceId = googlePlaceId
        self.vicinity = vicinity
        self.locality = locality
        self.distanceFromRoute = distanceFromRoute
        self.distanceAlongRoute = distanceAlongRoute
        self.isEnriched = isEnriched
        self.googleMapsUri = googleMapsUri
        self.appleMapsURL = appleMapsURL
        self.matchableName = matchableName
        self.hasWikidata = hasWikidata
    }

    // MARK: - Resilient Decoder

    /// Custom decoder that provides defaults for fields added after the initial release.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        location = try container.decode(Location.self, forKey: .location)
        category = try container.decode(POICategory.self, forKey: .category)
        estimatedTimeMinutes = try container.decodeIfPresent(Int.self, forKey: .estimatedTimeMinutes) ?? 15
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        reviewCount = try container.decodeIfPresent(Int.self, forKey: .reviewCount)
        imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
        websiteURL = try container.decodeIfPresent(URL.self, forKey: .websiteURL)
        bookingURL = try container.decodeIfPresent(URL.self, forKey: .bookingURL)
        openingHours = try container.decodeIfPresent(String.self, forKey: .openingHours)
        openingHoursWeekdayText = try container.decodeIfPresent([String].self, forKey: .openingHoursWeekdayText)
        openingHoursPeriods = try container.decodeIfPresent([OpeningHoursPeriod].self, forKey: .openingHoursPeriods)
        admissionFee = try container.decodeIfPresent(String.self, forKey: .admissionFee)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        accessibilityInfo = try container.decodeIfPresent(String.self, forKey: .accessibilityInfo)
        priceLevel = try container.decodeIfPresent(Int.self, forKey: .priceLevel)
        isOpenNow = try container.decodeIfPresent(Bool.self, forKey: .isOpenNow)
        detailedDescription = try container.decodeIfPresent(String.self, forKey: .detailedDescription)
        googlePlaceTypes = try container.decodeIfPresent([String].self, forKey: .googlePlaceTypes) ?? []
        googlePlaceId = try container.decodeIfPresent(String.self, forKey: .googlePlaceId)
        vicinity = try container.decodeIfPresent(String.self, forKey: .vicinity)
        locality = try container.decodeIfPresent(String.self, forKey: .locality)
        distanceFromRoute = try container.decodeIfPresent(Double.self, forKey: .distanceFromRoute)
        distanceAlongRoute = try container.decodeIfPresent(Double.self, forKey: .distanceAlongRoute)
        isEnriched = try container.decodeIfPresent(Bool.self, forKey: .isEnriched) ?? false
        googleMapsUri = try container.decodeIfPresent(URL.self, forKey: .googleMapsUri)
        appleMapsURL = try container.decodeIfPresent(URL.self, forKey: .appleMapsURL)
        matchableName = try container.decodeIfPresent(String.self, forKey: .matchableName)
        hasWikidata = try container.decodeIfPresent(Bool.self, forKey: .hasWikidata) ?? false
    }
}
