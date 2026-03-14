import Foundation

enum RouteError: Error, Equatable {
    case directionsUnavailable
    case throttled(waitSeconds: Double)
    case generationFailed(String)
    case noRoutesFound
    case cancelled

    var userFacingMessage: String {
        switch self {
        case .directionsUnavailable:
            return "Walking directions are not available in this area. Try a different location."
        case .throttled(let wait):
            return "Too many requests. Retrying in \(Int(wait)) seconds..."
        case .generationFailed:
            return "Could not generate routes. Please try again."
        case .noRoutesFound:
            return "No walking routes found for this duration. Try a different time."
        case .cancelled:
            return ""
        }
    }
}
