import SwiftUI

/// Bottom prompt presented when wrong-way travel is detected.
/// Matches Looopr's visual style: coral/orange accent, rounded corners,
/// dark/light mode support.
struct WrongWaySheetView: View {
    let onFlipRoute: () -> Void
    let onKeepGoing: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.spacingMedium) {
            // Drag indicator
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, AppTheme.spacingSmall)

            // Icon
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            // Title + message
            Text(L10n.WrongWay.title)
                .font(.title3.bold())

            Text(L10n.WrongWay.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.spacingMedium)

            // Actions
            //
            // `.contentShape(Rectangle())` is critical here: without it,
            // SwiftUI hit-tests against the inner Text shape rather than
            // the colored RoundedRectangle background. Inside a `.sheet`
            // with `.presentationDetents`, the gesture system can
            // additionally swallow taps that aren't on a clearly-defined
            // hit shape (the sheet's drag handler eats them as potential
            // drag-to-dismiss gestures). `.buttonStyle(.plain)` removes
            // any default SwiftUI button styling that could interfere.
            VStack(spacing: AppTheme.spacingSmall) {
                Button {
                    onFlipRoute()
                } label: {
                    Text(L10n.WrongWay.flipRoute)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    onKeepGoing()
                } label: {
                    Text(L10n.WrongWay.turnAround)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.bottom, AppTheme.spacingLarge)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.6), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 28, y: 14)
    }
}
