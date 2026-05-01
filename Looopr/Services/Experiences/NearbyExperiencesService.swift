import CoreLocation
import Foundation

actor NearbyExperiencesService {
    private let apiClient: APIClient
    private let apiKey: String
    private let logger = AppLogger(category: "NearbyExperiences")

    init(apiClient: APIClient? = nil, apiKey: String = Secrets.getYourGuideAPIKey) {
        self.apiClient = apiClient ?? ServiceContainer.shared.resolve(APIClient.self)
        self.apiKey = apiKey
    }

    func fetchExperiences(near coordinate: CLLocationCoordinate2D) async -> [NearbyExperience] {
        guard !apiKey.isEmpty else {
            logger.info("No GYG API key configured, skipping experiences fetch")
            return []
        }

        let endpoint = GetYourGuideAPI.searchActivities(
            query: "things to do",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            apiKey: apiKey
        )

        do {
            let response = try await apiClient.request(
                endpoint,
                responseType: GetYourGuideAPI.SearchResponse.self
            )

            guard let activities = response.data?.activities else { return [] }

            return activities.compactMap { activity -> NearbyExperience? in
                guard let activityId = activity.activityId,
                      let title = activity.title,
                      let urlString = activity.url,
                      let url = URL(string: urlString) else { return nil }

                let priceStr: String? = {
                    guard let values = activity.price?.values,
                          let amount = values.amount else { return nil }
                    let currency = values.currencyCode ?? "EUR"
                    return String(format: "From %@ %.0f", currency, amount)
                }()

                return NearbyExperience(
                    id: activityId,
                    title: title,
                    description: activity.abstract ?? "",
                    price: priceStr,
                    rating: activity.rating,
                    reviewCount: activity.reviewsCount,
                    bookingURL: url,
                    imageURL: activity.pictures?.first?.url.flatMap(URL.init(string:))
                )
            }
        } catch {
            logger.error("Failed to fetch GYG experiences: \(error.localizedDescription)")
            return []
        }
    }
}
