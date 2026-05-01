import Foundation

actor TiqetsTicketProvider: TicketProviding {
    let providerName = "Tiqets"
    let commissionRate = 0.07

    private let apiClient: APIClient
    private let apiKey: String
    private let logger = AppLogger(category: "TiqetsTickets")

    init(apiClient: APIClient, apiKey: String) {
        self.apiClient = apiClient
        self.apiKey = apiKey
    }

    func searchTickets(for poi: POI) async throws -> [TicketOffer] {
        let endpoint = TiqetsAPI.searchProducts(
            query: poi.name,
            latitude: poi.location.latitude,
            longitude: poi.location.longitude,
            apiKey: apiKey
        )

        let response = try await apiClient.request(endpoint, responseType: TiqetsAPI.SearchResponse.self)

        guard let products = response.products else { return [] }

        return products.compactMap { product -> TicketOffer? in
            guard let title = product.title,
                  let urlString = product.url,
                  let url = URL(string: urlString) else { return nil }

            let priceStr: String? = product.price.flatMap { price in
                guard let value = price.value else { return nil }
                let currency = price.currency ?? "EUR"
                return String(format: "%@ %.2f", currency, value)
            }

            return TicketOffer(
                providerName: providerName,
                productName: title,
                price: priceStr,
                bookingURL: url,
                commissionRate: commissionRate,
                imageURL: product.imageUrl.flatMap(URL.init(string:)),
                providerRating: product.rating?.average
            )
        }
    }
}
