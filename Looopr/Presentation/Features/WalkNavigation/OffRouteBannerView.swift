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

/// Shown instead of the off-route banner once automatic rerouting has
/// been paused: the user keeps leaving every new route, so stop buzzing
/// and let them choose.
struct OwnWayBannerView: View {
    let onGuideMeBack: () -> Void
    let onEndWalk: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack(spacing: AppTheme.spacingSmall) {
                Image(systemName: "figure.walk.motion")
                    .font(.body)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.OffRoute.ownWayTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(L10n.OffRoute.ownWayBody)
                        .font(.caption)
                        .opacity(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: AppTheme.spacingSmall) {
                Button(action: onGuideMeBack) {
                    Text(L10n.OffRoute.guideMeBack)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.white)
                        .foregroundStyle(Color(hex: "#1B5E20"))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button(action: onEndWalk) {
                    Text(L10n.WalkNavigation.endWalkButton)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(AppTheme.spacingSmall)
        .background(Color(hex: "#1B5E20").opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .contain)
    }
}
