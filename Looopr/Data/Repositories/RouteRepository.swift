import Foundation
import Supabase

final class RouteRepository: @unchecked Sendable {
    private let store: PersistenceStoring
    private let supabase: SupabaseClientProvider?
    private let recentRoutesKey = "looopr.recentRoutes"
    private let completedRoutesKey = "looopr.completedRoutes"
    private let savedRoutesKey = "looopr.savedRoutes"

    init(store: PersistenceStoring, supabase: SupabaseClientProvider? = nil) {
        self.store = store
        self.supabase = supabase
    }

    // MARK: - Recent Routes

    func saveRecentRoutes(_ routes: [Route]) throws {
        try store.save(routes, forKey: recentRoutesKey)
    }

    func loadRecentRoutes() throws -> [Route] {
        try store.load([Route].self, forKey: recentRoutesKey) ?? []
    }

    // MARK: - Completed Routes

    func markCompleted(_ routeID: UUID) throws {
        var completed = try store.load(Set<UUID>.self, forKey: completedRoutesKey) ?? []
        completed.insert(routeID)
        try store.save(completed, forKey: completedRoutesKey)
    }

    func isCompleted(_ routeID: UUID) -> Bool {
        let completed = try? store.load(Set<UUID>.self, forKey: completedRoutesKey)
        return completed?.contains(routeID) ?? false
    }

    // MARK: - Saved Routes

    func saveRoute(_ route: Route) throws {
        // Gracefully handle corrupted existing data — start fresh rather than blocking the save
        var saved = (try? loadSavedRoutes()) ?? []
        saved.removeAll { $0.id == route.id }
        saved.insert(route, at: 0)
        try store.save(saved, forKey: savedRoutesKey)
    }

    func removeSavedRoute(_ routeID: UUID) throws {
        var saved = (try? loadSavedRoutes()) ?? []
        saved.removeAll { $0.id == routeID }
        try store.save(saved, forKey: savedRoutesKey)
    }

    func loadSavedRoutes() throws -> [Route] {
        try store.load([Route].self, forKey: savedRoutesKey) ?? []
    }

    func isRouteSaved(_ routeID: UUID) -> Bool {
        let saved = try? loadSavedRoutes()
        return saved?.contains { $0.id == routeID } ?? false
    }

    // MARK: - Supabase Sync

    func syncSavedRoutesToCloud(userID: UUID) async throws {
        guard let supabase else { return }
        let localRoutes = try loadSavedRoutes()

        for route in localRoutes {
            let record = SavedRouteRecord(route: route, userID: userID)
            try await supabase.client.from("saved_routes")
                .upsert(record, onConflict: "id")
                .execute()
        }
    }

    func fetchSavedRoutesFromCloud(userID: UUID) async throws -> [Route] {
        guard let supabase else { return [] }
        let records: [SavedRouteRecord] = try await supabase.client.from("saved_routes")
            .select()
            .eq("user_id", value: userID.uuidString)
            .order("saved_at", ascending: false)
            .execute()
            .value
        return records.map(\.toRoute)
    }

    func pushSavedRouteToCloud(_ route: Route, userID: UUID) async throws {
        guard let supabase else { return }
        let record = SavedRouteRecord(route: route, userID: userID)
        try await supabase.client.from("saved_routes")
            .upsert(record, onConflict: "id")
            .execute()
    }

    func deleteSavedRouteFromCloud(_ routeID: UUID) async throws {
        guard let supabase else { return }
        try await supabase.client.from("saved_routes")
            .delete()
            .eq("id", value: routeID.uuidString)
            .execute()
    }
}

// MARK: - Supabase Row Representation

private struct SavedRouteRecord: Codable {
    let id: UUID
    let user_id: UUID
    let name: String
    let description: String
    let duration_minutes: Int
    let distance_km: Double
    let difficulty: String
    let coordinates: [Location]
    let navigation_steps: [NavigationStep]?
    let start_location: Location
    let color_index: Int
    let pois: [POI]
    let generated_at: Date
    let saved_at: Date

    init(route: Route, userID: UUID) {
        self.id = route.id
        self.user_id = userID
        self.name = route.name
        self.description = route.description
        self.duration_minutes = route.durationMinutes
        self.distance_km = route.distanceKilometers
        self.difficulty = route.difficulty.rawValue
        self.coordinates = route.coordinates
        self.navigation_steps = route.navigationSteps
        self.start_location = route.startLocation
        self.color_index = route.colorIndex
        self.pois = route.pois
        self.generated_at = route.generatedAt
        self.saved_at = Date()
    }

    var toRoute: Route {
        Route(
            id: id,
            name: name,
            description: description,
            durationMinutes: duration_minutes,
            distanceKilometers: distance_km,
            difficulty: Route.Difficulty(rawValue: difficulty) ?? .easy,
            pois: pois,
            coordinates: coordinates,
            navigationSteps: navigation_steps,
            generatedAt: generated_at,
            startLocation: start_location,
            colorIndex: color_index
        )
    }
}
