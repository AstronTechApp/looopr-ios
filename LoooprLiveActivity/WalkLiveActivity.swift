import ActivityKit
import SwiftUI
import WidgetKit

struct WalkLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkActivityAttributes.self) { context in
            // MARK: - Lock Screen / Banner Presentation
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.routeName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            } compactLeading: {
                // MARK: - Compact Leading
                CompactLeadingView(context: context)
            } compactTrailing: {
                // MARK: - Compact Trailing
                CompactTrailingView(context: context)
            } minimal: {
                // MARK: - Minimal
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Color Helpers

private extension Color {
    static let loooprGreenDark = Color(red: 0x1B / 255.0, green: 0x5E / 255.0, blue: 0x20 / 255.0)
    static let loooprGreenLight = Color(red: 0x66 / 255.0, green: 0xBB / 255.0, blue: 0x6A / 255.0)
}

// MARK: - Formatting Helpers

/// Checks unit preference at call-time. Reads the same key the main app
/// writes via `SettingsManager`. Falls back to the device locale when the
/// preference is "system" or unset.
private func isImperial() -> Bool {
    let raw = UserDefaults.standard.string(forKey: "settings.unitPreference") ?? "system"
    switch raw {
    case "imperial": return true
    case "metric":   return false
    default:         return Locale.current.measurementSystem == .us
    }
}

private func formattedDistance(_ meters: Double) -> String {
    if isImperial() {
        let feet = meters * 3.28084
        if feet >= 5280 {
            return String(format: "%.1f mi", feet / 5280)
        }
        return String(format: "%d ft", Int(feet))
    } else {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%d m", Int(meters))
    }
}

private func formattedPace(_ metersPerSecond: Double) -> String {
    guard metersPerSecond > 0 else { return "--:--" }
    if isImperial() {
        let metersPerMile = 1609.344
        let secondsPerMile = metersPerMile / metersPerSecond
        let minutes = Int(secondsPerMile) / 60
        let seconds = Int(secondsPerMile) % 60
        return String(format: "%d:%02d /mi", minutes, seconds)
    } else {
        let secondsPerKm = 1000.0 / metersPerSecond
        let minutes = Int(secondsPerKm) / 60
        let seconds = Int(secondsPerKm) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}

/// Maps the arrow character the app sends to a proper SF Symbol, so the Lock
/// Screen reads like Apple Maps rather than a text arrow.
private func directionSymbol(for arrow: String) -> String {
    switch arrow {
    case "\u{2190}": return "arrow.turn.up.left"      // turn left
    case "\u{2192}": return "arrow.turn.up.right"     // turn right
    case "\u{2196}": return "arrow.up.left"           // slight left
    case "\u{2197}": return "arrow.up.right"          // slight right
    case "\u{2199}": return "arrow.turn.left.down"    // sharp left
    case "\u{2198}": return "arrow.turn.right.down"   // sharp right
    case "\u{21A9}": return "arrow.uturn.left"        // u-turn
    case "\u{1F4CD}": return "mappin.and.ellipse"     // arrival
    default: return "arrow.up"                          // continue straight
    }
}

/// How close a turn has to be before the Lock Screen promotes it over the
/// next-POI row. Matches the walking-speed reaction window: ~2 minutes out.
private let turnPromotionDistance: Double = 150

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<WalkActivityAttributes>

    /// The next turn, but only once it's within acting distance. Nil the rest
    /// of the time so the card falls back to its normal stats row.
    private var upcomingTurn: (arrow: String, text: String, distance: Double)? {
        guard let arrow = context.state.nextDirectionArrow,
              let text = context.state.nextDirectionText,
              let distance = context.state.nextDirectionDistanceMeters,
              distance <= turnPromotionDistance else { return nil }
        return (arrow, text, distance)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Route name + live-counting timer
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundStyle(Color.loooprGreenLight)
                Text(context.attributes.routeName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
                // System-driven timer — counts every second on-device,
                // no app updates required.
                Text(context.state.walkStartDate, style: .timer)
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(.medium)
                    .multilineTextAlignment(.trailing)
            }

            // Progress bar
            ProgressBarView(progress: context.state.progressFraction)

            // Bottom row — the upcoming turn takes over from the next-POI
            // readout once it's close enough to act on, so the card stays the
            // same height but shows whichever is actually useful right now.
            if let turn = upcomingTurn {
                TurnRowView(
                    symbol: directionSymbol(for: turn.arrow),
                    instruction: turn.text,
                    distanceMeters: turn.distance,
                    walkedMeters: context.state.distanceWalkedMeters
                )
            } else {
                HStack {
                    StatItem(
                        icon: "mappin.and.ellipse",
                        value: formattedDistance(context.state.distanceWalkedMeters),
                        label: String(localized: "liveActivity.walked", defaultValue: "walked")
                    )
                    Spacer()
                    if let poiName = context.state.nextPOIName,
                       let poiDist = context.state.nextPOIDistanceMeters {
                        StatItem(
                            icon: "star.fill",
                            value: poiName,
                            label: formattedDistance(poiDist) + " " + String(localized: "liveActivity.ahead", defaultValue: "ahead")
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.loooprGreenDark, Color.loooprGreenLight],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .foregroundStyle(.white)
    }
}

// MARK: - Turn Row

/// The "act now" row: big direction glyph, the street-level instruction from
/// MapKit, and how far out the turn is — with distance walked kept on the
/// right so the card doesn't lose it entirely while navigating.
private struct TurnRowView: View {
    let symbol: String
    let instruction: String
    let distanceMeters: Double
    let walkedMeters: Double

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(instruction)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.8)

                Text("\(String(localized: "liveActivity.inDistance", defaultValue: "in")) \(formattedDistance(distanceMeters))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer(minLength: 4)

            StatItem(
                icon: "mappin.and.ellipse",
                value: formattedDistance(walkedMeters),
                label: String(localized: "liveActivity.walked", defaultValue: "walked")
            )
        }
    }
}

// MARK: - Progress Bar

private struct ProgressBarView: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 6)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.loooprGreenLight, Color.loooprGreenLight.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, geometry.size.width * CGFloat(min(progress, 1.0))), height: 6)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Stat Item

private struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(Color.loooprGreenLight)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Dynamic Island: Compact
// Strategy: use `Text(timerInterval:countsDown:)` for a LIVE every-second
// timer, constrained inside a tight fixed frame with `minimumScaleFactor`
// so SwiftUI shrinks the text to fit instead of stretching the pill.
// Trailing shows distance normally, but swaps to a turn arrow when the
// user is within 100 m of a navigation step.

private struct CompactLeadingView: View {
    let context: ActivityViewContext<WalkActivityAttributes>

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: "figure.walk")
                .font(.system(size: 10))
                .foregroundStyle(Color.loooprGreenLight)

            // Live-counting system timer — updates every second on-device.
            // `timerInterval` with an open-ended range counts up from the
            // start date. The fixed frame + minimumScaleFactor keeps it
            // from blowing out the compact pill width.
            Text(timerInterval: context.state.walkStartDate...Date.distantFuture,
                 countsDown: false)
                .font(.system(size: 11, design: .monospaced))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .frame(maxWidth: 40)
                .lineLimit(1)
                .foregroundStyle(.white)
        }
    }
}

private struct CompactTrailingView: View {
    let context: ActivityViewContext<WalkActivityAttributes>

    var body: some View {
        // When the user is within 100 m of a turn, show the direction
        // arrow so they get a heads-up right when they need it.
        // Otherwise show the short distance walked.
        if let arrow = context.state.nextDirectionArrow,
           let dist = context.state.nextDirectionDistanceMeters,
           dist < 100 {
            Image(systemName: directionSymbol(for: arrow))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.loooprGreenLight)
        } else {
            Text(compactDistance(context.state.distanceWalkedMeters))
                .font(.system(size: 11, design: .monospaced))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(Color.loooprGreenLight)
        }
    }
}

/// Ultra-short distance for the compact trailing slot: "0m", "340m", "1.2k", "5.0k"
private func compactDistance(_ meters: Double) -> String {
    if isImperial() {
        let feet = meters * 3.28084
        if feet >= 5280 {
            return String(format: "%.1fmi", feet / 5280)
        }
        return "\(Int(feet))ft"
    } else {
        if meters >= 1000 {
            return String(format: "%.1fk", meters / 1000)
        }
        return "\(Int(meters))m"
    }
}

// MARK: - Dynamic Island: Minimal

private struct MinimalView: View {
    let context: ActivityViewContext<WalkActivityAttributes>

    var body: some View {
        Image(systemName: "figure.walk")
            .foregroundStyle(Color.loooprGreenLight)
            .font(.caption)
    }
}

// MARK: - Dynamic Island: Expanded

private struct ExpandedLeadingView: View {
    let context: ActivityViewContext<WalkActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label {
                Text(context.state.walkStartDate, style: .timer)
                    .font(.caption.monospacedDigit())
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.trailing)
            } icon: {
                Image(systemName: "timer")
                    .font(.caption2)
            }
            .foregroundStyle(.white)

            Label {
                Text(formattedDistance(context.state.distanceWalkedMeters))
                    .font(.caption.monospacedDigit())
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")
                    .font(.caption2)
            }
            .foregroundStyle(.white.opacity(0.85))
        }
    }
}

private struct ExpandedTrailingView: View {
    let context: ActivityViewContext<WalkActivityAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Label {
                Text(formattedPace(context.state.currentPaceMetersPerSecond))
                    .font(.caption.monospacedDigit())
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: "speedometer")
                    .font(.caption2)
            }
            .foregroundStyle(.white.opacity(0.85))

            Text(String(format: "%.0f%%", context.state.progressFraction * 100))
                .font(.caption.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(Color.loooprGreenLight)
        }
    }
}

private struct ExpandedBottomView: View {
    let context: ActivityViewContext<WalkActivityAttributes>

    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            ProgressBarView(progress: context.state.progressFraction)

            // Turn-by-turn direction
            if let arrow = context.state.nextDirectionArrow,
               let text = context.state.nextDirectionText {
                HStack(spacing: 6) {
                    Image(systemName: directionSymbol(for: arrow))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.loooprGreenLight)
                    Text(text)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    if let dist = context.state.nextDirectionDistanceMeters {
                        Text(formattedDistance(dist))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }

            // Next POI
            if let poiName = context.state.nextPOIName,
               let poiDist = context.state.nextPOIDistanceMeters {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.loooprGreenLight)
                    Text("\(String(localized: "liveActivity.next", defaultValue: "Next:")) \(poiName)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(formattedDistance(poiDist))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}
