import Foundation

enum POIError: Error, Equatable {
    case discoveryFailed
    case enrichmentFailed(String)
    case noResults

    var userFacingMessage: String {
        switch self {
        case .discoveryFailed:
            return "Could not find points of interest nearby."
        case .enrichmentFailed:
            return "Could not load place details."
        case .noResults:
            return "No points of interest found along this route."
        }
    }
}
