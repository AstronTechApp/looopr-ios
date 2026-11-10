import CoreLocation
import Foundation

// Moved out of WalkNavigationViewModel.swift (1.5) unchanged.

// MARK: - Supporting types

/// Which way the user is walking through `activePolyline`.
///
/// Direction is read state for the active route. Reroutes and wrong-way flips
/// now replace `activePolyline` with a newly computed route and reset this to
/// `.forward`, so turn-by-turn instructions stay aligned with the map shape.
enum WalkDirection {
    case forward
    case reverse

    var toggled: WalkDirection { self == .forward ? .reverse : .forward }
}

enum RouteToastStyle {
    case success
    case status
    case error
}

enum RouteFlipPhase: Equatable {
    case idle
    case awaitingConfirmation
    case preparing
    case recomputing(pathPoints: Int)
    case applying(steps: Int)
    case succeeded(steps: Int)
    case failed(String)

    var debugLabel: String {
        switch self {
        case .idle:
            return "idle"
        case .awaitingConfirmation:
            return "awaiting user"
        case .preparing:
            return "preparing"
        case .recomputing(let pathPoints):
            return "recomputing (\(pathPoints) pts)"
        case .applying(let steps):
            return "applying (\(steps) steps)"
        case .succeeded(let steps):
            return "succeeded (\(steps) steps)"
        case .failed(let reason):
            return "failed: \(reason)"
        }
    }
}
