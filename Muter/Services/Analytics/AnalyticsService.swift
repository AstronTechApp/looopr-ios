import os

final class LiveAnalyticsService: AnalyticsTracking, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.pedro.muter", category: "Analytics")

    func track(_ event: AnalyticsEvent) {
        logger.info("Event: \(String(describing: event), privacy: .public)")
    }
}
