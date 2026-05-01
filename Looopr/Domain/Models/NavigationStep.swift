import CoreLocation

struct NavigationStep: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let instruction: String
    let distanceMeters: Double
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(
        id: UUID = UUID(),
        instruction: String,
        distanceMeters: Double,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.instruction = instruction
        self.distanceMeters = distanceMeters
        self.latitude = latitude
        self.longitude = longitude
    }

    init(instruction: String, distanceMeters: Double, coordinate: CLLocationCoordinate2D) {
        self.init(
            instruction: instruction,
            distanceMeters: distanceMeters,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}
