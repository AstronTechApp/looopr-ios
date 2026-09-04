import Foundation
import Supabase
import os

/// Sends analytics events to the `analytics_events` table in Supabase so
/// usage (app opens, route searches, walks, bookings…) is visible in the
/// dashboard/SQL editor. Fire-and-forget: failures are logged, never surfaced,
/// and events are dropped when the user is not signed in (RLS requires an
/// authenticated user and beta testers sign in on first launch anyway).
final class LiveAnalyticsService: AnalyticsTracking, @unchecked Sendable {
    private let logger = Logger(subsystem: "nl.astrontech.looopr", category: "Analytics")
    private let supabase: SupabaseClientProvider?

    init(supabase: SupabaseClientProvider? = nil) {
        self.supabase = supabase
    }

    func track(_ event: AnalyticsEvent) {
        logger.info("Event: \(event.name, privacy: .public)")
        guard let supabase else { return }

        let name = event.name
        let properties = event.properties
        Task.detached(priority: .utility) { [logger] in
            do {
                guard let session = try? await supabase.client.auth.session else { return }

                struct EventRow: Encodable {
                    let user_id: UUID
                    let event: String
                    let properties: [String: AnalyticsValue]
                }

                try await supabase.client
                    .from("analytics_events")
                    .insert(EventRow(
                        user_id: session.user.id,
                        event: name,
                        properties: properties
                    ))
                    .execute()
            } catch {
                logger.error("Failed to send \(name, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }
}
