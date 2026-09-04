import CoreLocation
import Combine

final class LiveLocationService: NSObject, LocationProviding, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    private let locationSubject = PassthroughSubject<CLLocation, Never>()
    private let authorizationSubject = PassthroughSubject<CLAuthorizationStatus, Never>()
    private let headingSubject = PassthroughSubject<CLLocationDirection, Never>()

    private(set) var currentCoordinate: CLLocationCoordinate2D?
    private(set) var currentLocation: CLLocation?
    private(set) var currentHeading: CLLocationDirection?

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    var isAuthorized: Bool {
        let status = authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    var locationPublisher: AnyPublisher<CLLocation, Never> {
        locationSubject.eraseToAnyPublisher()
    }

    var coordinatePublisher: AnyPublisher<CLLocationCoordinate2D, Never> {
        locationSubject.map(\.coordinate).eraseToAnyPublisher()
    }

    var authorizationPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        authorizationSubject.eraseToAnyPublisher()
    }

    var headingPublisher: AnyPublisher<CLLocationDirection, Never> {
        headingSubject.eraseToAnyPublisher()
    }

    /// True when the app declares the `location` background mode. Setting
    /// `allowsBackgroundLocationUpdates` without it is a hard crash, so this
    /// is read from the bundle rather than assumed.
    private static var declaresBackgroundLocationMode: Bool {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        return modes?.contains("location") ?? false
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        // Only report heading changes of >= 2° so the map camera isn't
        // re-targeted on compass micro-jitter.
        manager.headingFilter = 2
        manager.headingOrientation = .portrait

        // Core Location stops feeding updates once the app leaves the
        // foreground unless background updates are explicitly enabled. A
        // walk is precisely the case where the phone goes in a pocket, so
        // without this the recorded track ends at the lock screen.
        // "When In Use" authorisation is enough for this — iOS shows the
        // blue indicator while it's active, so `Always` isn't needed.
        if Self.declaresBackgroundLocationMode {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }

        // iOS pauses updates on its own when it decides the user has stopped
        // moving, and does not reliably resume. Looopr walks are slow and
        // full of deliberate stops at food and POI spots — exactly what that
        // heuristic mistakes for "finished" — so it stays off.
        manager.pausesLocationUpdatesAutomatically = false
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        currentCoordinate = location.coordinate
        locationSubject.send(location)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // `trueHeading` is -1 until Core Location has a fix to derive
        // magnetic declination from; fall back to magnetic heading so the
        // map can start rotating immediately.
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        guard heading >= 0 else { return }
        currentHeading = heading
        headingSubject.send(heading)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationSubject.send(manager.authorizationStatus)
    }
}
