import Foundation

protocol AnalyticsTracking: Sendable {
    func track(_ event: AnalyticsEvent)
}
