import Foundation
import Supabase

enum SupabaseConfigurationError: Error, LocalizedError {
    case missingCredentials

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Supabase is not configured. Please verify that SUPABASE_URL and SUPABASE_ANON_KEY are set in Secrets.xcconfig."
        }
    }
}

final class SupabaseClientProvider: @unchecked Sendable {
    let client: SupabaseClient

    /// Failable initializer — returns nil when Supabase credentials are missing
    /// instead of crashing the app.
    init?() {
        guard !Secrets.supabaseURL.isEmpty,
              !Secrets.supabaseAnonKey.isEmpty,
              let url = URL(string: Secrets.supabaseURL) else {
            AppLogger(category: "Supabase").error("Missing SUPABASE_URL or SUPABASE_ANON_KEY in Secrets.xcconfig — Supabase features will be unavailable.")
            return nil
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: Secrets.supabaseAnonKey
        )
    }
}
