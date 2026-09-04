import XCTest
@testable import Looopr

/// The behaviour that matters is mostly negative: level ground must report
/// zero. The bug this replaces displayed a climb for walks that had none.
final class ElevationCalculatorTests: XCTestCase {

    private let threshold = ElevationAccumulator.defaultThreshold

    /// Deterministic pseudo-noise so a failure is always reproducible.
    private func noise(count: Int, amplitude: Double, base: Double = 0) -> [Double] {
        (0..<count).map { index in
            let angle = Double(index)
            let wobble = sin(angle * 1.7) + sin(angle * 0.41) + sin(angle * 3.13)
            return base + (wobble / 3) * amplitude
        }
    }

    // MARK: - Level ground reports nothing

    func testPerfectlyLevelGroundReportsNoGain() {
        XCTAssertEqual(ElevationAccumulator.gain(for: Array(repeating: 4, count: 200)), 0)
    }

    func testBarometricNoiseOnLevelGroundReportsNoGain() {
        // Barometer noise is a few tenths of a metre; well inside the threshold.
        let readings = noise(count: 300, amplitude: 0.4)
        XCTAssertEqual(ElevationAccumulator.gain(for: readings), 0,
                       "Level ground reported phantom climb")
    }

    func testSlowWeatherDriftDoesNotAccumulate() {
        // Pressure drifting one way over an hour must not read as a climb;
        // a steady 1 m drift stays under the threshold at every step.
        let readings = (0..<360).map { Double($0) * (1.0 / 360.0) }
        XCTAssertEqual(ElevationAccumulator.gain(for: readings), 0)
    }

    // MARK: - Real climbs are measured accurately

    func testSustainedClimbIsMeasuredCloseToItsTrueHeight() {
        // 40 m over 200 readings, with barometric noise on top.
        let wobble = noise(count: 200, amplitude: 0.4)
        let readings = (0..<200).map { Double($0) * 0.2 + wobble[$0] }
        let gain = ElevationAccumulator.gain(for: readings)
        XCTAssertGreaterThan(gain, 37, "Expected roughly 40 m, got \(gain)")
        XCTAssertLessThan(gain, 41, "Expected roughly 40 m, got \(gain)")
    }

    func testDescentIsNotSubtractedFromGain() {
        let up = (0..<100).map { Double($0) * 0.3 }        // +29.7 m
        let down = (0..<100).map { 30 - Double($0) * 0.3 } // and back down
        let gain = ElevationAccumulator.gain(for: up + down)
        XCTAssertGreaterThan(gain, 27, "Expected roughly 30 m, got \(gain)")
        XCTAssertLessThan(gain, 31, "Expected roughly 30 m, got \(gain)")
    }

    func testRepeatedClimbsBothCount() {
        let hill = (0..<50).map { Double($0) * 0.4 } + (0..<50).map { 20 - Double($0) * 0.4 }
        let gain = ElevationAccumulator.gain(for: hill + hill)
        XCTAssertGreaterThan(gain, 36, "Two 20 m hills should total roughly 40 m, got \(gain)")
        XCTAssertLessThan(gain, 42, "Two 20 m hills should total roughly 40 m, got \(gain)")
    }

    // MARK: - Accumulator mechanics

    func testGainStartsAtZeroBeforeAnyReading() {
        XCTAssertEqual(ElevationAccumulator().gain, 0)
    }

    func testFirstReadingOnlySetsTheAnchor() {
        var accumulator = ElevationAccumulator()
        accumulator.add(120)
        XCTAssertEqual(accumulator.gain, 0, "A single reading cannot establish a climb")
    }

    func testMovesSmallerThanTheThresholdAreIgnored() {
        var accumulator = ElevationAccumulator()
        accumulator.add(0)
        accumulator.add(threshold * 0.9)
        XCTAssertEqual(accumulator.gain, 0)
    }

    func testOnlyRelativeChangeMatters() {
        // Absolute offset is irrelevant — the barometer reports relative metres.
        let readings = (0..<100).map { Double($0) * 0.3 }
        let offset = readings.map { $0 + 8_000 }
        XCTAssertEqual(ElevationAccumulator.gain(for: readings),
                       ElevationAccumulator.gain(for: offset),
                       accuracy: 0.0001)
    }
}
