import Foundation

struct UserProfile: Codable, Sendable {
    let id: UUID
    var displayName: String?
    var email: String?
    var isPremium: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        displayName: String? = nil,
        email: String? = nil,
        isPremium: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.isPremium = isPremium
        self.createdAt = createdAt
    }
}
