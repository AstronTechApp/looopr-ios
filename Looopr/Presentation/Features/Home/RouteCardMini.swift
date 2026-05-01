import SwiftUI
import MapKit

/// Route card for horizontal scroll lists — "Organic Editorial" style.
/// Shows a map preview with gradient overlay, distance/time chips, route name, and subtitle.
struct RouteCardMini: View {
    let route: Route
    let onTap: () -> Void

    private var routeColor: Color {
        AppTheme.routeColor(for: route.colorIndex)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Top: map preview with gradient overlay and chips
                ZStack(alignment: .bottomLeading) {
                    RouteMapPreview(route: route, color: routeColor)
                        .frame(height: 140)
                        .clipped()

                    // Gradient overlay (bottom fade)
                    LinearGradient(
                        colors: [.black.opacity(0.5), .clear],
                        startPoint: .bottom,
                        endPoint: .center
                    )

                    // Distance + time chips
                    HStack(spacing: 6) {
                        Text(route.distanceKilometers.formattedDistanceFromKm())
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(-0.3)
                            .textCase(.uppercase)
                            .foregroundStyle(Color(hex: "#005c15"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(LoooprTheme.Colors.primaryLight.opacity(0.9))
                            .clipShape(Capsule())

                        Text(route.paceAdjustedDurationLabel)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(-0.3)
                            .textCase(.uppercase)
                            .foregroundStyle(Color(hex: "#7b3100"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(LoooprTheme.Colors.secondaryContainer.opacity(0.9))
                            .clipShape(Capsule())
                    }
                    .padding(10)
                }

                // Bottom: route info
                VStack(alignment: .leading, spacing: 3) {
                    Text(route.displayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .tracking(-0.3)
                        .foregroundStyle(LoooprTheme.Colors.textPrimary)
                        .lineLimit(2)

                    if !route.description.isEmpty {
                        Text(route.description)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(LoooprTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 220)
            .background(LoooprTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.xl))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
