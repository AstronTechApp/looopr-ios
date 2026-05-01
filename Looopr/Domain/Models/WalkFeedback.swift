import Foundation

struct WalkFeedback: Codable, Sendable, Hashable {
    let rating: Int
    let tags: [String]
    let comment: String?

    init(rating: Int, tags: [String] = [], comment: String? = nil) {
        self.rating = min(max(rating, 1), 5)
        self.tags = tags
        self.comment = comment
    }
}
