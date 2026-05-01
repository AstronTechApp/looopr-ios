import SwiftUI

struct WalkStatsBar: View {
    let elapsedSeconds: TimeInterval
    let distanceWalked: Double
    let remainingSteps: Int
    var stepCount: Int = 0

    var body: some View {
        HStack(spacing: AppTheme.spacingMedium) {
            statItem(icon: "clock", value: formattedTime)
            Divider().frame(height: 20)
            statItem(icon: "figure.walk", value: formattedDistance)
            if stepCount > 0 {
                Divider().frame(height: 20)
                statItem(icon: "shoeprints.fill", value: formattedSteps)
            }
            Divider().frame(height: 20)
            statItem(icon: "point.topleft.down.to.point.bottomright.curvepath", value: "\(remainingSteps) steps")
        }
        .font(.caption.monospacedDigit())
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.vertical, AppTheme.spacingSmall)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private func statItem(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }

    private var formattedTime: String {
        let minutes = Int(elapsedSeconds) / 60
        let seconds = Int(elapsedSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var formattedDistance: String {
        distanceWalked.formattedDistance()
    }

    private var formattedSteps: String {
        if stepCount >= 1000 {
            return String(format: "%.1fk", Double(stepCount) / 1000)
        }
        return "\(stepCount)"
    }
}
