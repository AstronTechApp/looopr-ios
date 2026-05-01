import SwiftUI

struct POICardView: View {
    let poi: POI
    let style: Style
    var onAddToRoute: (() -> Void)?
    var isAddedToRoute: Bool = false
    var departureDate: Date?
    /// Called the moment the card is tapped, BEFORE the detail sheet opens.
    /// Used by the parent map to recenter on this POI and pulse its pin.
    var onSelect: (() -> Void)?
    @State private var showDetail = false

    enum Style {
        case attraction
        case food
    }

    private var accentColor: Color {
        style == .attraction ? LoooprTheme.Colors.primary : LoooprTheme.Colors.routeDot
    }

    var body: some View {
        Button {
            onSelect?()
            showDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Top row: icon + name + rating
                HStack(alignment: .top, spacing: 10) {
                    // Category icon
                    Image(systemName: poi.category.systemImage)
                        .font(.title3)
                        .foregroundStyle(accentColor)
                        .frame(width: 40, height: 40)
                        .background(accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Name + meta
                    VStack(alignment: .leading, spacing: 3) {
                        Text(poi.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LoooprTheme.Colors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        // Category + distance from route
                        HStack(spacing: 6) {
                            Text(poi.category.displayName)
                                .font(.caption)
                                .foregroundStyle(LoooprTheme.Colors.textSecondary)

                            if let distText = poi.distanceFromRouteFormatted(units: SettingsManager.shared.preferredUnits) {
                                Text(distText)
                                    .font(.caption)
                                    .foregroundStyle(LoooprTheme.Colors.textTertiary)
                            }
                        }
                    }

                    Spacer()

                    // Rating badge
                    if let rating = poi.rating {
                        VStack(spacing: 1) {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(LoooprTheme.Colors.warning)
                                Text(String(format: "%.1f", rating))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(LoooprTheme.Colors.textPrimary)
                            }
                            if let count = poi.reviewCount {
                                Text("(\(count))")
                                    .font(.caption2)
                                    .foregroundStyle(LoooprTheme.Colors.textTertiary)
                            }
                        }
                    }
                }

                // Description (editorial summary or fallback from category)
                Text(poi.displayDescription)
                    .font(.caption)
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
                    .lineLimit(2)
                    .padding(.top, 6)

                // Walking distance along route
                if let walkInfo = poi.walkingInfoFormatted(
                    units: SettingsManager.shared.preferredUnits,
                    pace: SettingsManager.shared.walkingPace
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.caption2)
                            .foregroundStyle(LoooprTheme.Colors.textTertiary)
                        Text(walkInfo)
                            .font(.caption)
                            .foregroundStyle(LoooprTheme.Colors.textTertiary)
                    }
                    .padding(.top, 4)
                }

                // Bottom row: open status + quick actions
                let hasBottomInfo = poi.isOpenNow != nil || poi.openingHours != nil
                    || poi.openingHoursPeriods?.isEmpty == false
                    || poi.websiteURL != nil || poi.phoneNumber != nil
                    || poi.googleMapsUri != nil || poi.appleMapsURL != nil
                if hasBottomInfo {
                    HStack(spacing: 10) {
                        // Open status badge
                        switch poi.openStatus(at: departureDate) {
                        case .open:
                            HStack(spacing: 3) {
                                Circle().fill(.green).frame(width: 6, height: 6)
                                Text(departureDate == nil ? L10n.POI.openNow : L10n.POI.openThen)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.green)
                            }
                        case .openingSoon:
                            HStack(spacing: 3) {
                                Circle().fill(.orange).frame(width: 6, height: 6)
                                Text(L10n.POI.openingSoon)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.orange)
                            }
                        case .closed:
                            HStack(spacing: 3) {
                                Circle().fill(.red).frame(width: 6, height: 6)
                                Text(departureDate == nil ? L10n.POI.closed : L10n.POI.closedThen)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.red)
                            }
                        case .unknown:
                            EmptyView()
                        }

                        // Today's hours
                        if let todayHours = todayHoursString(from: poi.openingHoursWeekdayText, at: departureDate ?? Date()) {
                            Text(todayHours)
                                .font(.caption2)
                                .foregroundStyle(LoooprTheme.Colors.textTertiary)
                                .lineLimit(1)
                        }

                        Spacer()

                        // Quick action icons
                        HStack(spacing: 12) {
                            // Map link: Google Maps for food, Apple Maps for attractions
                            if let mapsURL = poi.googleMapsUri {
                                Link(destination: mapsURL) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "map.fill")
                                            .font(.caption2)
                                        Text(L10n.POI.googleMaps)
                                            .font(.caption2.weight(.medium))
                                    }
                                    .foregroundStyle(LoooprTheme.Colors.primary)
                                }
                            } else if let appleMapsURL = poi.appleMapsURL {
                                Link(destination: appleMapsURL) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "map.fill")
                                            .font(.caption2)
                                        Text(L10n.POI.appleMaps)
                                            .font(.caption2.weight(.medium))
                                    }
                                    .foregroundStyle(LoooprTheme.Colors.primary)
                                }
                            }
                            if poi.websiteURL != nil {
                                Image(systemName: "safari")
                                    .font(.caption)
                                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
                            }
                            if poi.phoneNumber != nil {
                                Image(systemName: "phone")
                                    .font(.caption)
                                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
                            }
                            if let onAddToRoute, style == .food {
                                Button {
                                    onAddToRoute()
                                } label: {
                                    Image(systemName: isAddedToRoute ? "checkmark.circle.fill" : "plus.circle")
                                        .font(.body)
                                        .foregroundStyle(isAddedToRoute ? LoooprTheme.Colors.success : LoooprTheme.Colors.routeDot)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(LoooprTheme.Spacing.sm)
            .background(LoooprTheme.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: LoooprTheme.Radius.card)
                    .strokeBorder(
                        accentColor.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            POIDetailView(poi: poi, departureDate: departureDate)
        }
    }
}
