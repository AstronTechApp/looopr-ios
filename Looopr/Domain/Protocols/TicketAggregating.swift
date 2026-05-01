import Foundation

protocol TicketAggregating: Sendable {
    func findBestTicket(for poi: POI) async -> TicketResult
}
