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

    /// The result currently being turned into a coordinate. Drives a spinner
    /// on its row and disables the others, so a tap is never silent.
    @State private var resolvingCompletion: MKLocalSearchCompletion?
    @State private var showResolveError = false

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
                                    Group {
                                        if resolvingCompletion == completion {
                                            ProgressView()
                                                .tint(LoooprTheme.Colors.primary)
                                        } else {
                                            Image(systemName: "mappin")
                                                .font(.system(size: 14))
                                                .foregroundStyle(LoooprTheme.Colors.routeDot)
                                        }
                                    }
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
                            // Borderless, not plain: in a List this makes the
                            // whole row the hit target *and* highlights it on
                            // press, so the user sees the tap land.
                            .buttonStyle(.borderless)
                            .disabled(resolvingCompletion != nil)
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
            .navigationTitle(L10n.LocationSearch.searchLocation)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.LocationSearch.cancel) { dismiss() }
                        .foregroundStyle(LoooprTheme.Colors.primary)
                }
            }
            .toolbarBackground(LoooprTheme.Colors.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert(L10n.LocationSearch.resolveFailedTitle, isPresented: $showResolveError) {
                Button(L10n.Misc.okay, role: .cancel) {}
            } message: {
                Text(L10n.LocationSearch.resolveFailedMessage)
            }
        }
        .preferredColorScheme(.light)
    }

    private func resolveCompletion(_ completion: MKLocalSearchCompletion) {
        guard resolvingCompletion == nil else { return }
        resolvingCompletion = completion

        Task { @MainActor in
            let item = await resolve(completion)
            resolvingCompletion = nil

            guard let item else {
                showResolveError = true
                return
            }
            applyResolved(item: item, completion: completion)
        }
    }

    /// Turns a completion into a map item. Tries the completion directly first;
    /// generic completions (a bare city name) sometimes come back empty that
    /// way, so it retries as a free-text query built from title and subtitle.
    /// Returns nil only when both fail, and says so in the log.
    private func resolve(_ completion: MKLocalSearchCompletion) async -> MKMapItem? {
        let logger = AppLogger(category: "LocationSearch")

        do {
            let response = try await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start()
            if let item = response.mapItems.first { return item }
            logger.info("Completion '\(completion.title)' resolved to no map items; retrying as text")
        } catch {
            logger.info("Completion '\(completion.title)' failed directly: \(error.localizedDescription); retrying as text")
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = completion.subtitle.isEmpty
            ? completion.title
            : "\(completion.title), \(completion.subtitle)"

        do {
            let response = try await MKLocalSearch(request: request).start()
            if let item = response.mapItems.first { return item }
            logger.warning("Could not resolve '\(completion.title)': no map items from either path")
        } catch {
            logger.warning("Could not resolve '\(completion.title)': \(error.localizedDescription)")
        }
        return nil
    }

    /// Hands a resolved map item back to the caller and closes the sheet.
    private func applyResolved(item: MKMapItem, completion: MKLocalSearchCompletion) {
        let displayName = item.name ?? completion.title
        let coordinate = item.placemark.coordinate

        RecentLocationStore.save(RecentLocation(
            displayName: displayName,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        ))
        onSelectLocation(SelectedLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            displayName: displayName
        ))
        dismiss()
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
        // Empty results are the right UI, but the reason belongs in the log.
        AppLogger(category: "LocationSearch").warning("Completer failed: \(error.localizedDescription)")
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
