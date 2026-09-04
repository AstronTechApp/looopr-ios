import SwiftUI

@MainActor @Observable
final class FinishWalkViewModel {
    var session: WalkSession
    let route: Route

    private(set) var isSaving = false
    private(set) var hasPersisted = false
    private var didSubmitFeedback = false

    // Saved-route state
    private(set) var isRouteSaved = false
    private(set) var isTogglingSavedRoute = false

    // Share-route state
    private(set) var isSharingRoute = false
    private(set) var shareURL: URL?
    private(set) var shareError: String?

    // GPX export state
    private(set) var gpxFileURL: URL?
    private(set) var gpxError: String?

    /// Whether this walk has a recorded GPS track that can be exported.
    var canExportGPX: Bool { session.hasTrack }

    // Apple Health state
    private(set) var healthSaveState: HealthSaveState = .idle

    // Feedback
    var rating: Int = 0
    var selectedTags: Set<String> = []
    var feedbackComment: String = ""

    private let walkHistoryRepository: WalkHistoryRepository
    private let routeRepository: RouteRepository
    private let routeShareService: RouteShareService
    private let analytics: AnalyticsTracking
    private let healthService: HealthWorkoutSaving?
    private let logger = AppLogger(category: "FinishWalk")

    init(
        session: WalkSession,
        route: Route,
        walkHistoryRepository: WalkHistoryRepository = ServiceContainer.shared.resolve(WalkHistoryRepository.self),
        routeRepository: RouteRepository = ServiceContainer.shared.resolve(RouteRepository.self),
        routeShareService: RouteShareService? = nil,
        analytics: AnalyticsTracking = ServiceContainer.shared.resolve(AnalyticsTracking.self),
        healthService: HealthWorkoutSaving? = ServiceContainer.shared.resolveOptional(HealthWorkoutSaving.self)
    ) {
        self.session = session
        self.route = route
        self.walkHistoryRepository = walkHistoryRepository
        self.routeRepository = routeRepository
        self.analytics = analytics
        self.healthService = healthService
        self.routeShareService = routeShareService
            ?? ServiceContainer.shared.resolveOptional(RouteShareService.self)
            ?? RouteShareService()
        self.isRouteSaved = routeRepository.isRouteSaved(route.id)
    }

    // MARK: - Computed

    var formattedDuration: String {
        let totalSeconds = Int(session.durationSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedDistance: String {
        session.distanceWalkedMeters.formattedDistance()
    }

    var formattedSteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: session.stepCount)) ?? "\(session.stepCount)"
    }

    var routeColor: Color {
        AppTheme.routeColor(for: route.colorIndex)
    }

    var visitedFoodStops: [FoodStopVisit] {
        session.visitedFoodStops
    }

    var hasVisitedFoodStops: Bool {
        !session.visitedFoodStops.isEmpty
    }

    var hasFeedback: Bool {
        rating > 0
    }

    // MARK: - Actions

    /// Persists the walk session to local history. Called as soon as the
    /// finish screen appears, so the walk survives a swipe-back, crash, or
    /// force-quit on the celebration screen. Idempotent.
    func persistWalkIfNeeded() {
        guard !hasPersisted else { return }
        isSaving = true

        // Attach route metadata for profile/history display
        session.routeName = route.baseName
        session.elevationGainMeters = Double(RouteSelectionViewModel.estimatedElevation(for: route))
        session.routeColorIndex = route.colorIndex
        session.routeCoordinates = route.coordinates

        saveSession()
        hasPersisted = true
        isSaving = false

        if SettingsManager.shared.saveWalksToHealth {
            Task { await saveToHealth() }
        }
    }

    /// Writes the walk to Apple Health as a workout. Safe to call more than
    /// once: an already-saved walk is a no-op, and the service's sync
    /// identifier turns any retry into an update rather than a duplicate.
    func saveToHealth() async {
        guard let healthService, healthService.isAvailable else { return }
        if session.healthKitWorkoutID != nil {
            healthSaveState = .saved
            return
        }
        guard healthService.authorization == .authorized else {
            healthSaveState = .failed(L10n.Health.notAuthorized)
            return
        }

        healthSaveState = .saving
        do {
            let workoutID = try await healthService.saveWalk(session)
            session.healthKitWorkoutID = workoutID
            saveSession()
            healthSaveState = .saved
        } catch {
            healthSaveState = .failed(error.localizedDescription)
            logger.error("Save to Health failed: \(error)")
        }
    }

    /// Attaches any feedback given after the initial save and re-saves
    /// (repository saves upsert by session id). Called when the user leaves
    /// the screen. Safe to call with no feedback — it's a no-op then.
    func finalizeFeedbackIfNeeded() {
        persistWalkIfNeeded()
        guard rating > 0, !didSubmitFeedback else { return }
        let comment = feedbackComment.trimmingCharacters(in: .whitespacesAndNewlines)
        session.feedback = WalkFeedback(
            rating: rating,
            tags: Array(selectedTags),
            comment: comment.isEmpty ? nil : comment
        )
        analytics.track(.feedbackSubmitted(rating: rating, tags: Array(selectedTags)))
        didSubmitFeedback = true
        saveSession()
    }

    private func saveSession() {
        do {
            try walkHistoryRepository.save(session)
            logger.info("Walk session saved: \(session.id), feedback: \(session.feedback != nil ? "\(rating) stars" : "none")")
            // Mirror to the cloud so history survives reinstall/device loss.
            let repository = walkHistoryRepository
            let snapshot = session
            Task.detached(priority: .utility) {
                await repository.pushToCloudIfSignedIn(snapshot)
            }
        } catch {
            logger.error("Failed to save walk session: \(error)")
        }
    }

    /// Toggles whether the walked route is bookmarked for future use.
    func toggleSavedRoute() {
        guard !isTogglingSavedRoute else { return }
        isTogglingSavedRoute = true
        defer { isTogglingSavedRoute = false }

        do {
            if isRouteSaved {
                try routeRepository.removeSavedRoute(route.id)
                isRouteSaved = false
                logger.info("Route unsaved: \(route.id)")
            } else {
                try routeRepository.saveRoute(route)
                isRouteSaved = true
                logger.info("Route saved: \(route.id)")
            }
        } catch {
            logger.error("Toggle saved route failed: \(error)")
        }
    }

    /// Uploads the route to the share backend and returns a shareable URL.
    /// Returns `nil` if uploading fails — caller can show an error.
    func shareRoute() async -> URL? {
        if let url = shareURL { return url }
        isSharingRoute = true
        shareError = nil
        defer { isSharingRoute = false }

        do {
            let url = try await routeShareService.uploadRoute(route)
            shareURL = url
            return url
        } catch {
            shareError = error.localizedDescription
            logger.error("Share route failed: \(error)")
            return nil
        }
    }

    /// Writes the walked track to a temporary `.gpx` file for the share
    /// sheet (Strava web upload, Komoot, Files, …). Returns `nil` on failure.
    func exportGPX() -> URL? {
        gpxError = nil
        do {
            let url = try GPXExporter.writeTemporaryFile(for: session)
            gpxFileURL = url
            analytics.track(.gpxExported(routeId: route.id, pointCount: session.trackPoints?.count ?? 0))
            return url
        } catch {
            gpxError = error.localizedDescription
            logger.error("GPX export failed: \(error)")
            return nil
        }
    }

    func toggleTag(_ tagId: String) {
        if selectedTags.contains(tagId) {
            selectedTags.remove(tagId)
        } else {
            selectedTags.insert(tagId)
        }
    }

    func shareText() -> String {
        var text = "Just completed a \(formattedDistance) walk"
        text += " in \(formattedDuration) on Looopr!"
        if session.stepCount > 0 {
            text += " \(formattedSteps) steps."
        }
        if hasVisitedFoodStops {
            text += " Stopped at \(visitedFoodStops.count) food spot\(visitedFoodStops.count == 1 ? "" : "s")."
        }
        return text
    }
}

// MARK: - Health save state

/// Progress of writing a walk to Apple Health, shared by the finish and
/// walk-detail screens.
enum HealthSaveState: Equatable {
    case idle
    case saving
    case saved
    case failed(String)
}
