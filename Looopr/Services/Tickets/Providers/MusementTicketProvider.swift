import Foundation

actor MusementTicketProvider: TicketProviding {
    let providerName = "Musement"
    let commissionRate = 0.06

    private let apiClient: APIClient
    private let apiKey: String
    private let logger = AppLogger(category: "MusementTickets")

    init(apiClient: APIClient, apiKey: String) {
        self.apiClient = apiClient
        self.apiKey = apiKey
    }

    func searchTickets(for poi: POI) async throws -> [TicketOffer] {
        let endpoint = MusementAPI.searchActivities(
            query: poi.name,
            latitude: poi.location.latitude,
            longitude: poi.location.longitude,
            apiKey: apiKey
        )

        let response = try await apiClient.request(endpoint, responseType: [MusementAPI.Activity].self)

        return response.compactMap { activity -> TicketOffer? in
            guard let title = activity.title,
                  let urlString = activity.url,
                  let url = URL(string: urlString) else { return nil }

            return TicketOffer(
                providerName: providerName,
                productName: title,
                price: activity.retailPrice?.formattedValue,
                bookingURL: url,
                commissionRate: commissionRate,
                imageURL: activity.coverImageUrl.flatMap(URL.init(string:)),
                providerRating: activity.reviewsAvg
            )
        }
    }
}
