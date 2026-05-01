import SwiftUI

@MainActor @Observable
final class FinishWalkViewModel {
    var session: WalkSession
    let route: Route

    private(set) var isSaving = false
    private(set) var hasPersisted = false

    // Saved-route state
    private(set) var isRouteSaved = false
    private(set) var isTogglingSavedRoute = false

    // Share-route state
    private(set) var isSharingRoute = false
    private(set) var shareURL: URL?
    private(set) var shareError: String?

    // Feedback
    var rating: Int = 0
    var selectedTags: Set<String> = []
    var feedbackComment: String = ""

    private let walkHistoryRepository: WalkHistoryRepository
    private let routeRepository: RouteRepository
    private let routeShareService: RouteShareService
    private let logger = AppLogger(category: "FinishWalk")

    init(
        session: WalkSession,
        route: Route,
        walkHistoryRepository: WalkHistoryRepository = ServiceContainer.shared.resolve(WalkHistoryRepository.self),
        routeRepository: RouteRepository = ServiceContainer.shared.resolve(RouteRepository.self),
        routeShareService: RouteShareService? = nil
    ) {
        self.session = session
        self.route = route
        self.walkHistoryRepository = walkHistoryRepository
        self.routeRepository = routeRepository
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

    /// Persists the walk session (with any submitted feedback) to local history.
    /// Idempotent — calling more than once is a no-op.
    func persistWalkIfNeeded() {
        guard !hasPersisted else { return }
        isSaving = true

        // Attach route metadata for profile/history display
        session.routeName = route.baseName
        session.elevationGainMeters = Double(RouteSelectionViewModel.estimatedElevation(for: route))
        session.routeColorIndex = route.colorIndex
        session.routeCoordinates = route.coordinates

        // Attach feedback if provided
        if rating > 0 {
            let comment = feedbackComment.trimmingCharacters(in: .whitespacesAndNewlines)
            session.feedback = WalkFeedback(
                rating: rating,
                tags: Array(selectedTags),
                comment: comment.isEmpty ? nil : comment
            )
        }

        do {
            try walkHistoryRepository.save(session)
            hasPersisted = true
            logger.info("Walk session saved: \(session.id), feedback: \(session.feedback != nil ? "\(rating) stars" : "none")")
        } catch {
            logger.error("Failed to save walk session: \(error)")
        }

        isSaving = false
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
