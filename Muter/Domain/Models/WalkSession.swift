import Foundation

struct WalkSession: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let routeId: UUID
    let startedAt: Date
    var finishedAt: Date?
    var distanceWalkedMeters: Double
    var durationSeconds: TimeInterval
    var photoCount: Int

    var isComplete: Bool { finishedAt != nil }

    var distanceKilometers: Double {
        distanceWalkedMeters / 1000
    }

    var durationMinutes: Int {
        Int(durationSeconds / 60)
    }

    init(
        id: UUID = UUID(),
        routeId: UUID,
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        distanceWalkedMeters: Double = 0,
        durationSeconds: TimeInterval = 0,
        photoCount: Int = 0
    ) {
        self.id = id
        self.routeId = routeId
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.distanceWalkedMeters = distanceWalkedMeters
        self.durationSeconds = durationSeconds
        self.photoCount = photoCount
    }
}
