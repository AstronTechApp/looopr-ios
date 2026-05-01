import Foundation
import Supabase

actor RouteShareService {
    private let supabase: SupabaseClientProvider
    private let logger = AppLogger(category: "RouteShare")

    init(supabase: SupabaseClientProvider = ServiceContainer.shared.resolve(SupabaseClientProvider.self)) {
        self.supabase = supabase
    }

    /// Uploads a route to Supabase and returns a shareable URL.
    func uploadRoute(_ route: Route) async throws -> URL {
        let shareID = route.id

        // Encode route to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let routeJSON = try encoder.encode(route)

        // Refresh the session to ensure the access token is valid.
        // Without this, a stale token (e.g. app backgrounded for hours)
        // causes a 401 that surfaces as "Failed to upload route".
        let session: Session
        do {
            session = try await supabase.client.auth.refreshSession()
        } catch {
            // Refresh failed — fall back to the current session, which may
            // still be valid if the token hasn't expired yet.
            logger.warning("Session refresh failed, using current session: \(error.localizedDescription)")
            session = try await supabase.client.auth.session
        }
        let userID = session.user.id
        let accessToken = session.accessToken

        // Build Supabase REST API request.
        // `on_conflict=id` tells PostgREST which column to use for upsert
        // conflict detection — without it, re-sharing the same route returns
        // a 409 Conflict even with resolution=merge-duplicates.
        guard let url = URL(string: "\(Secrets.supabaseURL)/rest/v1/shared_routes?on_conflict=id") else {
            throw ShareError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal, resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        // Build payload matching the shared_routes table schema:
        // columns: id (uuid), user_id (uuid), route_data (jsonb), created_at (timestamptz default now())
        let payload: [String: Any] = [
            "id": shareID.uuidString,
            "user_id": userID.uuidString,
            "route_data": try JSONSerialization.jsonObject(with: routeJSON)
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            logger.error("Upload failed with status \(statusCode): \(body)")
            throw ShareError.uploadFailed
        }

        logger.info("Route shared: \(shareID)")

        guard let shareURL = URL(string: "https://looopr.app/route/\(shareID.uuidString)") else {
            throw ShareError.invalidConfiguration
        }

        return shareURL
    }

    /// Fetches a shared route from Supabase by ID.
    func fetchSharedRoute(id: UUID) async throws -> Route {
        guard let url = URL(string: "\(Secrets.supabaseURL)/rest/v1/shared_routes?id=eq.\(id.uuidString)&select=route_data") else {
            throw ShareError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        // Reads are allowed by anon — RLS policy: "Anyone can view shared routes" (true)
        request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ShareError.routeNotFound
        }

        // Supabase returns an array: [{ "route_data": { ... } }]
        guard let results = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = results.first,
              let routeJSON = first["route_data"] else {
            throw ShareError.routeNotFound
        }

        let routeData = try JSONSerialization.data(withJSONObject: routeJSON)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Route.self, from: routeData)
    }

    enum ShareError: LocalizedError {
        case invalidConfiguration
        case uploadFailed
        case routeNotFound

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration: "Sharing is not configured."
            case .uploadFailed: "Failed to upload route. Please try again."
            case .routeNotFound: "This route is no longer available."
            }
        }
    }
}
