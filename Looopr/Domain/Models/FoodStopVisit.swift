import Foundation

struct FoodStopVisit: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let poiId: UUID
    let name: String
    let checkedInAt: Date

    init(
        id: UUID = UUID(),
        poiId: UUID,
        name: String,
        checkedInAt: Date = Date()
    ) {
        self.id = id
        self.poiId = poiId
        self.name = name
        self.checkedInAt = checkedInAt
    }
}
