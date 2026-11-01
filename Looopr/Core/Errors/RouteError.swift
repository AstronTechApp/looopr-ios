import Foundation

enum RouteError: Error, Equatable {
    case directionsUnavailable
    case throttled(waitSeconds: Double)
    case generationFailed(String)
    case noRoutesFound
    /// No candidate produced a usable loop; `detail` tallies why
    /// (e.g. `http_422_NoSegment:8`), for analytics.
    case noUsableRoutes(detail: String)
    case cancelled

    var userFacingMessage: String {
        switch self {
        case .directionsUnavailable:
            return "Walking directions are not available in this area. Try a different location."
        case .throttled(let wait):
            return "Too many requests. Retrying in \(Int(wait)) seconds..."
        case .generationFailed:
            return "Could not generate routes. Please try again."
        case .noRoutesFound, .noUsableRoutes:
            return "No walking routes found for this duration. Try a different time."
        case .cancelled:
            return ""
        }
    }
}
