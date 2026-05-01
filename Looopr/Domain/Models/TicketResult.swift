import Foundation

struct TicketResult: Sendable {
    let offers: [TicketOffer]
    let bestOffer: TicketOffer?
    let fallbackURL: URL?

    static let empty = TicketResult(offers: [], bestOffer: nil, fallbackURL: nil)
}
