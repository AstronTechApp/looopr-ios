import Foundation

final class SettingsRepository: @unchecked Sendable {
    private let store: PersistenceStoring
    private let terrainKey = "looopr.terrainFactors"

    init(store: PersistenceStoring) {
        self.store = store
    }

    func saveTerrainFactors(_ factors: [String: Double]) throws {
        try store.save(factors, forKey: terrainKey)
    }

    func loadTerrainFactors() -> [String: Double] {
        (try? store.load([String: Double].self, forKey: terrainKey)) ?? [:]
    }
}
