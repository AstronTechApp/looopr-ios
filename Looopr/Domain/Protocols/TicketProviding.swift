import Foundation

protocol TicketProviding: Sendable {
    var providerName: String { get }
    var commissionRate: Double { get }
    func searchTickets(for poi: POI) async throws -> [TicketOffer]
}
