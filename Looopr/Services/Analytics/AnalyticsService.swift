import Foundation
import Supabase
import os

/// Sends analytics events to the `analytics_events` table in Supabase so
/// usage (app opens, route searches, walks, bookings…) is visible in the
/// dashboard/SQL editor. Fire-and-forget: failures are logged, never surfaced.
///
/// Every event carries a random per-install `install_id` (see `InstallID`).
/// Signed-in users also send their `user_id`; guests ("Continue without an
/// account") send only the install ID, which RLS allows for the anon role
/// for known event names only. That keeps guests visible in the numbers and
/// lets a guest who later signs up be followed across the sign-up.
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
        let installID = InstallID.current
        Task.detached(priority: .utility) { [logger] in
            do {
                // nil for guests: the row is then inserted with the anon key.
                let userID = (try? await supabase.client.auth.session)?.user.id

                struct EventRow: Encodable {
                    let user_id: UUID?
                    let install_id: UUID
                    let event: String
                    let properties: [String: AnalyticsValue]

                    // Omit user_id for guests instead of sending null, so the
                    // row matches the guest RLS policy exactly.
                    func encode(to encoder: Encoder) throws {
                        var c = encoder.container(keyedBy: CodingKeys.self)
                        try c.encodeIfPresent(user_id, forKey: .user_id)
                        try c.encode(install_id, forKey: .install_id)
                        try c.encode(event, forKey: .event)
                        try c.encode(properties, forKey: .properties)
                    }
                    enum CodingKeys: String, CodingKey {
                        case user_id, install_id, event, properties
                    }
                }

                try await supabase.client
                    .from("analytics_events")
                    .insert(EventRow(
                        user_id: userID,
                        install_id: installID,
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

/// A random identifier for this installation of Looopr, created on first use
/// and kept in UserDefaults. It is not derived from any device, Apple or
/// advertising identifier, is never shared with other apps, and resets when
/// the app is deleted — so it counts installs without identifying a person.
enum InstallID {
    private static let key = "analytics.installID"

    /// `static let` is initialised once, thread-safely, on first access.
    static let current: UUID = {
        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: key), let id = UUID(uuidString: stored) {
            return id
        }
        let id = UUID()
        defaults.set(id.uuidString, forKey: key)
        return id
    }()
}
