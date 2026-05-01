import CoreLocation

final class OffRouteDetector {
    private let config: AppConfiguration
    private var offRouteSince: Date?

    init(configuration: AppConfiguration = .current) {
        self.config = configuration
    }

    var isOffRoute: Bool { offRouteSince != nil }

    func check(
        userLocation: CLLocationCoordinate2D,
        horizontalAccuracy: Double = 0,
        polyline: [CLLocationCoordinate2D]
    ) -> OffRouteStatus {
        // Ignore noisy GPS — don't start the off-route timer on bad fixes
        if horizontalAccuracy > config.navigation.gpsAccuracyThresholdMeters {
            return .onRoute
        }

        let distance = RouteGeometry.minimumDistance(
            from: userLocation,
            toPolyline: polyline
        )

        if distance > config.navigation.offRouteThresholdMeters {
            if offRouteSince == nil { offRouteSince = Date() }
            let elapsed = Date().timeIntervalSince(offRouteSince!)
            if elapsed >= config.navigation.offRouteHoldSeconds {
                return .confirmed(distanceMeters: distance)
            }
            return .detecting(distanceMeters: distance)
        } else {
            offRouteSince = nil
            return .onRoute
        }
    }

    func reset() {
        offRouteSince = nil
    }

    enum OffRouteStatus {
        case onRoute
        case detecting(distanceMeters: Double)
        case confirmed(distanceMeters: Double)
    }
}
