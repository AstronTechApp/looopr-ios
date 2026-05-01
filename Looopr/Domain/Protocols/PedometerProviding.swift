import Foundation

protocol PedometerProviding: AnyObject, Sendable {
    var currentStepCount: Int { get }
    var isAvailable: Bool { get }
    func startCounting()
    func stopCounting()
}
