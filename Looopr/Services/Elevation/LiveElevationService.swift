import CoreMotion
import Foundation

/// Barometric elevation tracking.
///
/// `CMAltimeter` reports altitude *relative* to the moment tracking started,
/// derived from air pressure, and is accurate to roughly a metre — one to two
/// orders of magnitude better than GPS altitude for measuring change. Every
/// iPhone since the 6 has the sensor.
///
/// Updates continue while the phone is locked because the walk already holds
/// a background location session, and no new permission is needed: the
/// pedometer already requires motion access.
final class LiveElevationService: ElevationProviding, @unchecked Sendable {

    private let altimeter = CMAltimeter()
    private let logger = AppLogger(category: "Elevation")

    private let stateLock = NSLock()
    private var accumulator = ElevationAccumulator()
    private var isTracking = false

    var elevationGainMeters: Double {
        stateLock.lock()
        defer { stateLock.unlock() }
        return accumulator.gain
    }

    var isAvailable: Bool {
        CMAltimeter.isRelativeAltitudeAvailable()
            && CMAltimeter.authorizationStatus() != .denied
            && CMAltimeter.authorizationStatus() != .restricted
    }

    func startTracking() {
        guard isAvailable else {
            logger.warning("Barometric altitude unavailable — elevation will not be measured")
            return
        }

        stateLock.lock()
        guard !isTracking else { stateLock.unlock(); return }
        accumulator = ElevationAccumulator()
        isTracking = true
        stateLock.unlock()

        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self else { return }
            if let error {
                self.logger.error("Altimeter error: \(error.localizedDescription)")
                return
            }
            guard let metres = data?.relativeAltitude.doubleValue else { return }

            self.stateLock.lock()
            self.accumulator.add(metres)
            self.stateLock.unlock()
        }

        logger.info("Barometric elevation tracking started")
    }

    func stopTracking() {
        stateLock.lock()
        let wasTracking = isTracking
        isTracking = false
        let total = accumulator.gain
        stateLock.unlock()

        guard wasTracking else { return }
        altimeter.stopRelativeAltitudeUpdates()
        logger.info("Elevation tracking stopped — gain: \(Int(total)) m")
    }
}
