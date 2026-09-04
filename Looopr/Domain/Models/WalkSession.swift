import CoreLocation
import Foundation

struct WalkSession: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let routeId: UUID
    let startedAt: Date
    var finishedAt: Date?
    var distanceWalkedMeters: Double
    var durationSeconds: TimeInterval
    var stepCount: Int
    var visitedFoodStops: [FoodStopVisit]
    var feedback: WalkFeedback?
    var routeName: String?
    var elevationGainMeters: Double?
    var routeColorIndex: Int?
    var routeCoordinates: [Location]?
    /// What the route forecast promised when the walk started — kept alongside
    /// the actuals so planned-vs-actual is directly queryable.
    var plannedDurationMinutes: Int?
    var plannedDistanceMeters: Double?
    /// The GPS track actually walked, in chronological order. `nil` for walks
    /// recorded before track recording existed. This is what GPX export and
    /// Strava upload are built from — `routeCoordinates` is only the plan.
    var trackPoints: [TrackPoint]?
    /// Identifier of the HKWorkout this walk was saved as in Apple Health,
    /// or `nil` when it hasn't been (or the user has that turned off).
    var healthKitWorkoutID: UUID?

    var isComplete: Bool { finishedAt != nil }
    var hasTrack: Bool { (trackPoints?.count ?? 0) >= 2 }

    var distanceKilometers: Double {
        distanceWalkedMeters / 1000
    }

    var durationMinutes: Int {
        Int(durationSeconds / 60)
    }

    /// The *planned* loop. Use `trackCoordinates` for what was actually walked.
    var pathCoordinates: [CLLocationCoordinate2D] {
        routeCoordinates?.map(\.clCoordinate) ?? []
    }

    /// The GPS track actually walked, in order; empty when none was recorded.
    var trackCoordinates: [CLLocationCoordinate2D] {
        trackPoints?.map(\.clCoordinate) ?? []
    }

    /// What a map of this walk should draw as its main line: the walked
    /// track when there is one, otherwise the planned loop (older walks).
    var displayCoordinates: [CLLocationCoordinate2D] {
        hasTrack ? trackCoordinates : pathCoordinates
    }

    init(
        id: UUID = UUID(),
        routeId: UUID,
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        distanceWalkedMeters: Double = 0,
        durationSeconds: TimeInterval = 0,
        stepCount: Int = 0,
        visitedFoodStops: [FoodStopVisit] = [],
        feedback: WalkFeedback? = nil,
        routeName: String? = nil,
        elevationGainMeters: Double? = nil,
        routeColorIndex: Int? = nil,
        routeCoordinates: [Location]? = nil,
        plannedDurationMinutes: Int? = nil,
        plannedDistanceMeters: Double? = nil,
        trackPoints: [TrackPoint]? = nil,
        healthKitWorkoutID: UUID? = nil
    ) {
        self.id = id
        self.routeId = routeId
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.distanceWalkedMeters = distanceWalkedMeters
        self.durationSeconds = durationSeconds
        self.stepCount = stepCount
        self.visitedFoodStops = visitedFoodStops
        self.feedback = feedback
        self.routeName = routeName
        self.elevationGainMeters = elevationGainMeters
        self.routeColorIndex = routeColorIndex
        self.routeCoordinates = routeCoordinates
        self.plannedDurationMinutes = plannedDurationMinutes
        self.plannedDistanceMeters = plannedDistanceMeters
        self.trackPoints = trackPoints
        self.healthKitWorkoutID = healthKitWorkoutID
    }

    // Backward-compatible decoding. Sessions saved before the photo/collage
    // features were removed include `photoCount` and `collagePhotoId` — those
    // fields are intentionally ignored here so old on-device history still loads.
    private enum CodingKeys: String, CodingKey {
        case id
        case routeId
        case startedAt
        case finishedAt
        case distanceWalkedMeters
        case durationSeconds
        case stepCount
        case visitedFoodStops
        case feedback
        case routeName
        case elevationGainMeters
        case routeColorIndex
        case routeCoordinates
        case plannedDurationMinutes
        case plannedDistanceMeters
        case trackPoints
        case healthKitWorkoutID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        routeId = try container.decode(UUID.self, forKey: .routeId)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        finishedAt = try container.decodeIfPresent(Date.self, forKey: .finishedAt)
        distanceWalkedMeters = try container.decode(Double.self, forKey: .distanceWalkedMeters)
        durationSeconds = try container.decode(TimeInterval.self, forKey: .durationSeconds)
        stepCount = try container.decodeIfPresent(Int.self, forKey: .stepCount) ?? 0
        visitedFoodStops = try container.decodeIfPresent([FoodStopVisit].self, forKey: .visitedFoodStops) ?? []
        feedback = try container.decodeIfPresent(WalkFeedback.self, forKey: .feedback)
        routeName = try container.decodeIfPresent(String.self, forKey: .routeName)
        elevationGainMeters = try container.decodeIfPresent(Double.self, forKey: .elevationGainMeters)
        routeColorIndex = try container.decodeIfPresent(Int.self, forKey: .routeColorIndex)
        routeCoordinates = try container.decodeIfPresent([Location].self, forKey: .routeCoordinates)
        plannedDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .plannedDurationMinutes)
        plannedDistanceMeters = try container.decodeIfPresent(Double.self, forKey: .plannedDistanceMeters)
        trackPoints = try container.decodeIfPresent([TrackPoint].self, forKey: .trackPoints)
        healthKitWorkoutID = try container.decodeIfPresent(UUID.self, forKey: .healthKitWorkoutID)
    }
}
