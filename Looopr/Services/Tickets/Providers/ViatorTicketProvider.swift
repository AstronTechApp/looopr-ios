import Foundation

actor ViatorTicketProvider: TicketProviding {
    let providerName = "Viator"
    let commissionRate = 0.08

    private let apiClient: APIClient
    private let apiKey: String
    private let logger = AppLogger(category: "ViatorTickets")

    init(apiClient: APIClient, apiKey: String) {
        self.apiClient = apiClient
        self.apiKey = apiKey
    }

    func searchTickets(for poi: POI) async throws -> [TicketOffer] {
        let endpoint = ViatorAPI.searchProducts(
            query: poi.name,
            latitude: poi.location.latitude,
            longitude: poi.location.longitude,
            apiKey: apiKey
        )

        let response = try await apiClient.request(endpoint, responseType: ViatorAPI.SearchResponse.self)

        guard let products = response.products else { return [] }

        return products.compactMap { product -> TicketOffer? in
            guard let title = product.title,
                  let urlString = product.productUrl,
                  let url = URL(string: urlString) else { return nil }

            return TicketOffer(
                providerName: providerName,
                productName: title,
                price: product.pricing?.summary?.fromPrice,
                bookingURL: url,
                commissionRate: commissionRate,
                imageURL: product.images?.first?.imageSource.flatMap(URL.init(string:)),
                providerRating: product.reviews?.combinedAverageRating
            )
        }
    }
}
