import Foundation

struct TicketOffer: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let providerName: String
    let productName: String
    let price: String?
    let bookingURL: URL
    let commissionRate: Double
    let imageURL: URL?
    let providerRating: Double?

    init(
        id: UUID = UUID(),
        providerName: String,
        productName: String,
        price: String? = nil,
        bookingURL: URL,
        commissionRate: Double,
        imageURL: URL? = nil,
        providerRating: Double? = nil
    ) {
        self.id = id
        self.providerName = providerName
        self.productName = productName
        self.price = price
        self.bookingURL = bookingURL
        self.commissionRate = commissionRate
        self.imageURL = imageURL
        self.providerRating = providerRating
    }
}
