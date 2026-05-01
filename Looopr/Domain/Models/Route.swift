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
    /// Whether this route includes a ferry or water taxi segment.
    /// Used to display a notice on the route card so walkers know in advance.
    let containsFerry: Bool

    enum Difficulty: String, Codable, CaseIterable, Sendable {
        case easy, moderate, challenging
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, description, durationMinutes, distanceKilometers
        case difficulty, pois, coordinates, navigationSteps
        case generatedAt, startLocation, colorIndex, containsFerry
    }

    var pathCoordinates: [CLLocationCoordinate2D] {
        coordinates.map(\.clCoordinate)
    }

    /// Base name without distance suffix, stripping any legacy "(X km)" / "(X mi)" if present.
    var baseName: String {
        name.replacingOccurrences(
            of: #"\s*\(\d+\.?\d*\s*(?:km|mi)\)"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)
    }

    var attractions: [POI] {
        pois.filter { $0.category.isTouristAttraction }
    }

    var foodSpots: [POI] {
        pois.filter { $0.category.isFood }
    }

    /// Attractions within 100m of the route (on the walking path)
    var onRouteAttractions: [POI] {
        let threshold = AppConfiguration.current.poi.onRouteThresholdMeters
        return attractions.filter { ($0.distanceFromRoute ?? .infinity) <= threshold }
    }

    /// Attractions 100-500m from the route (short detour)
    var nearRouteAttractions: [POI] {
        let threshold = AppConfiguration.current.poi.onRouteThresholdMeters
        return attractions.filter { ($0.distanceFromRoute ?? .infinity) > threshold }
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
            colorIndex: colorIndex,
            containsFerry: containsFerry
        )
    }

    // MARK: - Pace-Adjusted Duration

    /// Estimated walk duration in minutes at the given pace.
    /// Falls back to the API-reported `durationMinutes` if pace is invalid.
    func estimatedDuration(metresPerMinute pace: Double) -> Int {
        guard pace > 0 else { return durationMinutes }
        return Int((distanceKilometers * 1000 / pace).rounded())
    }

    /// Formatted duration label for the given pace (e.g. "45min", "1h 15min").
    func formattedDuration(metresPerMinute pace: Double) -> String {
        let minutes = estimatedDuration(metresPerMinute: pace)
        if minutes < 60 {
            return "\(minutes)min"
        }
        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining == 0 ? "\(hours)h" : "\(hours)h \(remaining)min"
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
        colorIndex: Int = 0,
        containsFerry: Bool = false
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
        self.containsFerry = containsFerry
    }

    // MARK: - Resilient Decoder

    /// Custom decoder that provides defaults for fields added after the initial release.
    /// Prevents "data couldn't be read because it is missing" when loading old saved routes.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        distanceKilometers = try container.decode(Double.self, forKey: .distanceKilometers)
        difficulty = try container.decodeIfPresent(Difficulty.self, forKey: .difficulty) ?? .easy
        pois = try container.decodeIfPresent([POI].self, forKey: .pois) ?? []
        coordinates = try container.decodeIfPresent([Location].self, forKey: .coordinates) ?? []
        navigationSteps = try container.decodeIfPresent([NavigationStep].self, forKey: .navigationSteps)
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt) ?? Date()
        startLocation = try container.decodeIfPresent(Location.self, forKey: .startLocation)
            ?? Location(latitude: coordinates.first?.latitude ?? 0,
                        longitude: coordinates.first?.longitude ?? 0)
        colorIndex = try container.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
        containsFerry = try container.decodeIfPresent(Bool.self, forKey: .containsFerry) ?? false
    }
}

// MARK: - MainActor convenience (SwiftUI views)

@MainActor
extension Route {
    /// Localised display name with distance in the user's preferred units.
    /// e.g. "Northwest Loop (5.4 km)" → "Circuito Noroeste (5.4 km)" in Spanish
    /// Translates stored English compass directions at display time — never stored.
    var displayName: String {
        let localizedName = L10n.RouteName.localized(baseName)
        return "\(localizedName) (\(distanceKilometers.formattedDistanceFromKm()))"
    }

    /// Estimated duration using the user's current walking pace setting.
    var paceAdjustedDuration: Int {
        let pace = SettingsManager.shared.walkingPace.metresPerMinute
        return estimatedDuration(metresPerMinute: pace)
    }

    /// Formatted duration label using the user's current walking pace setting.
    var paceAdjustedDurationLabel: String {
        let pace = SettingsManager.shared.walkingPace.metresPerMinute
        return formattedDuration(metresPerMinute: pace)
    }
}
