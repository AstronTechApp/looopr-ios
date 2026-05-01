import ActivityKit
import CoreLocation
import Combine
import UIKit

// MARK: - Supporting types

struct ApproachingPOIInfo: Equatable {
    let poi: POI
    let distanceMeters: Double

    var estimatedMinutes: Int { max(1, Int(ceil(distanceMeters / 80.0))) }
}

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

@MainActor @Observable
final class WalkNavigationViewModel {
    let route: Route
    private(set) var steps: [NavigationStep] = []
    private(set) var currentStepIndex: Int = 0
    private(set) var currentInstruction: String = "Preparing navigation..."
    private(set) var nextInstruction: String?
    private(set) var distanceToNextStep: Double = 0
    private(set) var userLocation: CLLocationCoordinate2D?
    private(set) var heading: CLLocationDirection = 0
    private(set) var currentAccuracy: Double = 0
    private(set) var distanceWalked: Double = 0
    private(set) var elapsedSeconds: TimeInterval = 0
    private(set) var isLoading = true
    private(set) var error: NavigationError?
    private(set) var isFinished = false
    /// Which way the user is walking through `activePolyline`.
    private(set) var walkDirection: WalkDirection = .forward
    private(set) var activePolyline: [CLLocationCoordinate2D] = []
    private(set) var stepCount: Int = 0
    private(set) var routeArrows: [RouteArrow] = []
    private(set) var showWrongWayPrompt = false
    private(set) var isFlippingRoute = false
    private(set) var routeFlipPhase: RouteFlipPhase = .idle
    private(set) var routeToastMessage: String = L10n.WalkNavigation.routeUpdated
    private(set) var routeToastStyle: RouteToastStyle = .success
    /// Distance remaining along the *active* polyline from the user's current
    /// position to the end of the route. Adapts to reroutes — if the user
    /// skips a leg and the polyline shrinks, this shrinks too. Used as the
    /// source of truth for the "X km remaining" label and progress bar.
    private(set) var remainingMeters: Double = 0
    /// Compass bearing (0 = N, 90 = E …) of the route's direction of travel
    /// at the user's current position, going forward along the polyline.
    /// Computed via monotonic progress (see `lastClosestPolylineIndex`) so
    /// loop routes — where the start and end coordinates are the same point
    /// — don't accidentally point in the *returning* direction at the start.
    private(set) var currentRouteBearing: Double = 0
    private var activePolylineCumulativeDistances: [Double] = []
    private var stepRouteDistancesFromStart: [Double?] = []
    /// User's current best-known position along `activePolyline`, expressed
    /// as a vertex index. Advances monotonically (with a small back-buffer
    /// for GPS noise) so that on loop routes we don't jump from the start
    /// of the loop to the end just because they share a coordinate.
    private var lastClosestPolylineIndex: Int = 0 {
        didSet { debugLastClosestPolylineIndex = lastClosestPolylineIndex }
    }
    private(set) var isRerouting = false
    private(set) var showRouteUpdatedToast = false

    // Food check-in state
    private(set) var nearbyFoodSpot: POI?
    private(set) var showFoodCheckIn = false
    private var foodCheckInCooldownIds: Set<UUID> = []

    // Contextual nav overlays
    private(set) var approachingPOI: ApproachingPOIInfo?
    private(set) var currentStreetName: String = ""

    var session: WalkSession

    var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(currentStepIndex) / Double(steps.count)
    }

    /// Coordinate of the step the user is currently navigating toward, in
    /// the active walk direction.
    var currentStepCoordinate: CLLocationCoordinate2D? {
        activeStep(at: 0)?.coordinate
    }

    var remainingSteps: Int {
        max(0, steps.count - currentStepIndex)
    }

    /// Returns the step at `offset` ahead of the user in the active walk
    /// direction, or `nil` if that offset falls outside the array.
    ///
    /// - In `.forward`, this is `steps[currentStepIndex + offset]`.
    /// - In `.reverse`, the steps array is read end-to-start, so this is
    ///   `steps[steps.count - 1 - currentStepIndex - offset]`.
    ///
    /// `currentStepIndex` always counts up from 0 regardless of direction —
    /// it represents *how many steps the user has completed in the active
    /// direction*. This helper translates that into the actual array index.
    private func activeStepArrayIndex(at offset: Int) -> Int? {
        guard !steps.isEmpty else { return nil }
        let idx: Int
        switch walkDirection {
        case .forward:
            idx = currentStepIndex + offset
        case .reverse:
            idx = steps.count - 1 - currentStepIndex - offset
        }
        guard idx >= 0, idx < steps.count else { return nil }
        return idx
    }

    private func activeStep(at offset: Int) -> NavigationStep? {
        guard let idx = activeStepArrayIndex(at: offset) else { return nil }
        return steps[idx]
    }

    // Dependencies
    private let locationService: LocationProviding
    private let directionsService: NavigationDirecting
    private let pedometerService: PedometerProviding
    private let stepTracker: StepTracker
    private let wrongWayDetector: WrongWayDetector
    private let config: AppConfiguration
    private let logger = AppLogger(category: "WalkNav")
    private let liveActivityManager = LiveActivityManager.shared

    private var locationCancellable: AnyCancellable?
    private var elapsedTimer: Timer?
    private var liveActivityTimer: Timer?
    private let startTime = Date()

    // Reroute cooldown
    private var lastRerouteTime: Date?

    // Reverse geocoding
    private let geocoder = CLGeocoder()
    private var lastGeocodingLocation: CLLocation?
    private var lastGeocodingDate: Date = .distantPast

    // Navigation diagnostics kept available for logs/tests without showing an in-app overlay.
    var debugDeviationMeters: Double = 0
    var debugReentryCoordinate: CLLocationCoordinate2D?
    var debugLastRerouteDate: Date?
    private(set) var debugRouteFlipMessage: String = "idle"
    private(set) var debugRouteFlipPathPointCount: Int = 0
    private(set) var debugRouteFlipStepCount: Int = 0
    private(set) var debugRouteFlipFirstInstruction: String = ""
    private(set) var debugRouteFlipLastAttemptDate: Date?
    private(set) var debugWrongWaySnapshot = WrongWayDetectorDebugSnapshot()
    /// Mirrors `lastClosestPolylineIndex` for diagnostics. Updated
    /// automatically via `didSet`.
    private(set) var debugLastClosestPolylineIndex: Int = 0

    init(
        route: Route,
        locationService: LocationProviding = ServiceContainer.shared.resolve(LocationProviding.self),
        directionsService: NavigationDirecting = ServiceContainer.shared.resolve(NavigationDirecting.self),
        pedometerService: PedometerProviding = ServiceContainer.shared.resolve(PedometerProviding.self),
        configuration: AppConfiguration = .current
    ) {
        self.route = route
        self.locationService = locationService
        self.directionsService = directionsService
        self.pedometerService = pedometerService
        self.config = configuration
        self.stepTracker = StepTracker(configuration: configuration)
        self.wrongWayDetector = WrongWayDetector(configuration: configuration)
        self.session = WalkSession(routeId: route.id)
        self.activePolyline = route.pathCoordinates
        self.activePolylineCumulativeDistances = Self.cumulativeDistances(for: route.pathCoordinates)
        self.routeArrows = RouteArrowHelper.arrows(along: route.pathCoordinates)
        // Seed remaining distance with the full polyline length so the
        // progress bar shows a sensible "0 / total" before the first GPS
        // fix arrives.
        self.remainingMeters = WalkNavigationViewModel.polylineLength(route.pathCoordinates)
        // Seed initial route bearing from the first polyline segment so the
        // user-location arrow points the right way at t=0, even before any
        // GPS update has triggered the monotonic progress search.
        self.currentRouteBearing = route.pathCoordinates.count >= 2
            ? route.pathCoordinates[0].bearing(to: route.pathCoordinates[1])
            : 0

        self.wrongWayDetector.onWrongWayDetected = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.routeFlipPhase = .awaitingConfirmation
                self.debugRouteFlipMessage = "Prompt shown"
                self.syncWrongWayDebug()
                self.showWrongWayPrompt = true
                self.triggerHaptic()
            }
        }
    }

    func start() async {
        wrongWayDetector.startSession()
        syncWrongWayDebug()
        locationService.startUpdating()
        pedometerService.startCounting()

        // Seed blue dot from an existing GPS fix immediately
        if let existing = locationService.currentCoordinate {
            userLocation = existing
        }

        subscribeToLocation()
        startElapsedTimer()

        do {
            steps = try await directionsService.computeSteps(for: route)
            refreshStepRouteDistances()
            refreshCurrentStepPresentation(currentLocation: userLocation)
            isLoading = false
            logger.info("Navigation started with \(steps.count) steps")

            // Start Live Activity and its dedicated update timer
            liveActivityManager.startActivity(
                routeName: route.baseName,
                totalDistanceMeters: route.distanceKilometers * 1000,
                totalPOIs: route.pois.count,
                startDate: startTime
            )
            startLiveActivityTimer()
        } catch {
            self.error = .stepsUnavailable
            isLoading = false
            logger.error("Failed to compute steps: \(error)")
        }
    }

    func stop() {
        locationService.stopUpdating()
        locationCancellable?.cancel()
        elapsedTimer?.invalidate()
        pedometerService.stopCounting()
        session.finishedAt = Date()
        session.durationSeconds = Date().timeIntervalSince(startTime)
        session.stepCount = stepCount

        // End Live Activity and its dedicated timer
        liveActivityTimer?.invalidate()
        liveActivityTimer = nil
        liveActivityManager.endActivity()
    }

    func finish() {
        stop()
        isFinished = true
    }

    // MARK: - Food Check-in

    func checkInFoodSpot() {
        guard let spot = nearbyFoodSpot else { return }
        session.visitedFoodStops.append(FoodStopVisit(poiId: spot.id, name: spot.name))
        foodCheckInCooldownIds.insert(spot.id)
        showFoodCheckIn = false
        nearbyFoodSpot = nil
        triggerHaptic()
        logger.info("Checked in at \(spot.name)")
    }

    func dismissFoodCheckIn() {
        guard let spot = nearbyFoodSpot else { return }
        foodCheckInCooldownIds.insert(spot.id)
        showFoodCheckIn = false
        nearbyFoodSpot = nil
    }

    // MARK: - Re-routing

    /// Trigger a reroute from the user's current position.
    /// bypassCooldown=true is used for explicit "Recalculate" taps.
    func rerouteFromCurrentPosition(bypassCooldown: Bool = false) {
        guard let location = userLocation,
              !isRerouting,
              !isFlippingRoute,
              !showWrongWayPrompt
        else { return }
        if !bypassCooldown, let last = lastRerouteTime,
           Date().timeIntervalSince(last) < config.navigation.rerouteCooldownSeconds {
            logger.info("Reroute skipped — cooldown active")
            return
        }
        wrongWayDetector.resetAccumulator()
        syncWrongWayDebug()
        isRerouting = true
        Task {
            await performReroute(from: location)
            isRerouting = false
        }
    }

    func confirmWrongWayFlip() {
        showWrongWayPrompt = false

        guard let location = userLocation, !isRerouting, !isFlippingRoute else {
            logger.warning("Route flip skipped — location unavailable or reroute already active")
            recordRouteFlipFailure("Missing location or already busy")
            wrongWayDetector.recordFailedFlip()
            syncWrongWayDebug()
            showRouteFlipFailedToast()
            return
        }

        isFlippingRoute = true
        isRerouting = true
        routeFlipPhase = .preparing
        debugRouteFlipLastAttemptDate = Date()
        debugRouteFlipMessage = "Accepted prompt"
        debugRouteFlipPathPointCount = 0
        debugRouteFlipStepCount = 0
        debugRouteFlipFirstInstruction = ""
        routeToastMessage = L10n.WalkNavigation.routeFlipping
        routeToastStyle = .status
        showRouteUpdatedToast = true
        Task {
            await performConfirmedRouteFlip(from: location)
            isFlippingRoute = false
            isRerouting = false
        }
    }

    func keepOriginalRouteAfterWrongWayPrompt() {
        showWrongWayPrompt = false
        routeFlipPhase = .idle
        debugRouteFlipMessage = "User kept original"
        wrongWayDetector.recordDismissal()
        syncWrongWayDebug()
    }

    // MARK: - Private

    private func subscribeToLocation() {
        locationCancellable = locationService.locationPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] clLocation in
                self?.handleLocationUpdate(clLocation)
            }
    }

    private func handleLocationUpdate(_ clLocation: CLLocation) {
        let coordinate = clLocation.coordinate
        let accuracy = clLocation.horizontalAccuracy
        let previous = userLocation

        userLocation = coordinate
        currentAccuracy = accuracy
        heading = locationService.currentHeading ?? 0

        // Track distance walked
        if let prev = previous {
            let delta = prev.distance(to: coordinate)
            if delta > 2 && delta < 100 {
                distanceWalked += delta
                session.distanceWalkedMeters = distanceWalked
            }
        }

        // Refresh progress index, remaining distance, and route bearing now
        // that the user has moved.
        updateRouteProgress()
        checkWrongWayIfNeeded(clLocation)

        // Food spot proximity
        checkFoodSpotProximity(coordinate)

        // Attraction proximity banner + street name
        checkApproachingPOI(coordinate)
        updateStreetNameIfNeeded(clLocation)

        updateStepInstructionProgress(from: coordinate)
    }

    private func checkWrongWayIfNeeded(_ clLocation: CLLocation) {
        guard !isLoading else {
            markWrongWaySkipped("loading")
            return
        }
        guard error == nil else {
            markWrongWaySkipped("navigation error")
            return
        }
        guard !isRerouting else {
            markWrongWaySkipped("rerouting")
            return
        }
        guard !isFlippingRoute else {
            markWrongWaySkipped("flipping")
            return
        }
        guard activePolyline.count >= 2 else {
            markWrongWaySkipped("no route")
            return
        }
        guard clLocation.horizontalAccuracy > 0 else {
            markWrongWaySkipped("gps unavailable")
            return
        }
        guard clLocation.horizontalAccuracy <= config.navigation.gpsAccuracyThresholdMeters else {
            markWrongWaySkipped("gps \(Int(clLocation.horizontalAccuracy))m")
            return
        }

        let startBearings = wrongWayLoopStartBearings()
        wrongWayDetector.check(
            userLocation: clLocation,
            expectedBearing: currentRouteBearing,
            intendedStartBearing: startBearings?.forward,
            reverseStartBearing: startBearings?.reverse
        )
        syncWrongWayDebug()
    }

    private func markWrongWaySkipped(_ reason: String) {
        wrongWayDetector.recordSkipped(reason: reason)
        syncWrongWayDebug()
    }

    private func syncWrongWayDebug() {
        debugWrongWaySnapshot = wrongWayDetector.debugSnapshot
    }

    private func updateStepInstructionProgress(from coordinate: CLLocationCoordinate2D) {
        guard !steps.isEmpty else { return }

        var didAdvance = false
        while shouldAdvanceActiveStep(from: coordinate) {
            stepTracker.advance()
            currentStepIndex = stepTracker.currentStepIndex
            didAdvance = true

            // Auto-skip stray arrival instructions at non-final steps.
            while let stepNow = activeStep(at: 0),
                  currentStepIndex < steps.count - 1,
                  isArrivalInstruction(stepNow.instruction) {
                stepTracker.advance()
                currentStepIndex = stepTracker.currentStepIndex
                didAdvance = true
            }
        }

        refreshCurrentStepPresentation(currentLocation: coordinate)
        if didAdvance {
            triggerHaptic()
        }
    }

    private func shouldAdvanceActiveStep(from coordinate: CLLocationCoordinate2D) -> Bool {
        guard let target = activeStep(at: 0),
              currentStepIndex < steps.count - 1
        else {
            return false
        }

        if stepTracker.shouldAdvance(
            userLocation: coordinate,
            targetCoordinate: target.coordinate,
            totalSteps: steps.count
        ) {
            return true
        }

        return hasPassedActiveStepByRouteProgress(from: coordinate)
    }

    private func hasPassedActiveStepByRouteProgress(from coordinate: CLLocationCoordinate2D) -> Bool {
        guard activePolyline.count >= 2,
              let stepDistanceFromStart = activeStepRouteDistanceFromStart(at: 0),
              let totalDistance = activePolylineCumulativeDistances.last
        else {
            return false
        }

        let progressDistanceFromStart = routeDistanceFromStart(atVertexIndex: lastClosestPolylineIndex)
        let minSearchDistance = max(0, progressDistanceFromStart - 80)
        if let match = Self.nearestRouteProgress(
            to: coordinate,
            in: activePolyline,
            cumulativeDistances: activePolylineCumulativeDistances,
            minimumDistanceFromStart: minSearchDistance
        ) {
            let routeSnapThreshold = max(
                config.navigation.offRouteThresholdMeters,
                config.navigation.gpsAccuracyThresholdMeters * 2
            )
            guard match.distanceToRouteMeters <= routeSnapThreshold else {
                return false
            }
        }

        return Self.hasPassedStepByRouteProgress(
            progressDistanceFromStart: progressDistanceFromStart,
            stepDistanceFromStart: stepDistanceFromStart,
            totalDistance: totalDistance,
            walkDirection: walkDirection,
            toleranceMeters: config.navigation.stepAdvanceThresholdMeters
        )
    }

    private func activeStepRouteDistanceFromStart(at offset: Int) -> Double? {
        guard let idx = activeStepArrayIndex(at: offset),
              idx >= 0,
              idx < stepRouteDistancesFromStart.count
        else {
            return nil
        }
        return stepRouteDistancesFromStart[idx]
    }

    private func routeDistanceFromStart(atVertexIndex index: Int) -> Double {
        guard !activePolylineCumulativeDistances.isEmpty else { return 0 }
        let clampedIndex = min(max(0, index), activePolylineCumulativeDistances.count - 1)
        return activePolylineCumulativeDistances[clampedIndex]
    }

    private func refreshStepRouteDistances() {
        activePolylineCumulativeDistances = Self.cumulativeDistances(for: activePolyline)
        stepRouteDistancesFromStart = Self.routeDistancesForSteps(steps, along: activePolyline)
    }

    private func refreshCurrentStepPresentation(currentLocation: CLLocationCoordinate2D?) {
        guard let stepNow = activeStep(at: 0) else {
            currentInstruction = "You've arrived!"
            nextInstruction = nil
            distanceToNextStep = 0
            return
        }

        currentInstruction = stepNow.instruction
        nextInstruction = activeStep(at: 1)?.instruction
        if let currentLocation {
            distanceToNextStep = currentLocation.distance(to: stepNow.coordinate)
        }
    }

    private func checkFoodSpotProximity(_ coordinate: CLLocationCoordinate2D) {
        guard !showFoodCheckIn else { return }
        let threshold = config.navigation.foodSpotProximityMeters
        for foodSpot in route.foodSpots {
            guard !foodCheckInCooldownIds.contains(foodSpot.id) else { continue }
            if coordinate.distance(to: foodSpot.location.clCoordinate) <= threshold {
                nearbyFoodSpot = foodSpot
                showFoodCheckIn = true
                return
            }
        }
    }

    private func performReroute(from location: CLLocationCoordinate2D) async {
        let closestIdx = closestPolylineIndex(to: location, in: activePolyline)

        // Don't reroute in the last 10% of the route
        let routeProgress = Double(closestIdx) / Double(max(1, activePolyline.count - 1))
        if routeProgress > (1.0 - config.navigation.suppressRerouteLastPercent) {
            logger.info("Last 10% — skipping reroute")
            return
        }

        guard closestIdx + 1 < activePolyline.count else { return }
        let remaining = Array(activePolyline[(closestIdx + 1)...])

        // Try smart re-entry: forward-facing intersection in heading corridor
        let candidate = ReentryPointFinder.findReentryPoint(
            userLocation: location,
            userHeading: heading,
            remainingPolyline: remaining,
            config: config.navigation
        )

        let pathAfterRejoin: [CLLocationCoordinate2D]

        if let candidate {
            // Use the candidate's polylineIndex offset from the remaining slice,
            // NOT a closest-point search on the full polyline. On loop routes the
            // full-polyline search can match a geographically-close vertex near
            // the *end* of the loop, skipping most of the walk.
            let reentryIdx = closestIdx + 1 + candidate.polylineIndex
            pathAfterRejoin = Array(activePolyline[reentryIdx...])
            debugReentryCoordinate = candidate.coordinate
            logger.info("Smart re-entry \(Int(candidate.distanceFromUser))m ahead")
        } else {
            // Fallback: skip 80m ahead on polyline
            var skipIdx = closestIdx + 1
            var skipDist: Double = 0
            while skipIdx < activePolyline.count - 1 && skipDist < 80 {
                skipDist += activePolyline[skipIdx - 1].distance(to: activePolyline[skipIdx])
                skipIdx += 1
            }
            guard skipIdx < activePolyline.count else { return }
            pathAfterRejoin = Array(activePolyline[skipIdx...])
            debugReentryCoordinate = nil
            logger.info("Fallback: skip-80m reroute")
        }

        do {
            let result = try await directionsService.computeStepsAlongPath([location] + pathAfterRejoin)
            applyRecomputedNavigation(result)
            lastRerouteTime = Date()
            debugLastRerouteDate = lastRerouteTime
            triggerHaptic()
            logger.info("Rerouted: \(steps.count) steps")

            // Show green "Route updated" toast
            routeToastMessage = L10n.WalkNavigation.routeUpdated
            routeToastStyle = .success
            showRouteUpdatedToast = true
            try? await Task.sleep(for: .seconds(config.navigation.rerouteToastDismissSeconds))
            showRouteUpdatedToast = false
        } catch {
            logger.error("Reroute failed: \(error)")
        }
    }

    private func performConfirmedRouteFlip(from location: CLLocationCoordinate2D) async {
        let sourcePolyline = route.pathCoordinates.count >= 2 ? route.pathCoordinates : activePolyline
        routeFlipPhase = .preparing
        debugRouteFlipMessage = "Building reversed path"

        let path = Self.makeRouteFlipPath(from: location, sourcePolyline: sourcePolyline)
        debugRouteFlipPathPointCount = path.count

        guard path.count >= 2 else {
            logger.warning("Route flip skipped — no reversed path remains")
            recordRouteFlipFailure("No reversed path remains")
            wrongWayDetector.recordFailedFlip()
            syncWrongWayDebug()
            showRouteFlipFailedToast()
            return
        }

        routeFlipPhase = .recomputing(pathPoints: path.count)
        debugRouteFlipMessage = "Requesting walking directions"

        do {
            let result = try await directionsService.computeStepsAlongPath(path)
            debugRouteFlipStepCount = result.steps.count
            debugRouteFlipFirstInstruction = result.steps.first?.instruction ?? ""
            routeFlipPhase = .applying(steps: result.steps.count)
            debugRouteFlipMessage = "Applying recomputed route"

            applyRecomputedNavigation(result)
            routeToastMessage = L10n.WalkNavigation.routeFlipped
            routeToastStyle = .success
            showRouteUpdatedToast = true
            routeFlipPhase = .succeeded(steps: result.steps.count)
            debugRouteFlipMessage = "Applied: \(result.steps.count) steps"
            wrongWayDetector.recordFlip()
            syncWrongWayDebug()
            triggerHaptic()
            logger.info("Route flipped with \(steps.count) recomputed steps from \(path.count) reversed path points")

            try? await Task.sleep(for: .seconds(config.navigation.rerouteToastDismissSeconds))
            showRouteUpdatedToast = false
        } catch {
            let message = "Directions failed: \(String(describing: error))"
            logger.error("Route flip failed: \(error)")
            recordRouteFlipFailure(message)
            wrongWayDetector.recordFailedFlip()
            syncWrongWayDebug()
            showRouteFlipFailedToast()
        }
    }

    private func applyRecomputedNavigation(_ result: RerouteResult) {
        steps = result.steps
        activePolyline = result.polyline
        // Recomputed routes are generated from the user's current location
        // toward the desired remaining path, so they are always read forward.
        walkDirection = .forward
        routeArrows = RouteArrowHelper.arrows(along: activePolyline, direction: walkDirection)
        lastClosestPolylineIndex = 0
        refreshStepRouteDistances()
        updateRouteProgress()
        stepTracker.reset()
        currentStepIndex = 0
        refreshCurrentStepPresentation(currentLocation: userLocation)
    }

    private func recordRouteFlipFailure(_ message: String) {
        routeFlipPhase = .failed(message)
        debugRouteFlipMessage = message
    }

    private func wrongWayLoopStartBearings() -> (forward: CLLocationDirection, reverse: CLLocationDirection)? {
        let polyline = route.pathCoordinates
        guard polyline.count >= 3,
              let start = polyline.first,
              let end = polyline.last
        else {
            return nil
        }

        let overlapThreshold = max(40, config.navigation.gpsAccuracyThresholdMeters * 3)
        guard start.distance(to: end) <= overlapThreshold,
              let forward = Self.firstDistinctBearing(from: start, candidates: Array(polyline.dropFirst())),
              let reverse = Self.firstDistinctBearing(from: start, candidates: Array(polyline.dropLast().reversed()))
        else {
            return nil
        }

        return (forward, reverse)
    }

    static func makeRouteFlipPath(
        from location: CLLocationCoordinate2D,
        sourcePolyline: [CLLocationCoordinate2D]
    ) -> [CLLocationCoordinate2D] {
        let reversedPath = Array(sourcePolyline.reversed())
        guard reversedPath.count >= 2 else { return [] }

        let nextIdx = nextPolylineVertexIndex(after: location, in: reversedPath)
        var path = [location]
        path.append(contentsOf: reversedPath[nextIdx...])

        var deduped = removingConsecutiveNearDuplicates(path)
        if deduped.count < 2,
           let fallback = reversedPath.first(where: { location.distance(to: $0) >= 5 }) {
            deduped.append(fallback)
        }
        return deduped
    }

    private static func firstDistinctBearing(
        from start: CLLocationCoordinate2D,
        candidates: [CLLocationCoordinate2D]
    ) -> CLLocationDirection? {
        for coordinate in candidates where start.distance(to: coordinate) >= 8 {
            return start.bearing(to: coordinate)
        }
        return nil
    }

    private func showRouteFlipFailedToast() {
        routeToastMessage = L10n.WalkNavigation.routeFlipFailed
        routeToastStyle = .error
        showRouteUpdatedToast = true

        let dismissDelay = config.navigation.rerouteToastDismissSeconds
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(dismissDelay))
            if self?.routeToastStyle == .error {
                self?.showRouteUpdatedToast = false
            }
        }
    }

    private static func nextPolylineVertexIndex(
        after point: CLLocationCoordinate2D,
        in polyline: [CLLocationCoordinate2D]
    ) -> Int {
        guard polyline.count >= 2 else { return 0 }

        var bestDistance = Double.infinity
        var bestNextIndex = 1

        for index in 0..<(polyline.count - 1) {
            let distance = distanceFrom(point, toSegmentStart: polyline[index], end: polyline[index + 1])
            if distance < bestDistance {
                bestDistance = distance
                bestNextIndex = index + 1
            }
        }

        return bestNextIndex
    }

    private static func removingConsecutiveNearDuplicates(
        _ coordinates: [CLLocationCoordinate2D],
        thresholdMeters: Double = 5
    ) -> [CLLocationCoordinate2D] {
        var result: [CLLocationCoordinate2D] = []
        for coordinate in coordinates {
            guard let last = result.last else {
                result.append(coordinate)
                continue
            }
            if last.distance(to: coordinate) >= thresholdMeters {
                result.append(coordinate)
            }
        }
        return result
    }

    private static func distanceFrom(
        _ point: CLLocationCoordinate2D,
        toSegmentStart start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D
    ) -> Double {
        let origin = start
        let metersPerDegreeLatitude = 111_320.0
        let metersPerDegreeLongitude = metersPerDegreeLatitude * cos(origin.latitude * .pi / 180)

        func xy(_ coordinate: CLLocationCoordinate2D) -> (x: Double, y: Double) {
            (
                x: (coordinate.longitude - origin.longitude) * metersPerDegreeLongitude,
                y: (coordinate.latitude - origin.latitude) * metersPerDegreeLatitude
            )
        }

        let p = xy(point)
        let a = xy(start)
        let b = xy(end)
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return hypot(p.x - a.x, p.y - a.y)
        }

        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        let projectedX = a.x + t * dx
        let projectedY = a.y + t * dy
        return hypot(p.x - projectedX, p.y - projectedY)
    }

    private func closestPolylineIndex(to point: CLLocationCoordinate2D, in polyline: [CLLocationCoordinate2D]) -> Int {
        var minDist = Double.infinity
        var minIdx = 0
        for (i, coord) in polyline.enumerated() {
            let dist = point.distance(to: coord)
            if dist < minDist { minDist = dist; minIdx = i }
        }
        return minIdx
    }

    /// Total length of an arbitrary polyline, in meters.
    /// Static so we can call it from `init` before `self` is fully formed.
    private static func polylineLength(_ polyline: [CLLocationCoordinate2D]) -> Double {
        guard polyline.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 1 ..< polyline.count {
            total += polyline[i - 1].distance(to: polyline[i])
        }
        return total
    }

    static func routeDistancesForSteps(
        _ steps: [NavigationStep],
        along polyline: [CLLocationCoordinate2D]
    ) -> [Double?] {
        guard polyline.count >= 2 else { return Array(repeating: nil, count: steps.count) }

        let cumulativeDistances = cumulativeDistances(for: polyline)
        var minimumDistanceFromStart: Double = 0
        let orderToleranceMeters: Double = 25

        return steps.map { step in
            let match = nearestRouteProgress(
                to: step.coordinate,
                in: polyline,
                cumulativeDistances: cumulativeDistances,
                minimumDistanceFromStart: max(0, minimumDistanceFromStart - orderToleranceMeters)
            )
            guard let distanceFromStart = match?.distanceFromStartMeters else { return nil }
            minimumDistanceFromStart = max(minimumDistanceFromStart, distanceFromStart)
            return distanceFromStart
        }
    }

    static func hasPassedStepByRouteProgress(
        progressDistanceFromStart: Double,
        stepDistanceFromStart: Double,
        totalDistance: Double,
        walkDirection: WalkDirection,
        toleranceMeters: Double
    ) -> Bool {
        guard totalDistance > 0 else { return false }

        let progressTravelDistance: Double
        let stepTravelDistance: Double
        switch walkDirection {
        case .forward:
            progressTravelDistance = progressDistanceFromStart
            stepTravelDistance = stepDistanceFromStart
        case .reverse:
            progressTravelDistance = totalDistance - progressDistanceFromStart
            stepTravelDistance = totalDistance - stepDistanceFromStart
        }

        return progressTravelDistance >= stepTravelDistance + toleranceMeters
    }

    private struct RouteProgressMatch {
        let distanceFromStartMeters: Double
        let distanceToRouteMeters: Double
    }

    private static func cumulativeDistances(for polyline: [CLLocationCoordinate2D]) -> [Double] {
        guard !polyline.isEmpty else { return [] }
        var distances = Array(repeating: 0.0, count: polyline.count)
        guard polyline.count >= 2 else { return distances }

        for index in 1..<polyline.count {
            distances[index] = distances[index - 1] + polyline[index - 1].distance(to: polyline[index])
        }
        return distances
    }

    private static func nearestRouteProgress(
        to point: CLLocationCoordinate2D,
        in polyline: [CLLocationCoordinate2D],
        cumulativeDistances: [Double],
        minimumDistanceFromStart: Double = 0
    ) -> RouteProgressMatch? {
        guard polyline.count >= 2,
              cumulativeDistances.count == polyline.count
        else {
            return nil
        }

        var bestAllowed: RouteProgressMatch?
        var bestAny: RouteProgressMatch?

        for index in 0..<(polyline.count - 1) {
            let projection = project(point, ontoSegmentStart: polyline[index], end: polyline[index + 1])
            let segmentLength = cumulativeDistances[index + 1] - cumulativeDistances[index]
            let distanceFromStart = cumulativeDistances[index] + projection.fraction * segmentLength
            let match = RouteProgressMatch(
                distanceFromStartMeters: distanceFromStart,
                distanceToRouteMeters: projection.distanceToSegmentMeters
            )

            if bestAny == nil || match.distanceToRouteMeters < bestAny!.distanceToRouteMeters {
                bestAny = match
            }
            if distanceFromStart >= minimumDistanceFromStart,
               bestAllowed == nil || match.distanceToRouteMeters < bestAllowed!.distanceToRouteMeters {
                bestAllowed = match
            }
        }

        return bestAllowed ?? bestAny
    }

    private struct SegmentProjection {
        let distanceToSegmentMeters: Double
        let fraction: Double
    }

    private static func project(
        _ point: CLLocationCoordinate2D,
        ontoSegmentStart start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D
    ) -> SegmentProjection {
        let origin = start
        let metersPerDegreeLatitude = 111_320.0
        let metersPerDegreeLongitude = metersPerDegreeLatitude * cos(origin.latitude * .pi / 180)

        func xy(_ coordinate: CLLocationCoordinate2D) -> (x: Double, y: Double) {
            (
                x: (coordinate.longitude - origin.longitude) * metersPerDegreeLongitude,
                y: (coordinate.latitude - origin.latitude) * metersPerDegreeLatitude
            )
        }

        let p = xy(point)
        let a = xy(start)
        let b = xy(end)
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return SegmentProjection(
                distanceToSegmentMeters: hypot(p.x - a.x, p.y - a.y),
                fraction: 0
            )
        }

        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        let projectedX = a.x + t * dx
        let projectedY = a.y + t * dy
        return SegmentProjection(
            distanceToSegmentMeters: hypot(p.x - projectedX, p.y - projectedY),
            fraction: t
        )
    }

    /// Updates `lastClosestPolylineIndex`, `remainingMeters`, and
    /// `currentRouteBearing` based on the user's current position. Call
    /// after every location update *and* after every polyline-changing event
    /// (reroute, reverse) so the progress bar, "X km remaining" label, and
    /// next-step direction arrow always reflect what's actually ahead.
    ///
    /// Uses a *windowed forward search* rather than a global nearest-point
    /// search so loop routes (where start and end coordinates coincide)
    /// don't accidentally jump from the start of the loop to the end.
    private func updateRouteProgress() {
        guard activePolyline.count >= 2 else {
            remainingMeters = 0
            currentRouteBearing = 0
            return
        }

        if let userCoord = userLocation {
            // Search a window around the previous index. Small back-buffer
            // tolerates GPS noise; generous look-ahead captures brisk
            // walking. The window flips orientation in `.reverse` so that
            // "ahead of the user" walks the polyline backward (N → 0).
            let backBuffer = 5
            let lookAhead = 100
            let lowerBound: Int
            let upperBound: Int
            switch walkDirection {
            case .forward:
                lowerBound = max(0, lastClosestPolylineIndex - backBuffer)
                upperBound = min(activePolyline.count - 1, lastClosestPolylineIndex + lookAhead)
            case .reverse:
                lowerBound = max(0, lastClosestPolylineIndex - lookAhead)
                upperBound = min(activePolyline.count - 1, lastClosestPolylineIndex + backBuffer)
            }

            var bestIdx = lastClosestPolylineIndex
            var bestDist = Double.infinity
            for i in lowerBound ... upperBound {
                let d = userCoord.distance(to: activePolyline[i])
                if d < bestDist {
                    bestDist = d
                    bestIdx = i
                }
            }
            lastClosestPolylineIndex = bestIdx
        }

        let progressIdx = lastClosestPolylineIndex

        // Remaining distance = sum of segment lengths from progress index
        // to whichever end of the polyline is "ahead" in the active
        // direction (end in forward, start in reverse).
        var total: Double = 0
        switch walkDirection {
        case .forward:
            var idx = progressIdx
            while idx + 1 < activePolyline.count {
                total += activePolyline[idx].distance(to: activePolyline[idx + 1])
                idx += 1
            }
        case .reverse:
            var idx = progressIdx
            while idx - 1 >= 0 {
                total += activePolyline[idx].distance(to: activePolyline[idx - 1])
                idx -= 1
            }
        }
        remainingMeters = total

        // Bearing = direction of the segment immediately ahead of the user
        // in the active direction.
        switch walkDirection {
        case .forward:
            let nextIdx = min(progressIdx + 1, activePolyline.count - 1)
            if nextIdx > progressIdx {
                currentRouteBearing = activePolyline[progressIdx].bearing(to: activePolyline[nextIdx])
            }
        case .reverse:
            let nextIdx = max(progressIdx - 1, 0)
            if nextIdx < progressIdx {
                currentRouteBearing = activePolyline[progressIdx].bearing(to: activePolyline[nextIdx])
            }
        }
    }

    private func angleDifference(_ a: Double, _ b: Double) -> Double {
        var diff = a - b
        while diff > 180  { diff -= 360 }
        while diff < -180 { diff += 360 }
        return diff
    }

    private func isArrivalInstruction(_ instruction: String) -> Bool {
        let lower = instruction.lowercased()
        return lower.contains("destination")
            || lower.contains("arrive")
            || lower.contains("arriving")
            || lower.contains("arrived")
            || lower.contains("you have reached")
            || lower.contains("end of route")
    }

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedSeconds = Date().timeIntervalSince(self?.startTime ?? Date())
                self?.stepCount = self?.pedometerService.currentStepCount ?? 0
                self?.session.stepCount = self?.stepCount ?? 0
            }
        }
    }

    // MARK: - Live Activity Timer (separate from UI timer)

    /// Starts a dedicated timer for Live Activity updates at ~8-second intervals,
    /// well within Apple's ActivityKit rate limit (~15s). Decoupled from the
    /// 1-second UI timer to avoid flooding ActivityKit with updates.
    private func startLiveActivityTimer() {
        liveActivityTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pushLiveActivityUpdate()
            }
        }
    }

    /// Pushes the current walk state to the Live Activity.
    /// Note: elapsed time is handled on-device via `Text(date, style: .timer)`
    /// and does not need to be sent here.
    private func pushLiveActivityUpdate() {
        let pace: Double = elapsedSeconds > 0 ? distanceWalked / elapsedSeconds : 0
        // Use a *dynamic* total = walked + remaining, so the Live Activity
        // progress bar reaches 100% when the user actually finishes the
        // route — even if a reroute shrank the total relative to the
        // originally-planned `route.distanceKilometers`.
        let totalDistance = distanceWalked + remainingMeters
        let progressFraction = totalDistance > 0 ? min(distanceWalked / totalDistance, 1.0) : progress

        // Find the next upcoming POI based on distance along route
        let nextPOI = findNextUpcomingPOI()

        // Parse turn-by-turn direction from current navigation instruction
        let directionArrow = directionArrow(from: currentInstruction)
        let directionText = currentInstruction == "Preparing navigation..." ? nil : currentInstruction
        let directionDistance: Double? = distanceToNextStep > 0 ? distanceToNextStep : nil

        liveActivityManager.updateActivity(
            distanceWalkedMeters: distanceWalked,
            currentPaceMetersPerSecond: pace,
            nextPOIName: nextPOI?.name,
            nextPOIDistanceMeters: nextPOI?.distance,
            progressFraction: progressFraction,
            nextDirectionArrow: directionArrow,
            nextDirectionText: directionText,
            nextDirectionDistanceMeters: directionDistance
        )
    }

    /// Maps a navigation instruction string to a direction arrow character.
    /// Parses keywords like "left", "right", "straight", "u-turn" from the instruction.
    private func directionArrow(from instruction: String) -> String? {
        let lower = instruction.lowercased()

        // Check for specific turn types before generic directions
        if lower.contains("u-turn") || lower.contains("u turn") || lower.contains("uturn") {
            return "↩"
        }
        if lower.contains("sharp left") || lower.contains("hard left") {
            return "↙"
        }
        if lower.contains("sharp right") || lower.contains("hard right") {
            return "↘"
        }
        if lower.contains("slight left") || lower.contains("bear left") || lower.contains("keep left") {
            return "↖"
        }
        if lower.contains("slight right") || lower.contains("bear right") || lower.contains("keep right") {
            return "↗"
        }
        if lower.contains("turn left") || lower.contains("left") {
            return "←"
        }
        if lower.contains("turn right") || lower.contains("right") {
            return "→"
        }
        if lower.contains("straight") || lower.contains("continue") || lower.contains("head ") {
            return "↑"
        }
        if lower.contains("arrive") || lower.contains("destination") {
            return "📍"
        }
        return nil
    }

    /// Finds the next POI the user hasn't passed yet, based on distance along route.
    private func findNextUpcomingPOI() -> (name: String, distance: Double)? {
        guard let location = userLocation else { return nil }

        // Filter to attractions (main POIs) and sort by distance along route
        let upcomingPOIs = route.attractions
            .compactMap { poi -> (name: String, distance: Double)? in
                let poiCoord = poi.location.clCoordinate
                let distanceToPOI = location.distance(to: poiCoord)
                // Only show POIs that are still ahead (more than 50m away)
                guard distanceToPOI > 50 else { return nil }
                return (name: poi.name, distance: distanceToPOI)
            }
            .sorted { $0.distance < $1.distance }

        return upcomingPOIs.first
    }

    private func triggerHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - POI Proximity (attractions)

    private func checkApproachingPOI(_ coordinate: CLLocationCoordinate2D) {
        var nearest: (poi: POI, dist: Double)?
        for poi in route.attractions {
            let dist = coordinate.distance(to: poi.location.clCoordinate)
            if dist <= 300, nearest == nil || dist < nearest!.dist {
                nearest = (poi, dist)
            }
        }
        approachingPOI = nearest.map { ApproachingPOIInfo(poi: $0.poi, distanceMeters: $0.dist) }
    }

    // MARK: - Reverse Geocoding

    private func updateStreetNameIfNeeded(_ clLocation: CLLocation) {
        if let last = lastGeocodingLocation {
            let dist = clLocation.distance(from: last)
            let elapsed = Date().timeIntervalSince(lastGeocodingDate)
            guard dist > 50 || elapsed > 10 else { return }
        }
        lastGeocodingLocation = clLocation
        lastGeocodingDate = Date()
        Task { await reverseGeocode(clLocation) }
    }

    private func reverseGeocode(_ location: CLLocation) async {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let p = placemarks.first {
                var parts: [String] = []
                if let street = p.thoroughfare { parts.append(street) }
                if let city = p.locality { parts.append(city) }
                currentStreetName = parts.joined(separator: ", ")
            }
        } catch { }
    }
}
