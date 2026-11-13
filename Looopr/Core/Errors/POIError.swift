import Foundation

enum POIError: Error, Equatable {
    case discoveryFailed
    case enrichmentFailed(String)
    case noResults
    /// Searches failed (throttled, offline, server error) and nothing was
    /// found. Not the same as "there are no sights along this loop".
    case searchUnavailable

    var userFacingMessage: String {
        switch self {
        case .discoveryFailed:
            return "Could not find points of interest nearby."
        case .enrichmentFailed:
            return "Could not load place details."
        case .noResults:
            return "No points of interest found along this route."
        case .searchUnavailable:
            return "Could not load the sights along this route."
        }
    }
}
