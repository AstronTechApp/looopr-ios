import CoreLocation

actor TerrainCalibrationCache {
    private let store: SettingsRepository
    private var factors: [String: Double]
    private let maxEntries: Int

    init(store: SettingsRepository, maxEntries: Int = 20) {
        self.store = store
        self.maxEntries = maxEntries
        self.factors = store.loadTerrainFactors()
    }

    func factor(for coordinate: CLLocationCoordinate2D) -> Double? {
        factors[gridKey(for: coordinate)]
    }

    func update(for coordinate: CLLocationCoordinate2D, factor: Double) {
        let key = gridKey(for: coordinate)
        let existing = factors[key] ?? 1.0
        factors[key] = existing * 0.7 + factor * 0.3

        if factors.count > maxEntries {
            let sorted = factors.sorted { $0.key < $1.key }
            factors = Dictionary(uniqueKeysWithValues: Array(sorted.suffix(maxEntries)))
        }

        try? store.saveTerrainFactors(factors)
    }

    private func gridKey(for coordinate: CLLocationCoordinate2D) -> String {
        let latGrid = Int(coordinate.latitude * 10)
        let lonGrid = Int(coordinate.longitude * 10)
        return "\(latGrid),\(lonGrid)"
    }
}
