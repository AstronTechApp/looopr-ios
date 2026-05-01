import CoreMotion
import Foundation

final class LivePedometerService: PedometerProviding, @unchecked Sendable {
    private let pedometer = CMPedometer()
    private let logger = AppLogger(category: "Pedometer")

    private(set) var currentStepCount: Int = 0

    var isAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    func startCounting() {
        guard isAvailable else {
            logger.warning("Step counting not available on this device")
            return
        }

        currentStepCount = 0
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            if let error {
                Task { @MainActor in
                    self?.logger.error("Pedometer error: \(error.localizedDescription)")
                }
                return
            }
            guard let steps = data?.numberOfSteps.intValue else { return }
            Task { @MainActor in
                self?.currentStepCount = steps
            }
        }
        logger.info("Pedometer started")
    }

    func stopCounting() {
        pedometer.stopUpdates()
        logger.info("Pedometer stopped — total steps: \(currentStepCount)")
    }
}
