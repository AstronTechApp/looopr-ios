import Foundation

struct NearbyExperience: Identifiable {
    let id: Int
    let title: String
    let description: String
    let price: String?
    let rating: Double?
    let reviewCount: Int?
    let bookingURL: URL
    let imageURL: URL?
}
