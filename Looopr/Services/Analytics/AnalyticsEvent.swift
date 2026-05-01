import Foundation

enum AnalyticsEvent: Sendable {
    case routeGenerated(count: Int, minutes: Int)
    case routeSelected(routeId: UUID)
    case walkStarted(routeId: UUID)
    case walkCompleted(routeId: UUID, durationSeconds: TimeInterval)
    case poiViewed(poiId: UUID, category: String)
    case bookingLinkTapped(poiId: UUID, partner: String)
    case photoTaken(routeId: UUID)
    case collageCreated(template: String)
    case routeShared(routeId: UUID, platform: String)
    case feedbackSubmitted
    case paywallShown
    case subscriptionStarted
    case offRouteDetected(routeId: UUID)
    case rerouteTriggered(routeId: UUID)
}
