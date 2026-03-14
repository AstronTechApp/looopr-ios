import Foundation

final class RouteRepository: @unchecked Sendable {
    private let store: PersistenceStoring
    private let recentRoutesKey = "muter.recentRoutes"
    private let completedRoutesKey = "muter.completedRoutes"

    init(store: PersistenceStoring) {
        self.store = store
    }

    func saveRecentRoutes(_ routes: [Route]) throws {
        try store.save(routes, forKey: recentRoutesKey)
    }

    func loadRecentRoutes() throws -> [Route] {
        try store.load([Route].self, forKey: recentRoutesKey) ?? []
    }

    func markCompleted(_ routeID: UUID) throws {
        var completed = try store.load(Set<UUID>.self, forKey: completedRoutesKey) ?? []
        completed.insert(routeID)
        try store.save(completed, forKey: completedRoutesKey)
    }

    func isCompleted(_ routeID: UUID) -> Bool {
        let completed = try? store.load(Set<UUID>.self, forKey: completedRoutesKey)
        return completed?.contains(routeID) ?? false
    }
}
