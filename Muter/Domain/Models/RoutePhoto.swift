import Foundation

struct RoutePhoto: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let routeId: UUID
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let filename: String
    var note: String?

    init(
        id: UUID = UUID(),
        routeId: UUID,
        timestamp: Date = Date(),
        latitude: Double = 0,
        longitude: Double = 0,
        filename: String,
        note: String? = nil
    ) {
        self.id = id
        self.routeId = routeId
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.filename = filename
        self.note = note
    }
}
