#if DEBUG
import SwiftUI
import CoreLocation

/// Debug overlay for navigation — shown only in DEBUG builds.
/// Defaults to visible during development (see `showDebugOverlay` in
/// WalkNavigationView). Surfaces reroute internals at a glance so
/// you don't need an attached Xcode console to see whether state changed.
struct DebugNavigationOverlay: View {
    let deviationMeters: Double
    let heading: CLLocationDirection
    let gpsAccuracy: Double
    let reentryCoordinate: CLLocationCoordinate2D?
    let lastRerouteDate: Date?
    let routeProgress: Double
    let detectorState: OffRouteDetector.OffRouteStatus
    let wrongWaySnapshot: WrongWayDetectorDebugSnapshot
    let isRerouting: Bool
    let lastClosestPolylineIndex: Int
    let currentInstruction: String
    let routeFlipPhase: RouteFlipPhase
    let routeFlipMessage: String
    let routeFlipPathPointCount: Int
    let routeFlipStepCount: Int
    let routeFlipFirstInstruction: String
    let routeFlipLastAttemptDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NAV DEBUG")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(.yellow)

            Divider().background(.white.opacity(0.3))

            debugRow("Closest idx", "\(lastClosestPolylineIndex)")
            debugRow("Instr", instructionPreview)

            Divider().background(.white.opacity(0.3))

            debugRow("Deviation", "\(Int(deviationMeters)) m")
            debugRow("Heading", "\(Int(heading))°")
            debugRow("GPS acc", String(format: "%.1f m", gpsAccuracy))
            debugRow("Progress", String(format: "%.1f%%", routeProgress * 100))
            debugRow("Detector", detectorLabel)
            debugRow("Rerouting", isRerouting ? "YES" : "no")
            debugRow("Wrong way", wrongWaySnapshot.status)
            debugRow("WW msg", wrongWayMessagePreview)
            debugRow("WW dist", wrongWayDistanceLabel)
            debugRow("WW win", wrongWayWindowLabel)
            debugRow("WW div", wrongWayDivergenceLabel)

            Divider().background(.white.opacity(0.3))

            debugRow("Flip", routeFlipPhase.debugLabel)
            debugRow("Flip msg", routeFlipMessagePreview)
            debugRow("Flip pts", "\(routeFlipPathPointCount)")
            debugRow("Flip steps", "\(routeFlipStepCount)")
            debugRow("Flip instr", routeFlipInstructionPreview)

            if let coord = reentryCoordinate {
                debugRow("Re-entry", String(format: "%.5f, %.5f", coord.latitude, coord.longitude))
            } else {
                debugRow("Re-entry", "—")
            }

            if let date = lastRerouteDate {
                debugRow("Last reroute", timeAgo(date))
            } else {
                debugRow("Last reroute", "never")
            }

            if let date = routeFlipLastAttemptDate {
                debugRow("Last flip", timeAgo(date))
            } else {
                debugRow("Last flip", "never")
            }
        }
        .padding(10)
        .background(.black.opacity(0.75))
        .foregroundStyle(.white)
        .font(.system(.caption2, design: .monospaced))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    /// First ~28 chars of the current instruction — long enough to see it
    /// change after a flip without overflowing the overlay.
    private var instructionPreview: String {
        preview(currentInstruction)
    }

    private var routeFlipMessagePreview: String {
        preview(routeFlipMessage)
    }

    private var routeFlipInstructionPreview: String {
        preview(routeFlipFirstInstruction)
    }

    private var wrongWayMessagePreview: String {
        preview(wrongWaySnapshot.reason)
    }

    private var wrongWayDistanceLabel: String {
        "\(Int(wrongWaySnapshot.wrongWayMeters))/\(Int(wrongWaySnapshot.triggerMeters)) m"
    }

    private var wrongWayWindowLabel: String {
        "\(Int(wrongWaySnapshot.windowMeters))/\(Int(wrongWaySnapshot.windowLimitMeters)) m"
    }

    private var wrongWayDivergenceLabel: String {
        guard let divergence = wrongWaySnapshot.divergenceDegrees else { return "-" }
        if let reverseAlignment = wrongWaySnapshot.reverseStartAlignmentDegrees {
            return "\(Int(divergence))deg / rev \(Int(reverseAlignment))deg"
        }
        return "\(Int(divergence))deg"
    }

    private func preview(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "-" }
        return trimmed.count <= 28 ? trimmed : String(trimmed.prefix(28)) + "..."
    }

    private func debugRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label + ":")
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 80, alignment: .leading)
            Text(value)
                .foregroundStyle(.white)
        }
    }

    private var detectorLabel: String {
        switch detectorState {
        case .onRoute:              return "on-route"
        case .detecting(let d):    return "detecting (\(Int(d))m)"
        case .confirmed(let d):    return "CONFIRMED (\(Int(d))m)"
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let elapsed = Int(Date().timeIntervalSince(date))
        if elapsed < 60 { return "\(elapsed)s ago" }
        return "\(elapsed / 60)m ago"
    }
}
#endif
