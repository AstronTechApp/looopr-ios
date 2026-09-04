import CoreLocation

struct WrongWayDetectorDebugSnapshot: Equatable {
    var status: String = "idle"
    var reason: String = "not started"
    var windowMeters: Double = 0
    var windowLimitMeters: Double = 0
    var wrongWayMeters: Double = 0
    var triggerMeters: Double = 0
    var wrongWaySeconds: Double = 0
    var minDurationSeconds: Double = 0
    var divergenceDegrees: Double?
    var expectedBearing: Double?
    var travelBearing: Double?
    var reverseStartAlignmentDegrees: Double?
}

/// Detects when a user is walking in the opposite direction to the intended
/// route. Fully decoupled from off-route / rerouting logic.
///
/// Flow:
///   1. GPS warmup guard -- ignore the first few seconds (once per session).
///   2. Accumulate `wrongWayDistance` when the user's travel bearing diverges
///      from the expected route bearing. The travel bearing is measured from
///      a fix at least `bearingBaselineMeters` back (not the previous fix),
///      and only fixes where the user is actually moving count — GPS drift
///      while standing still produces random bearings and must not trigger.
///   3. Once `wrongWayDistance` reaches the configured trigger distance AND
///      the divergence has persisted for `minDurationSeconds`, fire
///      `onWrongWayDetected`.
///   4. If the user self-corrects before the trigger distance,
///      reset `wrongWayDistance`.
///   5. After `maxFlips` confirmed flips, detection stops for the session.
///   6. While a prompt is on screen (`awaitingUserResponse`), no duplicate
///      prompts fire.
///   7. Detection only runs inside the configured start-of-walk distance
///      window; this avoids mid-walk route reversals for now.
final class WrongWayDetector {

    // MARK: - Configuration

    private let warmupSeconds: TimeInterval
    private let detectionWindowMeters: Double
    private let divergenceThresholdDegrees: Double
    private let wrongWayTriggerMeters: Double
    private let minDurationSeconds: TimeInterval
    private let minSpeed: Double
    private let bearingBaselineMeters: Double
    private let maxFlips: Int

    // MARK: - State

    /// Number of confirmed route flips this session.
    private(set) var flipCount: Int = 0

    /// `true` while the wrong-way modal is visible, preventing duplicate prompts.
    private(set) var awaitingUserResponse: Bool = false

    /// Whether wrong-way detection is still active this session.
    var isActive: Bool {
        flipCount < maxFlips && !awaitingUserResponse
    }

    private(set) var debugSnapshot = WrongWayDetectorDebugSnapshot()

    private var walkStartTime: Date?
    private var previousLocation: CLLocation?
    private var wrongWayDistance: CLLocationDistance = 0
    /// Timestamp of the first fix in the current run of diverging travel.
    private var wrongWayStartedAt: Date?
    /// Recent moving fixes, oldest first, used to measure travel bearing
    /// over `bearingBaselineMeters` rather than fix-to-fix.
    private var trail: [CLLocation] = []
    private let trailMaxAge: TimeInterval = 90

    /// Total distance considered by this detector since the walk started.
    /// This is not reset when the user dismisses the prompt, so it enforces
    /// "beginning of route only" across repeated warnings.
    private var cumulativeDistanceSinceSessionStart: CLLocationDistance = 0

    // MARK: - Callbacks

    var onWrongWayDetected: (() -> Void)?

    // MARK: - Init

    init(configuration: AppConfiguration = .current) {
        self.warmupSeconds = configuration.navigation.wrongWayWarmupSeconds
        self.detectionWindowMeters = configuration.navigation.wrongWayDetectionWindowMeters
        self.divergenceThresholdDegrees = configuration.navigation.wrongWayDivergenceDegrees
        self.wrongWayTriggerMeters = configuration.navigation.wrongWayTriggerMeters
        self.minDurationSeconds = configuration.navigation.wrongWayMinDurationSeconds
        self.minSpeed = configuration.navigation.wrongWayMinSpeedMetersPerSecond
        self.bearingBaselineMeters = configuration.navigation.wrongWayBearingBaselineMeters
        self.maxFlips = configuration.navigation.wrongWayMaxFlips
    }

    init(navigation: AppConfiguration.Navigation) {
        self.warmupSeconds = navigation.wrongWayWarmupSeconds
        self.detectionWindowMeters = navigation.wrongWayDetectionWindowMeters
        self.divergenceThresholdDegrees = navigation.wrongWayDivergenceDegrees
        self.wrongWayTriggerMeters = navigation.wrongWayTriggerMeters
        self.minDurationSeconds = navigation.wrongWayMinDurationSeconds
        self.minSpeed = navigation.wrongWayMinSpeedMetersPerSecond
        self.bearingBaselineMeters = navigation.wrongWayBearingBaselineMeters
        self.maxFlips = navigation.wrongWayMaxFlips
    }

    // MARK: - Session lifecycle

    func startSession() {
        walkStartTime = Date()
        previousLocation = nil
        cumulativeDistanceSinceSessionStart = 0
        clearWrongWayRun()
        trail = []
        flipCount = 0
        awaitingUserResponse = false
        updateDebug(status: "idle", reason: "session started")
    }

    /// Called when the user confirms "Yes, flip route".
    func recordFlip() {
        flipCount += 1
        clearWrongWayRun()
        awaitingUserResponse = false
        updateDebug(status: "flipped", reason: "user confirmed")
        // previousLocation is kept so the next check has a reference point.
    }

    /// Called when the user dismisses the prompt and keeps the original route.
    func recordDismissal() {
        clearWrongWayRun()
        awaitingUserResponse = false
        updateDebug(status: "dismissed", reason: "user kept original")
        // flipCount is NOT incremented -- dismissed prompts don't count.
    }

    /// Called when the user confirms a flip but the route could not be
    /// recomputed. This should not consume the one-flip session allowance,
    /// and it should let the beginning-of-walk prompt recover on the next
    /// clear wrong-way movement.
    func recordFailedFlip() {
        clearWrongWayRun()
        awaitingUserResponse = false
        previousLocation = nil
        trail = []
        cumulativeDistanceSinceSessionStart = 0
        updateDebug(status: "retry", reason: "flip failed; detector reset")
    }

    /// Clears the accumulated wrong-way distance without changing flip count
    /// or the awaiting-response flag. Called when the user goes off-route so
    /// that distance accumulated *while off-route* (where the next-waypoint
    /// bearing is meaningless) doesn't carry over into a later wrong-way
    /// trigger once they're back on the polyline.
    func resetAccumulator() {
        clearWrongWayRun()
        previousLocation = nil
        trail = []
        updateDebug(status: "reset", reason: "off-route/reroute reset")
    }

    private func clearWrongWayRun() {
        wrongWayDistance = 0
        wrongWayStartedAt = nil
    }

    func recordSkipped(reason: String) {
        updateDebug(status: "skipped", reason: reason)
    }

    // MARK: - Core detection

    /// Called on every CLLocationManager update during a walk.
    /// `nextWaypoint` is the next waypoint the user should be walking toward.
    func check(userLocation: CLLocation, nextWaypoint: CLLocationCoordinate2D) {
        let expectedBearing = userLocation.coordinate.bearing(to: nextWaypoint)
        check(userLocation: userLocation, expectedBearing: expectedBearing)
    }

    /// Called on every CLLocationManager update during a walk.
    /// `expectedBearing` is the route's intended bearing at the user's
    /// current progress point.
    func check(
        userLocation: CLLocation,
        expectedBearing: CLLocationDirection,
        intendedStartBearing: CLLocationDirection? = nil,
        reverseStartBearing: CLLocationDirection? = nil
    ) {
        // Session limit reached or modal already on screen
        guard flipCount < maxFlips else {
            updateDebug(status: "inactive", reason: "flip limit reached")
            return
        }
        guard !awaitingUserResponse else {
            updateDebug(status: "awaiting", reason: "prompt visible")
            return
        }

        // GPS warmup guard (once per session, not reset on flip)
        guard let startTime = walkStartTime else {
            updateDebug(status: "idle", reason: "session not started")
            return
        }
        let elapsed = Date().timeIntervalSince(startTime)
        guard elapsed >= warmupSeconds else {
            updateDebug(status: "warming", reason: "\(Int(ceil(warmupSeconds - elapsed)))s left")
            return
        }

        // Need a previous location to compute travel bearing
        guard let previous = previousLocation else {
            previousLocation = userLocation
            updateDebug(status: "priming", reason: "first good GPS fix")
            return
        }

        let delta = userLocation.distance(from: previous)

        // Ignore tiny movements (noise)
        guard delta > 2 else {
            updateDebug(status: "waiting", reason: "movement too small")
            return
        }

        // Ignore large GPS jumps; they should not count as intentional walking.
        guard delta < 75 else {
            previousLocation = userLocation
            clearWrongWayRun()
            trail = []
            updateDebug(status: "gps jump", reason: "\(Int(delta))m jump ignored")
            return
        }

        defer { previousLocation = userLocation }

        // Standing still? GPS drift while stationary yields random bearings,
        // so such fixes neither count towards nor clear a wrong-way run.
        let dt = userLocation.timestamp.timeIntervalSince(previous.timestamp)
        let speed = userLocation.speed >= 0 ? userLocation.speed : delta / max(dt, 0.1)
        guard speed >= minSpeed else {
            updateDebug(status: "stationary", reason: String(format: "%.1f m/s", speed))
            return
        }

        cumulativeDistanceSinceSessionStart += delta
        guard cumulativeDistanceSinceSessionStart <= detectionWindowMeters else {
            clearWrongWayRun()
            updateDebug(status: "expired", reason: "start window passed")
            return
        }

        // Measure travel bearing over a baseline of at least
        // `bearingBaselineMeters` so per-fix jitter can't swing it around.
        trail.removeAll { userLocation.timestamp.timeIntervalSince($0.timestamp) > trailMaxAge }
        trail.append(previous)
        guard let anchor = trail.last(where: {
            $0.distance(from: userLocation) >= bearingBaselineMeters
        }) else {
            updateDebug(status: "baseline", reason: "building \(Int(bearingBaselineMeters))m baseline")
            return
        }
        let travelBearing = anchor.coordinate.bearing(to: userLocation.coordinate)
        let divergence = Self.angularDivergence(travelBearing, expectedBearing)
        let reverseStartAlignment = reverseStartBearing.map {
            Self.angularDivergence(travelBearing, $0)
        }
        let startDivergence = intendedStartBearing.map {
            Self.angularDivergence(travelBearing, $0)
        }

        let matchesReverseStart = startDivergence.map { $0 > divergenceThresholdDegrees } == true
            && reverseStartAlignment.map { $0 <= 60 } == true

        if divergence > divergenceThresholdDegrees || matchesReverseStart {
            wrongWayDistance += delta
            let startedAt = wrongWayStartedAt ?? previous.timestamp
            wrongWayStartedAt = startedAt
            let wrongWaySeconds = userLocation.timestamp.timeIntervalSince(startedAt)
            if wrongWayDistance >= wrongWayTriggerMeters, wrongWaySeconds >= minDurationSeconds {
                awaitingUserResponse = true
                updateDebug(
                    status: "triggered",
                    reason: matchesReverseStart ? "reverse start" : "bearing divergence",
                    divergenceDegrees: divergence,
                    expectedBearing: expectedBearing,
                    travelBearing: travelBearing,
                    reverseStartAlignmentDegrees: reverseStartAlignment
                )
                onWrongWayDetected?()
            } else {
                updateDebug(
                    status: "accumulating",
                    reason: matchesReverseStart ? "reverse start" : "bearing divergence",
                    divergenceDegrees: divergence,
                    expectedBearing: expectedBearing,
                    travelBearing: travelBearing,
                    reverseStartAlignmentDegrees: reverseStartAlignment
                )
            }
        } else {
            // User self-corrected
            clearWrongWayRun()
            updateDebug(
                status: "aligned",
                reason: "travel matches route",
                divergenceDegrees: divergence,
                expectedBearing: expectedBearing,
                travelBearing: travelBearing,
                reverseStartAlignmentDegrees: reverseStartAlignment
            )
        }
    }

    // MARK: - Helpers

    /// Absolute shortest angular difference between two bearings (0-180 deg).
    static func angularDivergence(_ a: Double, _ b: Double) -> Double {
        var diff = abs(a - b)
        if diff > 180 { diff = 360 - diff }
        return diff
    }

    private func updateDebug(
        status: String,
        reason: String,
        divergenceDegrees: Double? = nil,
        expectedBearing: Double? = nil,
        travelBearing: Double? = nil,
        reverseStartAlignmentDegrees: Double? = nil
    ) {
        debugSnapshot = WrongWayDetectorDebugSnapshot(
            status: status,
            reason: reason,
            windowMeters: cumulativeDistanceSinceSessionStart,
            windowLimitMeters: detectionWindowMeters,
            wrongWayMeters: wrongWayDistance,
            triggerMeters: wrongWayTriggerMeters,
            wrongWaySeconds: wrongWayStartedAt.map { max(0, Date().timeIntervalSince($0)) } ?? 0,
            minDurationSeconds: minDurationSeconds,
            divergenceDegrees: divergenceDegrees,
            expectedBearing: expectedBearing,
            travelBearing: travelBearing,
            reverseStartAlignmentDegrees: reverseStartAlignmentDegrees
        )
    }
}
