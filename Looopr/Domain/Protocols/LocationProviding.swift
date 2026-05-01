import CoreLocation
import Combine

protocol LocationProviding: AnyObject, Sendable {
    var currentCoordinate: CLLocationCoordinate2D? { get }
    var currentLocation: CLLocation? { get }
    var currentHeading: CLLocationDirection? { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    var isAuthorized: Bool { get }

    var coordinatePublisher: AnyPublisher<CLLocationCoordinate2D, Never> { get }
    var locationPublisher: AnyPublisher<CLLocation, Never> { get }
    var authorizationPublisher: AnyPublisher<CLAuthorizationStatus, Never> { get }

    func requestAuthorization()
    func startUpdating()
    func stopUpdating()
}
