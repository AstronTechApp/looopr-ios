import SwiftUI

struct TimeSelectorView: View {
    @Binding var minutes: Int
    var onChange: () -> Void

    private var displayTime: String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }

    var body: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            Text(displayTime)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primary)
                .contentTransition(.numericText())
                .animation(.snappy, value: minutes)

            Slider(
                value: Binding(
                    get: { Double(minutes) },
                    set: { newValue in
                        let newMinutes = Int(newValue)
                        if newMinutes != minutes {
                            minutes = newMinutes
                            onChange()
                        }
                    }
                ),
                in: 5...180,
                step: 5
            )
            .tint(AppTheme.primary)

            HStack {
                Text("5 min")
                Spacer()
                Text("3 hours")
            }
            .font(AppTheme.captionFont)
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, AppTheme.spacingLarge)
    }
}
