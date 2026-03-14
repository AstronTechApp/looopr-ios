import SwiftUI
import MapKit

struct RouteCardView: View {
    let route: Route
    let onTap: () -> Void

    private var routeColor: Color {
        AppTheme.routeColor(for: route.colorIndex)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                // Mini map preview
                RouteMapPreview(route: route, color: routeColor)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))

                // Route info
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .font(AppTheme.headlineFont)
                        .foregroundStyle(.primary)

                    HStack(spacing: AppTheme.spacingMedium) {
                        Label("\(route.durationMinutes) min", systemImage: "clock")
                        Label(String(format: "%.1f km", route.distanceKilometers), systemImage: "figure.walk")
                        DifficultyBadge(difficulty: route.difficulty)
                    }
                    .font(AppTheme.captionFont)
                    .foregroundStyle(.secondary)
                }

                // POI preview (if any)
                if !route.attractions.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text("\(route.attractions.count) attraction\(route.attractions.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(AppTheme.spacingSmall)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(routeColor.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Route Map Preview

struct RouteMapPreview: View {
    let route: Route
    let color: Color

    var body: some View {
        Map {
            MapPolyline(coordinates: route.pathCoordinates)
                .stroke(color, lineWidth: 3)

            if let start = route.pathCoordinates.first {
                Annotation("Start", coordinate: start) {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
    }
}

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let difficulty: Route.Difficulty

    private var color: Color {
        switch difficulty {
        case .easy:        return .green
        case .moderate:    return .orange
        case .challenging: return .red
        }
    }

    var body: some View {
        Text(difficulty.rawValue.capitalized)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
