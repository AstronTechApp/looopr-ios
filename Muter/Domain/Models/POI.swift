import Foundation

struct POI: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let name: String
    let summary: String
    let location: Location
    let category: POICategory
    let estimatedTimeMinutes: Int

    // Enriched data (from Google Places)
    var rating: Double?
    var reviewCount: Int?
    var imageURL: URL?
    var websiteURL: URL?
    var bookingURL: URL?
    var openingHours: String?
    var admissionFee: String?
    var phoneNumber: String?
    var accessibilityInfo: String?
    var priceLevel: Int?
    var isOpenNow: Bool?
    var detailedDescription: String?
    var googlePlaceTypes: [String]

    var isBookable: Bool { bookingURL != nil }
    var isHighlighted: Bool { category.isTouristAttraction }

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
        admissionFee: String? = nil,
        phoneNumber: String? = nil,
        accessibilityInfo: String? = nil,
        priceLevel: Int? = nil,
        isOpenNow: Bool? = nil,
        detailedDescription: String? = nil,
        googlePlaceTypes: [String] = []
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
        self.admissionFee = admissionFee
        self.phoneNumber = phoneNumber
        self.accessibilityInfo = accessibilityInfo
        self.priceLevel = priceLevel
        self.isOpenNow = isOpenNow
        self.detailedDescription = detailedDescription
        self.googlePlaceTypes = googlePlaceTypes
    }
}
