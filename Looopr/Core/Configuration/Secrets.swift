import Foundation

enum Secrets {
    static var googlePlacesAPIKey: String {
        Bundle.main.infoDictionary?["GOOGLE_PLACES_API_KEY"] as? String ?? ""
    }

    static var hasGooglePlacesKey: Bool {
        !googlePlacesAPIKey.isEmpty
    }

    static var supabaseURL: String {
        Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
    }

    static var supabaseAnonKey: String {
        Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
    }

    static var mapboxAccessToken: String {
        Bundle.main.infoDictionary?["MAPBOX_ACCESS_TOKEN"] as? String ?? ""
    }

    static var hasMapboxToken: Bool {
        !mapboxAccessToken.isEmpty
    }

    // MARK: - Subscriptions

    /// RevenueCat *public* SDK key (safe to ship in the binary).
    ///
    /// A Test Store key (`test_...`) routes purchases to RevenueCat's
    /// simulated store — perfect for development, catastrophic in a
    /// TestFlight/App Store build (nobody would ever be charged, and Apple
    /// review would fail). Outside DEBUG such a key is treated as absent so
    /// the app falls back to the permissive stub instead.
    static var revenueCatAPIKey: String {
        let key = Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as? String ?? ""
        #if DEBUG
        return key
        #else
        return key.hasPrefix("test_") ? "" : key
        #endif
    }

    static var hasRevenueCatKey: Bool { !revenueCatAPIKey.isEmpty }

    // MARK: - Crash reporting

    /// Sentry DSN (public; safe to ship). Empty = crash reporting off.
    static var sentryDSN: String {
        Bundle.main.infoDictionary?["SENTRY_DSN"] as? String ?? ""
    }

    static var hasSentryDSN: Bool { !sentryDSN.isEmpty }

    // MARK: - Ticket Providers

    static var viatorAPIKey: String {
        Bundle.main.infoDictionary?["VIATOR_API_KEY"] as? String ?? ""
    }

    static var hasViatorKey: Bool { !viatorAPIKey.isEmpty }

    static var getYourGuideAPIKey: String {
        Bundle.main.infoDictionary?["GETYOURGUIDE_API_KEY"] as? String ?? ""
    }

    static var hasGetYourGuideKey: Bool { !getYourGuideAPIKey.isEmpty }

    static var tiqetsAPIKey: String {
        Bundle.main.infoDictionary?["TIQETS_API_KEY"] as? String ?? ""
    }

    static var hasTiqetsKey: Bool { !tiqetsAPIKey.isEmpty }

    static var musementAPIKey: String {
        Bundle.main.infoDictionary?["MUSEMENT_API_KEY"] as? String ?? ""
    }

    static var hasMusementKey: Bool { !musementAPIKey.isEmpty }

    static var klookAPIKey: String {
        Bundle.main.infoDictionary?["KLOOK_API_KEY"] as? String ?? ""
    }

    static var hasKlookKey: Bool { !klookAPIKey.isEmpty }
}
