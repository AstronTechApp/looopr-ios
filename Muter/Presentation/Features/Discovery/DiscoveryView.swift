import SwiftUI

struct DiscoveryView: View {
    @State private var selectedMinutes: Double = 60

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: AppTheme.spacingSmall) {
                Text("Muter")
                    .font(.largeTitle.bold())
                Text("Discover the perfect walk")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, AppTheme.spacingLarge)

            // Time Selector
            VStack(spacing: AppTheme.spacingSmall) {
                Text("\(Int(selectedMinutes)) min")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primary)

                Slider(value: $selectedMinutes, in: 5...180, step: 5)
                    .tint(AppTheme.primary)
                    .padding(.horizontal, AppTheme.spacingLarge)

                HStack {
                    Text("5 min")
                    Spacer()
                    Text("3 hours")
                }
                .font(AppTheme.captionFont)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, AppTheme.spacingLarge)
            }
            .padding(.vertical, AppTheme.spacingLarge)

            Divider()

            // Route List placeholder
            ScrollView {
                EmptyStateView(
                    title: "Set your time",
                    subtitle: "Choose how much time you have and we'll find the perfect walking routes for you.",
                    systemImage: "figure.walk"
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DiscoveryView()
    }
}
