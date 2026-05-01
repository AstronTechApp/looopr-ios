import os

final class LiveAnalyticsService: AnalyticsTracking, @unchecked Sendable {
    private let logger = Logger(subsystem: "nl.astrontech.looopr", category: "Analytics")

    func track(_ event: AnalyticsEvent) {
        logger.info("Event: \(String(describing: event), privacy: .public)")
    }
}
