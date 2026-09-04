import Foundation
import Supabase

final class WalkHistoryRepository: @unchecked Sendable {
    private let store: PersistenceStoring
    private let supabase: SupabaseClientProvider?
    private let historyKey = "looopr.walkHistory"
    private let logger = AppLogger(category: "WalkHistory")
    /// Serialises `lastFullSync` access (sync can be triggered from any actor).
    private let syncLock = NSLock()
    private var lastFullSync: Date = .distantPast
    private let fullSyncInterval: TimeInterval = 10 * 60

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

    /// Deletes one walk locally *and* in the cloud.
    ///
    /// A local-only delete is not enough: `syncWithCloudIfNeeded()` pulls any
    /// cloud walk that is missing locally back into history, so a walk removed
    /// on this device would reappear at the next sync. Removing the row first
    /// means the delete sticks across devices.
    ///
    /// The local delete happens even if the cloud delete fails, so the walk
    /// always disappears from the UI; the throw lets the caller surface a
    /// warning that other devices may still hold a copy.
    func deleteEverywhere(id: UUID) async throws {
        try delete(id: id)
        try await deleteFromCloudIfSignedIn(id: id)
    }

    /// Removes the walk's cloud row when a user is signed in. No-op when
    /// signed out (nothing was ever pushed) or when Supabase is unavailable.
    func deleteFromCloudIfSignedIn(id: UUID) async throws {
        guard let supabase else { return }
        guard let userID = try? await supabase.client.auth.session.user.id else { return }

        do {
            try await supabase.client.from("walk_sessions")
                .delete()
                .eq("id", value: id.uuidString)
                .eq("user_id", value: userID.uuidString)
                .execute()
            logger.info("Walk \(id) deleted from cloud")
        } catch {
            logger.error("Cloud delete failed for walk \(id): \(error)")
            throw error
        }
    }

    // MARK: - Supabase Sync

    /// Uploads one finished session, if a user is signed in. Fire-and-forget:
    /// called right after a walk is saved locally so history reaches the
    /// cloud without waiting for the next full sync.
    func pushToCloudIfSignedIn(_ session: WalkSession) async {
        guard session.isComplete, let supabase else { return }
        guard let userID = try? await supabase.client.auth.session.user.id else { return }
        do {
            try await pushToCloud(session, userID: userID)
            logger.info("Walk \(session.id) pushed to cloud")
        } catch {
            logger.error("Cloud push failed for walk \(session.id): \(error)")
        }
    }

    /// Two-way sync: local completed walks are upserted to the cloud (local
    /// wins on conflicts — it carries the freshest feedback), and cloud walks
    /// missing locally (other device, reinstall) are saved into local
    /// history. Throttled so frequent profile visits don't hammer the
    /// network. Returns `true` when local history changed.
    func syncWithCloudIfNeeded() async -> Bool {
        guard let supabase else { return false }

        syncLock.lock()
        let due = Date().timeIntervalSince(lastFullSync) >= fullSyncInterval
        if due { lastFullSync = Date() }
        syncLock.unlock()
        guard due else { return false }

        guard let userID = try? await supabase.client.auth.session.user.id else { return false }

        var localChanged = false
        do {
            let local = try loadAll()
            let cloud = try await fetchFromCloud(userID: userID)
            let localIDs = Set(local.map(\.id))

            for session in cloud where !localIDs.contains(session.id) {
                try save(session)
                localChanged = true
            }
            for session in local where session.isComplete {
                try await pushToCloud(session, userID: userID)
            }
            logger.info("Walk history synced: \(local.count) local, \(cloud.count) cloud, pulled \(localChanged ? "new" : "none")")
        } catch {
            logger.error("Walk history sync failed: \(error)")
            // Allow a retry before the full interval elapses.
            syncLock.lock(); lastFullSync = .distantPast; syncLock.unlock()
        }
        return localChanged
    }

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
    let planned_duration_minutes: Int?
    let planned_distance_meters: Double?
    let track_points: [TrackPoint]?

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
        self.planned_duration_minutes = session.plannedDurationMinutes
        self.planned_distance_meters = session.plannedDistanceMeters
        self.track_points = session.trackPoints
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
            routeCoordinates: route_coordinates,
            plannedDurationMinutes: planned_duration_minutes,
            plannedDistanceMeters: planned_distance_meters,
            trackPoints: track_points
        )
    }
}
