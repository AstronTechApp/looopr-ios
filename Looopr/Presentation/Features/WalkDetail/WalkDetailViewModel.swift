import Foundation
import SwiftUI

@MainActor @Observable
final class WalkDetailViewModel {

    // MARK: - State

    let session: WalkSession

    private(set) var isSharing = false
    private(set) var shareURL: URL?
    private(set) var shareError: String?

    // MARK: - Dependencies

    private let routeShareService: RouteShareService

    init(
        session: WalkSession,
        routeShareService: RouteShareService? = nil
    ) {
        self.session = session
        self.routeShareService = routeShareService
            ?? ServiceContainer.shared.resolveOptional(RouteShareService.self)
            ?? RouteShareService()
    }

    // MARK: - Computed

    var routeName: String {
        session.routeName ?? "Walk"
    }

    var walkDate: String {
        let date = session.finishedAt ?? session.startedAt
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }

    var walkTime: String {
        let date = session.finishedAt ?? session.startedAt
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    var formattedDistance: String {
        session.distanceWalkedMeters.formattedDistance()
    }

    var formattedDuration: String {
        let totalSeconds = Int(session.durationSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %02dmin", hours, minutes)
        }
        return "\(minutes)min"
    }

    var formattedSteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: session.stepCount)) ?? "\(session.stepCount)"
    }

    var formattedElevation: String {
        guard let elev = session.elevationGainMeters else { return "—" }
        return elev.formattedElevation()
    }

    var hasElevation: Bool {
        session.elevationGainMeters != nil && session.elevationGainMeters! > 0
    }

    var hasSteps: Bool {
        session.stepCount > 0
    }

    var routeColor: Color {
        if let colorIndex = session.routeColorIndex {
            return AppTheme.routeColor(for: colorIndex)
        }
        return LoooprTheme.Colors.primary
    }

    // MARK: - Sharing

    /// Uploads the walked route and returns a shareable URL, or nil on failure.
    func shareRoute() async -> URL? {
        let coords = session.routeCoordinates ?? []
        guard !coords.isEmpty else {
            shareError = "This walk has no route data to share."
            return nil
        }

        isSharing = true
        shareError = nil
        defer { isSharing = false }

        let start = coords.first ?? Location(latitude: 0, longitude: 0)
        let route = Route(
            id: session.routeId,
            name: routeName,
            durationMinutes: session.durationMinutes,
            distanceKilometers: session.distanceKilometers,
            coordinates: coords,
            startLocation: start,
            colorIndex: session.routeColorIndex ?? 0
        )

        do {
            let url = try await routeShareService.uploadRoute(route)
            shareURL = url
            return url
        } catch {
            shareError = error.localizedDescription
            return nil
        }
    }
}
