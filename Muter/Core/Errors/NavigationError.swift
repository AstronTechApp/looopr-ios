import Foundation

enum NavigationError: Error, Equatable {
    case stepsUnavailable
    case rerouteFailed
    case locationUnavailable

    var userFacingMessage: String {
        switch self {
        case .stepsUnavailable:
            return "Could not load navigation steps."
        case .rerouteFailed:
            return "Could not recalculate route."
        case .locationUnavailable:
            return "Location is not available."
        }
    }
}
