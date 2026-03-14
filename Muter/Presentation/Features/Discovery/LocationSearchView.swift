import SwiftUI
import MapKit

struct LocationSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var results: [MKLocalSearchCompletion] = []
    @State private var completer = SearchCompleter()

    let onSelect: (SearchedLocation) -> Void

    var body: some View {
        NavigationStack {
            List {
                if results.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(results, id: \.self) { completion in
                        Button {
                            selectCompletion(completion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(completion.title)
                                    .font(AppTheme.bodyFont)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(AppTheme.captionFont)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search for a city or address")
            .onChange(of: searchText) { _, newValue in
                completer.search(query: newValue)
            }
            .onChange(of: completer.results) { _, newResults in
                results = newResults
            }
            .navigationTitle("Plan Ahead")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        Task {
            let request = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: request)
            if let response = try? await search.start(),
               let item = response.mapItems.first {
                let location = SearchedLocation(
                    name: completion.title,
                    coordinate: item.placemark.coordinate
                )
                onSelect(location)
                dismiss()
            }
        }
    }
}

// MARK: - Search Completer

@Observable
final class SearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest, .query]
    }

    func search(query: String) {
        guard !query.isEmpty else {
            results = []
            return
        }
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}
