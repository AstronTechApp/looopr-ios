import SwiftUI

/// Shows while the detector is counting down (detecting) or while a reroute
/// is in progress. Disappears once the reroute succeeds — replaced by the
/// green "Route updated" toast in WalkNavigationView.
struct OffRouteBannerView: View {
    let isDetecting: Bool
    let isRerouting: Bool
    let distanceMeters: Double

    var body: some View {
        if isDetecting || isRerouting {
            HStack(spacing: AppTheme.spacingSmall) {
                if isRerouting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "location.slash")
                        .font(.body)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .opacity(0.85)
                }

                Spacer()
            }
            .foregroundStyle(.white)
            .padding(AppTheme.spacingSmall)
            .background(Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var title: String {
        isRerouting ? "Recalculating..." : "Checking route..."
    }

    private var subtitle: String {
        if isRerouting { return "Finding your path forward" }
        return "\(distanceMeters.formattedDistance()) from route"
    }
}
