import SwiftUI

struct POICardView: View {
    let poi: POI
    let isHighlighted: Bool
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            HStack(spacing: AppTheme.spacingSmall) {
                // Category icon
                Image(systemName: poi.category.systemImage)
                    .font(.title3)
                    .foregroundStyle(isHighlighted ? .yellow : .orange)
                    .frame(width: 36, height: 36)
                    .background(
                        (isHighlighted ? Color.yellow : Color.orange).opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(poi.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if isHighlighted {
                            Text("Featured")
                                .font(.caption2.bold())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.yellow.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 8) {
                        if let rating = poi.rating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                                Text(String(format: "%.1f", rating))
                                    .font(.caption)
                            }
                        }

                        Text(poi.category.displayName)
                            .font(.caption)

                        if let isOpen = poi.isOpenNow {
                            Text(isOpen ? "Open" : "Closed")
                                .font(.caption2.bold())
                                .foregroundStyle(isOpen ? .green : .red)
                        }
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(AppTheme.spacingSmall)
            .background(AppTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                    .strokeBorder(
                        isHighlighted ? Color.yellow.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            POIDetailView(poi: poi)
        }
    }
}
