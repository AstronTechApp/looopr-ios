import ActivityKit
import CoreLocation
import Foundation

/// Lightweight manager that bridges the existing walk navigation flow to iOS Live Activities.
/// Call `startActivity`, `updateActivity`, and `endActivity` from the walk view model
/// without changing any existing walk tracking logic.
///
/// **Rate-limit aware**: Apple throttles ActivityKit updates to roughly once every
/// 15 seconds. This manager enforces a minimum 8-second interval between updates
/// and serialises calls so fire-and-forget Tasks never pile up.
///
/// **Timer**: Elapsed time is rendered on-device via `Text(date, style: .timer)`,
/// so it counts every second without any updates from the app. Only distance, pace,
/// POI, and progress data require periodic pushes.
@MainActor
final class LiveActivityManager {

    // MARK: - Singleton (also registered in ServiceContainer)

    static let shared = LiveActivityManager()

    // MARK: - Configuration

    /// Minimum seconds between consecutive ActivityKit updates.
    /// Apple's internal throttle is ~15s; 8s keeps us safely under while
    /// still feeling responsive on the Dynamic Island.
    private let minimumUpdateInterval: TimeInterval = 8

    /// How long before iOS considers the Live Activity stale and dims it.
    /// If the app is force-quit, the activity will auto-dismiss after this window.
    private let staleDateInterval: TimeInterval = 5 * 60  // 5 minutes

    // MARK: - State

    private var currentActivity: Activity<WalkActivityAttributes>?
    private let logger = AppLogger(category: "LiveActivity")

    /// The walk start time — passed through every ContentState so the
    /// system timer (`Text(date, style: .timer)`) keeps counting.
    private var walkStartDate: Date?

    /// Timestamp of the last successful update push to ActivityKit.
    private var lastUpdateTime: Date?

    /// Guard against overlapping `activity.update()` calls.
    /// If an update is already in-flight, we skip rather than queue another.
    private var isUpdating = false

    /// Holds the most recent state so we can push it once the throttle window reopens.
    private var pendingState: WalkActivityAttributes.ContentState?

    // MARK: - Public API

    /// Starts a new Live Activity for a walk session.
    /// - Parameters:
    ///   - routeName: Display name of the route
    ///   - totalDistanceMeters: Total route distance in meters
    ///   - totalPOIs: Number of POIs on the route
    ///   - startDate: The moment the walk began — used for the on-device timer
    func startActivity(
        routeName: String,
        totalDistanceMeters: Double,
        totalPOIs: Int,
        startDate: Date
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.info("Live Activities not enabled — skipping start")
            return
        }

        // End any lingering activity from a previous session
        endActivity()

        self.walkStartDate = startDate

        let attributes = WalkActivityAttributes(
            routeName: routeName,
            totalDistanceMeters: totalDistanceMeters,
            totalPOIs: totalPOIs
        )

        let initialState = WalkActivityAttributes.ContentState(
            walkStartDate: startDate,
            distanceWalkedMeters: 0,
            currentPaceMetersPerSecond: 0,
            nextPOIName: nil,
            nextPOIDistanceMeters: nil,
            progressFraction: 0,
            nextDirectionArrow: nil,
            nextDirectionText: nil,
            nextDirectionDistanceMeters: nil
        )

        do {
            let content = ActivityContent(state: initialState, staleDate: Date().addingTimeInterval(staleDateInterval))
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivity = activity
            lastUpdateTime = Date()
            isUpdating = false
            pendingState = nil
            logger.info("Live Activity started — id: \(activity.id)")
        } catch {
            logger.error("Failed to start Live Activity: \(error)")
        }
    }

    /// Updates the Live Activity with current walk metrics.
    ///
    /// The elapsed time is **not** passed here — it is rendered on-device via
    /// `Text(walkStartDate, style: .timer)`. Only distance, pace, POI, and
    /// progress need periodic updates.
    ///
    /// Calls are **throttled** to `minimumUpdateInterval` and **serialised** so
    /// only one `activity.update()` is in-flight at a time.
    func updateActivity(
        distanceWalkedMeters: Double,
        currentPaceMetersPerSecond: Double,
        nextPOIName: String?,
        nextPOIDistanceMeters: Double?,
        progressFraction: Double,
        nextDirectionArrow: String? = nil,
        nextDirectionText: String? = nil,
        nextDirectionDistanceMeters: Double? = nil
    ) {
        guard currentActivity != nil,
              let startDate = walkStartDate else { return }

        let newState = WalkActivityAttributes.ContentState(
            walkStartDate: startDate,
            distanceWalkedMeters: distanceWalkedMeters,
            currentPaceMetersPerSecond: currentPaceMetersPerSecond,
            nextPOIName: nextPOIName,
            nextPOIDistanceMeters: nextPOIDistanceMeters,
            progressFraction: progressFraction,
            nextDirectionArrow: nextDirectionArrow,
            nextDirectionText: nextDirectionText,
            nextDirectionDistanceMeters: nextDirectionDistanceMeters
        )

        // Always store the latest state
        pendingState = newState

        // Skip if an update is already in-flight
        guard !isUpdating else { return }

        // Enforce minimum interval between pushes
        if let lastUpdate = lastUpdateTime,
           Date().timeIntervalSince(lastUpdate) < minimumUpdateInterval {
            return
        }

        pushPendingState()
    }

    /// Ends the current Live Activity. Called when the walk finishes.
    func endActivity() {
        guard let activity = currentActivity else { return }

        // Clear update state immediately so no more updates are attempted
        let activityToEnd = activity
        currentActivity = nil
        pendingState = nil
        isUpdating = false
        lastUpdateTime = nil

        let finalState = WalkActivityAttributes.ContentState(
            walkStartDate: walkStartDate ?? Date(),
            distanceWalkedMeters: 0,
            currentPaceMetersPerSecond: 0,
            nextPOIName: nil,
            nextPOIDistanceMeters: nil,
            progressFraction: 1.0,
            nextDirectionArrow: nil,
            nextDirectionText: nil,
            nextDirectionDistanceMeters: nil
        )

        walkStartDate = nil

        let content = ActivityContent(state: finalState, staleDate: nil)

        Task {
            await activityToEnd.end(content, dismissalPolicy: .immediate)
            logger.info("Live Activity ended — id: \(activityToEnd.id)")
        }
    }

    /// Ends ALL Live Activities for this app — both the tracked `currentActivity`
    /// and any orphaned activities left behind by a force-quit or crash.
    /// Call this on app launch to clean up stale activities from a previous session.
    func endAllActivities() {
        // End the tracked activity through the normal path
        endActivity()

        // Also sweep any orphaned activities the system still has running
        sweepOrphanedActivities()
    }

    /// Ends only orphaned Live Activities — ones left behind by a previous
    /// force-quit or crash — while keeping the current walk's activity alive.
    /// Call this when the app moves to background so the user can switch apps
    /// mid-walk without losing the Dynamic Island.
    func endOrphanedActivities() {
        sweepOrphanedActivities()
    }

    /// Internal sweep that ends every activity whose id doesn't match the
    /// currently tracked activity.
    private func sweepOrphanedActivities() {
        let currentId = currentActivity?.id
        Task {
            for activity in Activity<WalkActivityAttributes>.activities {
                // Skip the activity we're currently managing
                if activity.id == currentId { continue }

                let finalState = WalkActivityAttributes.ContentState(
                    walkStartDate: Date(),
                    distanceWalkedMeters: 0,
                    currentPaceMetersPerSecond: 0,
                    nextPOIName: nil,
                    nextPOIDistanceMeters: nil,
                    progressFraction: 0,
                    nextDirectionArrow: nil,
                    nextDirectionText: nil,
                    nextDirectionDistanceMeters: nil
                )
                let content = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(content, dismissalPolicy: .immediate)
                logger.info("Ended orphaned Live Activity — id: \(activity.id)")
            }
        }
    }

    // MARK: - Private

    /// Pushes the pending state to ActivityKit, guarded by `isUpdating` to prevent overlap.
    private func pushPendingState() {
        guard let activity = currentActivity,
              let state = pendingState else { return }

        isUpdating = true
        pendingState = nil

        // Reset the stale date with each update so the activity stays fresh
        // as long as the app is actively pushing. If the app dies, iOS will
        // dim/dismiss the activity after staleDateInterval.
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(staleDateInterval))

        Task { [weak self] in
            await activity.update(content)
            guard let self else { return }
            await MainActor.run {
                self.isUpdating = false
                self.lastUpdateTime = Date()

                // If a newer state arrived while we were updating, push it now
                // (only if the throttle window allows — otherwise it waits for
                // the next caller-driven attempt).
                if self.pendingState != nil {
                    self.pushPendingState()
                }
            }
        }
    }
}
