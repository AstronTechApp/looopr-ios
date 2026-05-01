import Foundation
import Supabase

final class WalkHistoryRepository: @unchecked Sendable {
    private let store: PersistenceStoring
    private let supabase: SupabaseClientProvider?
    private let historyKey = "looopr.walkHistory"

    init(store: PersistenceStoring, supabase: SupabaseClientProvider? = nil) {
        self.store = store
        self.supabase = supabase
    }

    func save(_ session: WalkSession) throws {
        var history = try loadAll()
        if let index = history.firstIndex(where: { $0.id == session.id }) {
            history[index] = session
        } else {
            history.append(session)
        }
        try store.save(history, forKey: historyKey)
    }

    func loadAll() throws -> [WalkSession] {
        try store.load([WalkSession].self, forKey: historyKey) ?? []
    }

    func delete(id: UUID) throws {
        var history = try loadAll()
        history.removeAll { $0.id == id }
        try store.save(history, forKey: historyKey)
    }

    // MARK: - Supabase Sync

    func syncToCloud(userID: UUID) async throws {
        guard let supabase else { return }
        let sessions = try loadAll()

        for session in sessions where session.isComplete {
            let record = WalkSessionRecord(session: session, userID: userID)
            try await supabase.client.from("walk_sessions")
                .upsert(record, onConflict: "id")
                .execute()
        }
    }

    func fetchFromCloud(userID: UUID) async throws -> [WalkSession] {
        guard let supabase else { return [] }
        let records: [WalkSessionRecord] = try await supabase.client.from("walk_sessions")
            .select()
            .eq("user_id", value: userID.uuidString)
            .order("started_at", ascending: false)
            .execute()
            .value
        return records.map(\.toSession)
    }

    func pushToCloud(_ session: WalkSession, userID: UUID) async throws {
        guard let supabase else { return }
        let record = WalkSessionRecord(session: session, userID: userID)
        try await supabase.client.from("walk_sessions")
            .upsert(record, onConflict: "id")
            .execute()
    }
}

// MARK: - Supabase Row Representation

private struct WalkSessionRecord: Codable {
    let id: UUID
    let user_id: UUID
    let route_id: UUID
    let route_name: String?
    let started_at: Date
    let finished_at: Date?
    let distance_meters: Double
    let duration_seconds: Double
    let step_count: Int
    let elevation_gain_meters: Double?
    let visited_food_stops: [FoodStopVisit]
    let feedback: WalkFeedback?
    let route_color_index: Int?
    let route_coordinates: [Location]?

    init(session: WalkSession, userID: UUID) {
        self.id = session.id
        self.user_id = userID
        self.route_id = session.routeId
        self.route_name = session.routeName
        self.started_at = session.startedAt
        self.finished_at = session.finishedAt
        self.distance_meters = session.distanceWalkedMeters
        self.duration_seconds = session.durationSeconds
        self.step_count = session.stepCount
        self.elevation_gain_meters = session.elevationGainMeters
        self.visited_food_stops = session.visitedFoodStops
        self.feedback = session.feedback
        self.route_color_index = session.routeColorIndex
        self.route_coordinates = session.routeCoordinates
    }

    var toSession: WalkSession {
        WalkSession(
            id: id,
            routeId: route_id,
            startedAt: started_at,
            finishedAt: finished_at,
            distanceWalkedMeters: distance_meters,
            durationSeconds: duration_seconds,
            stepCount: step_count,
            visitedFoodStops: visited_food_stops,
            feedback: feedback,
            routeName: route_name,
            elevationGainMeters: elevation_gain_meters,
            routeColorIndex: route_color_index,
            routeCoordinates: route_coordinates
        )
    }
}
