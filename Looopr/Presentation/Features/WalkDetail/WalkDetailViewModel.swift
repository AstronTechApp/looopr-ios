import Foundation
import SwiftUI

@MainActor @Observable
final class WalkDetailViewModel {

    // MARK: - State

    private(set) var session: WalkSession

    private(set) var isSharing = false
    private(set) var shareURL: URL?
    private(set) var shareError: String?
    private(set) var gpxFileURL: URL?
    private(set) var gpxError: String?

    /// Whether this walk has a recorded GPS track that can be exported.
    var canExportGPX: Bool { session.hasTrack }

    // Apple Health
    private(set) var healthSaveState: HealthSaveState

    /// Whether the "Save to Apple Health" action makes sense for this walk on
    /// this device. Permission is requested on tap if still undecided.
    var canSaveToHealth: Bool {
        guard let healthService, healthService.isAvailable else { return false }
        return session.distanceWalkedMeters > 0 || session.hasTrack
    }

    /// Writes the walk to Apple Health, asking for permission first if the
    /// user hasn't decided yet. Already-saved walks report `.saved` at once.
    func saveToHealth() async {
        guard let healthService else { return }
        if session.healthKitWorkoutID != nil {
            healthSaveState = .saved
            return
        }

        var authorization = healthService.authorization
        if authorization == .notDetermined {
            authorization = (try? await healthService.requestAuthorization()) ?? .denied
        }
        guard authorization == .authorized else {
            healthSaveState = .failed(L10n.Health.notAuthorized)
            return
        }

        healthSaveState = .saving
        do {
            let workoutID = try await healthService.saveWalk(session)
            session.healthKitWorkoutID = workoutID
            try? walkHistoryRepository.save(session)
            healthSaveState = .saved
        } catch {
            healthSaveState = .failed(error.localizedDescription)
        }
    }

    /// Writes the walked track to a temporary `.gpx` file for the share sheet.
    func exportGPX() -> URL? {
        gpxError = nil
        do {
            let url = try GPXExporter.writeTemporaryFile(for: session)
            gpxFileURL = url
            return url
        } catch {
            gpxError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Dependencies

    private let routeShareService: RouteShareService
    private let healthService: HealthWorkoutSaving?
    private let walkHistoryRepository: WalkHistoryRepository

    init(
        session: WalkSession,
        routeShareService: RouteShareService? = nil,
        healthService: HealthWorkoutSaving? = ServiceContainer.shared.resolveOptional(HealthWorkoutSaving.self),
        walkHistoryRepository: WalkHistoryRepository = ServiceContainer.shared.resolve(WalkHistoryRepository.self)
    ) {
        self.session = session
        self.routeShareService = routeShareService
            ?? ServiceContainer.shared.resolveOptional(RouteShareService.self)
            ?? RouteShareService()
        self.healthService = healthService
        self.walkHistoryRepository = walkHistoryRepository
        self.healthSaveState = session.healthKitWorkoutID == nil ? .idle : .saved
    }

    // MARK: - Computed

    var routeName: String {
        session.routeName.map(L10n.RouteName.localized) ?? L10n.Misc.walk
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
