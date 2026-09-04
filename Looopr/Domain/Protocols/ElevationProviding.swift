import Foundation

/// Tracks elevation gain over the course of a walk.
///
/// Backed by the iPhone's barometer rather than GPS altitude — see
/// `ElevationAccumulator` for why GPS is unusable for this.
protocol ElevationProviding: AnyObject, Sendable {
    /// Metres climbed since `startTracking()`. Zero before a walk begins.
    var elevationGainMeters: Double { get }

    /// False on hardware with no barometer, and on any device that refuses
    /// motion access. Callers should report "not measured" rather than zero.
    var isAvailable: Bool { get }

    func startTracking()
    func stopTracking()
}
