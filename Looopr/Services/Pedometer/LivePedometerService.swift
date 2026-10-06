import CoreMotion
import Foundation

final class LivePedometerService: PedometerProviding, @unchecked Sendable {
    private let pedometer = CMPedometer()
    private let logger = AppLogger(category: "Pedometer")
    private var startDate: Date?

    private(set) var currentStepCount: Int = 0

    var isAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    var isAuthorizationDenied: Bool {
        switch CMPedometer.authorizationStatus() {
        case .denied, .restricted: return true
        case .authorized, .notDetermined: return false
        @unknown default: return false
        }
    }

    func startCounting() {
        guard isAvailable else {
            logger.warning("Step counting not available on this device")
            return
        }

        let start = Date()
        startDate = start
        currentStepCount = 0
        logger.info("Pedometer starting; Motion & Fitness authorization: \(Self.describe(CMPedometer.authorizationStatus()))")

        pedometer.startUpdates(from: start) { [weak self] data, error in
            if let error {
                let code = (error as NSError).code
                self?.logger.error("Pedometer update error (code \(code)): \(error.localizedDescription)")
                return
            }
            guard let steps = data?.numberOfSteps.intValue else { return }
            Task { @MainActor in
                self?.currentStepCount = steps
            }
        }
    }

    @discardableResult
    func stopCounting() async -> Int {
        pedometer.stopUpdates()
        let live = currentStepCount
        guard let startDate else {
            logger.info("Pedometer stopped — total steps: \(live)")
            return live
        }
        self.startDate = nil

        // Live updates arrive in batches and the last batch is often still
        // in flight when the walk ends, so ask CoreMotion for the stored
        // total over the exact interval. Fall back to the live figure if the
        // query fails (e.g. permission denied), never to less than it.
        let queried = await queryStepCount(from: startDate, to: Date())
        let total = max(live, queried ?? 0)
        currentStepCount = total
        logger.info("Pedometer stopped — live \(live), queried \(queried.map(String.init) ?? "n/a"), final \(total)")
        return total
    }

    // MARK: - Private

    private func queryStepCount(from: Date, to: Date) async -> Int? {
        await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: from, to: to) { [weak self] data, error in
                if let error {
                    let code = (error as NSError).code
                    self?.logger.error("Pedometer query error (code \(code)): \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: data?.numberOfSteps.intValue)
            }
        }
    }

    private static func describe(_ status: CMAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default: return "unknown"
        }
    }
}
