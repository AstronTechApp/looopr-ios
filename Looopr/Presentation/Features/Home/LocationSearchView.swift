import MapKit
import SwiftUI

// MARK: - Location Search View

struct LocationSearchView: View {
    @Environment(\.dismiss) private var dismiss

    var onSelectLocation: (SelectedLocation) -> Void
    var onSelectCurrentLocation: () -> Void

    @State private var searchText = ""
    @State private var completer = SearchCompleterCoordinator()
    @State private var recentLocations = RecentLocationStore.load()

    var body: some View {
        NavigationStack {
            List {
                // Current Location row
                Section {
                    Button {
                        onSelectCurrentLocation()
                        dismiss()
                    } label: {
                        HStack(spacing: LoooprTheme.Spacing.sm) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(LoooprTheme.Colors.primary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.LocationSearch.useCurrentLocation)
                                    .font(LoooprTheme.Typography.headline)
                                    .foregroundStyle(LoooprTheme.Colors.textPrimary)

                                Text(L10n.LocationSearch.routesNearYou)
                                    .font(LoooprTheme.Typography.caption)
                                    .foregroundStyle(LoooprTheme.Colors.textTertiary)
                            }

                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                // Recent locations
                if searchText.isEmpty, !recentLocations.isEmpty {
                    Section {
                        ForEach(recentLocations) { recent in
                            Button {
                                let selected = SelectedLocation(
                                    latitude: recent.latitude,
                                    longitude: recent.longitude,
                                    displayName: recent.displayName
                                )
                                onSelectLocation(selected)
                                RecentLocationStore.save(recent)
                                dismiss()
                            } label: {
                                HStack(spacing: LoooprTheme.Spacing.sm) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 14))
                                        .foregroundStyle(LoooprTheme.Colors.textTertiary)
                                        .frame(width: 28)

                                    Text(recent.displayName)
                                        .font(LoooprTheme.Typography.body)
                                        .foregroundStyle(LoooprTheme.Colors.textPrimary)
                                        .lineLimit(1)

                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text(L10n.LocationSearch.recent)
                    }
                }

                // Search results
                if !completer.results.isEmpty {
                    Section {
                        ForEach(completer.results, id: \.self) { completion in
                            Button {
                                resolveCompletion(completion)
                            } label: {
                                HStack(spacing: LoooprTheme.Spacing.sm) {
                                    Image(systemName: "mappin")
                                        .font(.system(size: 14))
                                        .foregroundStyle(LoooprTheme.Colors.routeDot)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(completion.title)
                                            .font(LoooprTheme.Typography.body)
                                            .foregroundStyle(LoooprTheme.Colors.textPrimary)
                                            .lineLimit(1)

                                        if !completion.subtitle.isEmpty {
                                            Text(completion.subtitle)
                                                .font(LoooprTheme.Typography.caption)
                                                .foregroundStyle(LoooprTheme.Colors.textTertiary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text(L10n.LocationSearch.results)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.visible)
            .background(LoooprTheme.Colors.background)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search city, address, or place")
            .onChange(of: searchText) { _, newValue in
                if newValue.isEmpty {
                    completer.results = []
                } else {
                    completer.search(query: newValue)
                }
            }
            .navigationTitle("Search Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.LocationSearch.cancel) { dismiss() }
                        .foregroundStyle(LoooprTheme.Colors.primary)
                }
            }
            .toolbarBackground(LoooprTheme.Colors.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.light)
    }

    private func resolveCompletion(_ completion: MKLocalSearchCompletion) {
        // Primary path: resolve via the MKLocalSearchCompletion directly.
        let primaryRequest = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: primaryRequest).start { response, _ in
            if let item = response?.mapItems.first {
                applyResolved(item: item, completion: completion)
                return
            }

            // Fallback: some generic completions (e.g. just a city name) don't
            // resolve to a mapItem when used directly. Retry with a free-text
            // naturalLanguageQuery built from title + subtitle so the user's
            // tap is never silently swallowed.
            let fallbackQuery = completion.subtitle.isEmpty
                ? completion.title
                : "\(completion.title), \(completion.subtitle)"
            let fallbackRequest = MKLocalSearch.Request()
            fallbackRequest.naturalLanguageQuery = fallbackQuery
            MKLocalSearch(request: fallbackRequest).start { fallback, error in
                if let item = fallback?.mapItems.first {
                    applyResolved(item: item, completion: completion)
                } else {
                    AppLogger(category: "LocationSearch")
                        .warning("Could not resolve completion '\(completion.title)': \(error?.localizedDescription ?? "no mapItems")")
                }
            }
        }
    }

    /// Propagates a resolved map item back to the caller on the main queue.
    private func applyResolved(item: MKMapItem, completion: MKLocalSearchCompletion) {
        let displayName = item.name ?? completion.title
        let selected = SelectedLocation(
            latitude: item.placemark.coordinate.latitude,
            longitude: item.placemark.coordinate.longitude,
            displayName: displayName
        )
        DispatchQueue.main.async {
            RecentLocationStore.save(RecentLocation(
                displayName: displayName,
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude
            ))
            onSelectLocation(selected)
            dismiss()
        }
    }
}

// MARK: - Search Completer Coordinator

@Observable
final class SearchCompleterCoordinator: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func search(query: String) {
        completer.queryFragment = query
    }

    // MARK: - MKLocalSearchCompleterDelegate

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Silently fail — empty results shown
    }
}

// MARK: - Selected Location

struct SelectedLocation: Equatable {
    let latitude: Double
    let longitude: Double
    let displayName: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Recent Location Persistence

struct RecentLocation: Codable, Identifiable {
    var id: String { displayName }
    let displayName: String
    let latitude: Double
    let longitude: Double
}

enum RecentLocationStore {
    private static let key = "looopr.recentLocations"
    private static let maxRecents = 3

    static func load() -> [RecentLocation] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([RecentLocation].self, from: data)) ?? []
    }

    static func save(_ location: RecentLocation) {
        var recents = load()
        recents.removeAll { $0.displayName == location.displayName }
        recents.insert(location, at: 0)
        if recents.count > maxRecents { recents = Array(recents.prefix(maxRecents)) }
        if let data = try? JSONEncoder().encode(recents) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
