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
        isRerouting ? L10n.OffRoute.recalculating : L10n.OffRoute.checkingRoute
    }

    private var subtitle: String {
        if isRerouting { return L10n.OffRoute.findingPath }
        return "\(distanceMeters.formattedDistance()) \(L10n.POI.fromRoute)"
    }
}
