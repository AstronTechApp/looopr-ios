import CoreLocation

struct Route: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let durationMinutes: Int
    let distanceKilometers: Double
    let difficulty: Difficulty
    let pois: [POI]
    let coordinates: [Location]
    let navigationSteps: [NavigationStep]?
    let generatedAt: Date
    let startLocation: Location
    let colorIndex: Int

    enum Difficulty: String, Codable, CaseIterable, Sendable {
        case easy, moderate, challenging
    }

    var pathCoordinates: [CLLocationCoordinate2D] {
        coordinates.map(\.clCoordinate)
    }

    var attractions: [POI] {
        pois.filter { $0.category.isTouristAttraction }
    }

    var foodSpots: [POI] {
        pois.filter { $0.category.isFood }
    }

    func withPOIs(_ newPOIs: [POI]) -> Route {
        Route(
            id: id, name: name, description: description,
            durationMinutes: durationMinutes,
            distanceKilometers: distanceKilometers,
            difficulty: difficulty, pois: newPOIs,
            coordinates: coordinates,
            navigationSteps: navigationSteps,
            generatedAt: generatedAt,
            startLocation: startLocation,
            colorIndex: colorIndex
        )
    }

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        durationMinutes: Int,
        distanceKilometers: Double,
        difficulty: Difficulty = .easy,
        pois: [POI] = [],
        coordinates: [Location] = [],
        navigationSteps: [NavigationStep]? = nil,
        generatedAt: Date = Date(),
        startLocation: Location,
        colorIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.durationMinutes = durationMinutes
        self.distanceKilometers = distanceKilometers
        self.difficulty = difficulty
        self.pois = pois
        self.coordinates = coordinates
        self.navigationSteps = navigationSteps
        self.generatedAt = generatedAt
        self.startLocation = startLocation
        self.colorIndex = colorIndex
    }
}
