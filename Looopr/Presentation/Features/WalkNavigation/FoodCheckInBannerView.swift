import SwiftUI

struct FoodCheckInBannerView: View {
    let foodSpotName: String
    let onCheckIn: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.FoodCheckIn.nearestFood(foodSpotName))
                    .font(.subheadline.weight(.semibold))
                Text(L10n.FoodCheckIn.stoppingForBreak)
                    .font(.caption)
                    .opacity(0.85)
            }

            Spacer()

            Button(L10n.FoodCheckIn.checkInButton) {
                onCheckIn()
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white)
            .foregroundStyle(.orange)
            .clipShape(Capsule())

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
            }
        }
        .foregroundStyle(.white)
        .padding(AppTheme.spacingSmall)
        .background(Color.orange)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
