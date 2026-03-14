import SwiftUI

struct POIListView: View {
    let attractions: [POI]
    let foodSpots: [POI]

    var body: some View {
        LazyVStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            // Tourist Attractions - highlighted section
            if !attractions.isEmpty {
                SectionHeader(
                    title: "Attractions",
                    subtitle: "Highlighted spots along your route",
                    icon: "star.fill",
                    color: .yellow
                )

                ForEach(attractions) { poi in
                    POICardView(poi: poi, isHighlighted: true)
                }
            }

            // Food & Drink - secondary section
            if !foodSpots.isEmpty {
                SectionHeader(
                    title: "Along your route",
                    subtitle: "Cafes & restaurants rated 4.4+",
                    icon: "fork.knife",
                    color: .orange
                )

                ForEach(foodSpots) { poi in
                    POICardView(poi: poi, isHighlighted: false)
                }
            }
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.bottom, AppTheme.spacingLarge)
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(AppTheme.headlineFont)
            }
            Text(subtitle)
                .font(AppTheme.captionFont)
                .foregroundStyle(.secondary)
        }
        .padding(.top, AppTheme.spacingSmall)
    }
}
