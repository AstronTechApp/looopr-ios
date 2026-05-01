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

    var isComplete: Bool { finishedAt != nil }

    var distanceKilometers: Double {
        distanceWalkedMeters / 1000
    }

    var durationMinutes: Int {
        Int(durationSeconds / 60)
    }

    var pathCoordinates: [CLLocationCoordinate2D] {
        routeCoordinates?.map(\.clCoordinate) ?? []
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
        routeCoordinates: [Location]? = nil
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
    }
}
