import CoreLocation

struct NavigationStep: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let instruction: String
    let distanceMeters: Double
    let latitude: Double
    let longitude: Double
    /// Mapbox maneuver type ("turn", "arrive", "roundabout", …). Nil for MapKit steps.
    let maneuverType: String?
    /// Mapbox maneuver modifier ("left", "slight right", "uturn", …). Nil for MapKit steps.
    let maneuverModifier: String?
    /// Name of the street the step continues on, when the routing service provides it.
    let streetName: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(
        id: UUID = UUID(),
        instruction: String,
        distanceMeters: Double,
        latitude: Double,
        longitude: Double,
        maneuverType: String? = nil,
        maneuverModifier: String? = nil,
        streetName: String? = nil
    ) {
        self.id = id
        self.instruction = instruction
        self.distanceMeters = distanceMeters
        self.latitude = latitude
        self.longitude = longitude
        self.maneuverType = maneuverType
        self.maneuverModifier = maneuverModifier
        self.streetName = streetName
    }

    init(
        instruction: String,
        distanceMeters: Double,
        coordinate: CLLocationCoordinate2D,
        maneuverType: String? = nil,
        maneuverModifier: String? = nil,
        streetName: String? = nil
    ) {
        self.init(
            instruction: instruction,
            distanceMeters: distanceMeters,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            maneuverType: maneuverType,
            maneuverModifier: maneuverModifier,
            streetName: streetName
        )
    }
}
