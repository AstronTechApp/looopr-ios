import SwiftUI

// MARK: - Public Category Filter

/// The three POI category filters shared between the list (POIListView) and the
/// map (RouteDetailView). Lifted out so RouteDetailView can dim non-active
/// categories on the map in sync with the user's selection in the list.
enum POICategoryFilter: Hashable {
    case onRoute
    case nearRoute
    case food
}

struct POIListView: View {
    let onRouteAttractions: [POI]
    let nearRouteAttractions: [POI]
    let cafesAndRestaurants: [POI]
    var onAddFoodStop: ((POI) -> Void)?
    var addedFoodStopIDs: Set<UUID> = []
    /// Called when the Food & Drinks tab is tapped to trigger on-demand Google Places fetch.
    var onFoodTabSelected: (() -> Void)?
    /// Whether the food POIs are currently being fetched from Google Places (New).
    var isLoadingFood: Bool = false
    /// Whether the food fetch has completed (even if results are empty).
    var hasFetchedFood: Bool = false
    /// Selected planned departure. `nil` means evaluate against now.
    var departureDate: Date?

    /// Active filter tab — bound to the parent so the map can highlight only
    /// the matching POI category.
    @Binding var selectedTab: POICategoryFilter
    /// POI currently focused via map tap or list tap. When this changes from a
    /// map tap, the list scrolls to bring the matching card into view.
    @Binding var focusedPOIID: UUID?

    @State private var selectedFoodFilter: FoodFilter = .cafes

    // MARK: - Tab Types

    private enum FoodFilter: Hashable {
        case cafes
        case restaurants
    }

    // MARK: - Food Split + Quality Cap

    /// Max food items per sub-tab to keep lists digestible in dense cities.
    private let foodCapPerTab = 15

    /// Cafes & bakeries, sorted by quality (rating × review count), capped.
    /// Excludes closed places — open, opening soon, and unknown status are shown.
    private var cafes: [POI] {
        let filtered = cafesAndRestaurants.filter {
            ($0.category == .cafe || $0.category == .bakery) && isVisibleAtDeparture($0)
        }
        return Array(Self.sortByQuality(filtered).prefix(foodCapPerTab))
    }

    /// Restaurants & bars, sorted by quality (rating × review count), capped.
    /// Excludes closed places — open, opening soon, and unknown status are shown.
    private var restaurants: [POI] {
        let filtered = cafesAndRestaurants.filter {
            ($0.category == .restaurant || $0.category == .bar) && isVisibleAtDeparture($0)
        }
        return Array(Self.sortByQuality(filtered).prefix(foodCapPerTab))
    }

    /// Sort food POIs by quality: rating × log(reviewCount), descending.
    /// This balances high ratings with popularity — a 4.8 with 200 reviews
    /// ranks higher than a 4.9 with 6 reviews.
    private static func sortByQuality(_ pois: [POI]) -> [POI] {
        pois.sorted { a, b in
            let scoreA = (a.rating ?? 0) * log2(max(Double(a.reviewCount ?? 1), 1))
            let scoreB = (b.rating ?? 0) * log2(max(Double(b.reviewCount ?? 1), 1))
            return scoreA > scoreB
        }
    }

    // MARK: - Tab Helpers

    // MARK: - Filtered Attractions (exclude closed)

    /// On-route attractions excluding closed places.
    private var filteredOnRoute: [POI] {
        onRouteAttractions.filter(isVisibleAtDeparture)
    }

    /// Near-route attractions excluding closed places.
    private var filteredNearRoute: [POI] {
        nearRouteAttractions.filter(isVisibleAtDeparture)
    }

    /// Available tabs. Attraction tabs only shown if they have POIs;
    /// Food & Drinks tab is always available (loads on-demand when tapped).
    private var availableTabs: [POICategoryFilter] {
        var tabs: [POICategoryFilter] = []
        if !filteredOnRoute.isEmpty { tabs.append(.onRoute) }
        if !filteredNearRoute.isEmpty { tabs.append(.nearRoute) }
        // Always show Food & Drinks — tapping triggers the Google Places fetch
        tabs.append(.food)
        return tabs
    }

    private func tabLabel(for tab: POICategoryFilter) -> String {
        switch tab {
        case .onRoute: return L10n.POI.onRoute
        case .nearRoute: return L10n.POI.nearRoute
        case .food: return L10n.POI.foodAndDrinks
        }
    }

    /// Badge text for each tab. Food tab shows "10+" as a teaser before data loads.
    private func tabCountLabel(for tab: POICategoryFilter) -> String? {
        switch tab {
        case .onRoute: return "\(filteredOnRoute.count)"
        case .nearRoute: return "\(filteredNearRoute.count)"
        case .food: return hasFetchedFood ? "\(cafes.count + restaurants.count)" : "10+"
        }
    }

    private func tabIcon(for tab: POICategoryFilter) -> String {
        switch tab {
        case .onRoute: return "mappin.circle.fill"
        case .nearRoute: return "arrow.triangle.turn.up.right.circle.fill"
        case .food: return "fork.knife.circle.fill"
        }
    }

    private func poisForTab(_ tab: POICategoryFilter) -> [POI] {
        switch tab {
        case .onRoute: return filteredOnRoute
        case .nearRoute: return filteredNearRoute
        case .food:
            switch selectedFoodFilter {
            case .cafes: return cafes
            case .restaurants: return restaurants
            }
        }
    }

    private func cardStyle(for tab: POICategoryFilter) -> POICardView.Style {
        tab == .food ? .food : .attraction
    }

    // MARK: - Body

    var body: some View {
        let tabs = availableTabs
        // If no tab is selected yet or current selection has no POIs, pick the first available
        let activeTab = tabs.contains(selectedTab) ? selectedTab : (tabs.first ?? .onRoute)

        VStack(spacing: 0) {
            // Primary tab bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tabs, id: \.self) { tab in
                        POITabButton(
                            label: tabLabel(for: tab),
                            countLabel: tabCountLabel(for: tab),
                            icon: tabIcon(for: tab),
                            isSelected: tab == activeTab
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = tab
                            }
                            // Trigger on-demand food fetch when Food tab is tapped
                            if tab == .food {
                                onFoodTabSelected?()
                            }
                        }
                    }
                }
                .padding(.horizontal, LoooprTheme.Spacing.md)
                .padding(.vertical, LoooprTheme.Spacing.sm)
            }

            // Food sub-filter (Cafes / Restaurants) — only after food has been loaded
            if activeTab == .food && hasFetchedFood && !(cafes.isEmpty && restaurants.isEmpty) {
                foodFilterBar
            }

            // Content for selected tab
            if activeTab == .food && isLoadingFood {
                // Loading state while fetching food from Google Places (New)
                HStack(spacing: LoooprTheme.Spacing.xs) {
                    ProgressView().scaleEffect(0.8)
                    Text(L10n.POI.findingNearby)
                        .font(.subheadline)
                        .foregroundStyle(LoooprTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, LoooprTheme.Spacing.lg)
            } else if activeTab == .food && hasFetchedFood && cafes.isEmpty && restaurants.isEmpty {
                // Empty state after food fetch completed
                VStack(spacing: LoooprTheme.Spacing.xs) {
                    Image(systemName: "fork.knife")
                        .font(.title2)
                        .foregroundStyle(LoooprTheme.Colors.textTertiary)
                    Text(L10n.POI.noRestaurantsFound)
                        .font(.subheadline)
                        .foregroundStyle(LoooprTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, LoooprTheme.Spacing.lg)
            } else if activeTab == .food && !hasFetchedFood {
                // Pre-fetch state: prompt to tap the tab
                VStack(spacing: LoooprTheme.Spacing.xs) {
                    Image(systemName: "fork.knife.circle")
                        .font(.title2)
                        .foregroundStyle(LoooprTheme.Colors.routeDot)
                    Text(L10n.POI.tapToFind)
                        .font(.subheadline)
                        .foregroundStyle(LoooprTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, LoooprTheme.Spacing.lg)
                .onAppear {
                    // Also trigger fetch when this view appears (tab was already selected)
                    onFoodTabSelected?()
                }
            } else {
                // Normal content — grouped by shared location
                let pois = poisForTab(activeTab)
                let groups = Self.groupByVicinity(pois)

                ScrollViewReader { proxy in
                    LazyVStack(spacing: LoooprTheme.Spacing.sm) {
                        ForEach(groups) { group in
                            // Show location header only when multiple POIs share the address
                            if group.pois.count > 1, let vicinity = group.vicinity {
                                LocationGroupHeader(address: vicinity)
                            }

                            ForEach(group.pois) { poi in
                                Group {
                                    if activeTab == .food, let onAddFoodStop {
                                        POICardView(
                                            poi: poi,
                                            style: .food,
                                            onAddToRoute: { onAddFoodStop(poi) },
                                            isAddedToRoute: addedFoodStopIDs.contains(poi.id),
                                            departureDate: departureDate,
                                            onSelect: { focusedPOIID = poi.id }
                                        )
                                    } else {
                                        POICardView(
                                            poi: poi,
                                            style: cardStyle(for: activeTab),
                                            departureDate: departureDate,
                                            onSelect: { focusedPOIID = poi.id }
                                        )
                                    }
                                }
                                .id(poi.id)
                            }
                        }
                    }
                    .padding(.horizontal, LoooprTheme.Spacing.md)
                    .padding(.bottom, LoooprTheme.Spacing.lg)
                    .onChange(of: focusedPOIID) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private func isVisibleAtDeparture(_ poi: POI) -> Bool {
        poi.openStatus(at: departureDate) != .closed
    }

    // MARK: - Food Sub-filter Bar

    private var foodFilterBar: some View {
        HStack(spacing: 8) {
            FoodFilterChip(
                label: L10n.POI.cafes,
                icon: "cup.and.saucer.fill",
                count: cafes.count,
                isSelected: selectedFoodFilter == .cafes
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedFoodFilter = .cafes
                }
            }

            FoodFilterChip(
                label: L10n.POI.restaurants,
                icon: "fork.knife",
                count: restaurants.count,
                isSelected: selectedFoodFilter == .restaurants
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedFoodFilter = .restaurants
                }
            }

            Spacer()
        }
        .padding(.horizontal, LoooprTheme.Spacing.md)
        .padding(.bottom, LoooprTheme.Spacing.xs)
    }

    // MARK: - Location Grouping

    /// Groups POIs by their `vicinity` (address) string. POIs with the same
    /// vicinity are grouped together; POIs without a vicinity get their own group.
    static func groupByVicinity(_ pois: [POI]) -> [POILocationGroup] {
        var groups: [POILocationGroup] = []
        var vicinityMap: [String: Int] = [:]  // vicinity → index in groups array

        for poi in pois {
            if let vicinity = poi.vicinity, !vicinity.isEmpty {
                if let idx = vicinityMap[vicinity] {
                    groups[idx].pois.append(poi)
                } else {
                    let idx = groups.count
                    vicinityMap[vicinity] = idx
                    groups.append(POILocationGroup(vicinity: vicinity, pois: [poi]))
                }
            } else {
                // No vicinity — standalone group
                groups.append(POILocationGroup(vicinity: nil, pois: [poi]))
            }
        }

        return groups
    }
}

// MARK: - Location Group Model

struct POILocationGroup: Identifiable {
    let id = UUID()
    let vicinity: String?
    var pois: [POI]
}

// MARK: - Location Group Header

private struct LocationGroupHeader: View {
    let address: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin")
                .font(.caption2)
                .foregroundStyle(LoooprTheme.Colors.textTertiary)
            Text(address)
                .font(.caption)
                .foregroundStyle(LoooprTheme.Colors.textTertiary)
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
}

// MARK: - Primary Tab Button

private struct POITabButton: View {
    let label: String
    let countLabel: String?
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)

                Text(label)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))

                if let countLabel {
                    Text(countLabel)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            isSelected
                                ? Color.white.opacity(0.3)
                                : LoooprTheme.Colors.border
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, LoooprTheme.Spacing.sm)
            .padding(.vertical, LoooprTheme.Spacing.xs)
            .background(isSelected ? LoooprTheme.Colors.primary : Color.clear)
            .foregroundStyle(isSelected ? LoooprTheme.Colors.textOnPrimary : LoooprTheme.Colors.textSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : LoooprTheme.Colors.borderStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Food Filter Chip

private struct FoodFilterChip: View {
    let label: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)

                Text(label)
                    .font(.caption.weight(isSelected ? .semibold : .regular))

                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        isSelected
                            ? LoooprTheme.Colors.routeDot.opacity(0.3)
                            : LoooprTheme.Colors.border
                    )
                    .clipShape(Capsule())
            }
            .padding(.horizontal, LoooprTheme.Spacing.xs)
            .padding(.vertical, 5)
            .background(isSelected ? LoooprTheme.Colors.routeDot.opacity(0.12) : Color.clear)
            .foregroundStyle(isSelected ? LoooprTheme.Colors.routeDot : LoooprTheme.Colors.textTertiary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? LoooprTheme.Colors.routeDot.opacity(0.3) : LoooprTheme.Colors.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
