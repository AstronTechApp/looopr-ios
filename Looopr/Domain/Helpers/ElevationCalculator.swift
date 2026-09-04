import Foundation

/// Accumulates elevation gain from a stream of altitude readings.
///
/// Gain accrues only once altitude climbs more than `threshold` above a
/// moving anchor, and the anchor only follows the terrain down once it falls
/// more than `threshold` below. That symmetry matters: an anchor that slides
/// down on every dip lets sensor noise ratchet upward, inventing a climb out
/// of level ground.
///
/// The threshold is calibrated for the **barometer**, whose readings are
/// stable to well under a metre. GPS altitude is deliberately not used here:
/// its error is both large (±5–10 m) and slowly drifting, which is
/// indistinguishable from gentle terrain at any smoothing window — measured
/// against realistic GPS noise, even aggressive filtering reported 10–20 m of
/// climb across flat ground while under-reporting real hills.
struct ElevationAccumulator {

    /// Metres a reading must clear before it counts as a real move. Barometric
    /// noise sits far below this; slow weather drift over an hour is roughly
    /// this size, which is why it isn't smaller.
    static let defaultThreshold: Double = 1.5

    private let threshold: Double
    private var anchor: Double?

    /// Total climb in metres. Descent is tracked but never subtracted — this
    /// is gain, not net change.
    private(set) var gain: Double = 0

    init(threshold: Double = ElevationAccumulator.defaultThreshold) {
        self.threshold = threshold
    }

    /// Feeds in one altitude reading, in metres. Absolute or relative to the
    /// start of the walk — only the differences matter.
    mutating func add(_ altitude: Double) {
        guard let current = anchor else {
            anchor = altitude
            return
        }

        if altitude > current + threshold {
            gain += altitude - current
            anchor = altitude
        } else if altitude < current - threshold {
            anchor = altitude
        }
    }

    /// Convenience for a complete series, used by the tests.
    static func gain(
        for altitudes: [Double],
        threshold: Double = defaultThreshold
    ) -> Double {
        var accumulator = ElevationAccumulator(threshold: threshold)
        for altitude in altitudes { accumulator.add(altitude) }
        return accumulator.gain
    }
}
