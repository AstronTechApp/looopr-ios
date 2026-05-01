import Foundation

actor KlookTicketProvider: TicketProviding {
    let providerName = "Klook"
    let commissionRate = 0.05

    private let apiClient: APIClient
    private let apiKey: String
    private let logger = AppLogger(category: "KlookTickets")

    init(apiClient: APIClient, apiKey: String) {
        self.apiClient = apiClient
        self.apiKey = apiKey
    }

    func searchTickets(for poi: POI) async throws -> [TicketOffer] {
        let endpoint = KlookAPI.searchActivities(
            query: poi.name,
            latitude: poi.location.latitude,
            longitude: poi.location.longitude,
            apiKey: apiKey
        )

        let response = try await apiClient.request(endpoint, responseType: KlookAPI.SearchResponse.self)

        guard let activities = response.result else { return [] }

        return activities.compactMap { activity -> TicketOffer? in
            guard let title = activity.title,
                  let urlString = activity.url,
                  let url = URL(string: urlString) else { return nil }

            return TicketOffer(
                providerName: providerName,
                productName: title,
                price: activity.price,
                bookingURL: url,
                commissionRate: commissionRate,
                imageURL: activity.imageUrl.flatMap(URL.init(string:)),
                providerRating: activity.score
            )
        }
    }
}
