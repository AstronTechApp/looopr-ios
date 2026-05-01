import CoreLocation

final class StepTracker {
    private let config: AppConfiguration

    private(set) var currentStepIndex: Int = 0
    private(set) var lastAdvanceTime: Date = Date()

    init(configuration: AppConfiguration = .current) {
        self.config = configuration
    }

    func shouldAdvance(
        userLocation: CLLocationCoordinate2D,
        targetCoordinate: CLLocationCoordinate2D,
        totalSteps: Int
    ) -> Bool {
        guard currentStepIndex < totalSteps - 1 else { return false }
        let distance = userLocation.distance(to: targetCoordinate)
        return distance <= config.navigation.stepAdvanceThresholdMeters
    }

    func advance() {
        currentStepIndex += 1
        lastAdvanceTime = Date()
    }

    func hasNoProgress(since timeout: TimeInterval) -> Bool {
        Date().timeIntervalSince(lastAdvanceTime) >= timeout
    }

    func reset() {
        currentStepIndex = 0
        lastAdvanceTime = Date()
    }

    func set(index: Int) {
        currentStepIndex = index
        lastAdvanceTime = Date()
    }
}
