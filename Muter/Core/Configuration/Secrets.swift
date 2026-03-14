import Foundation

enum Secrets {
    static var googlePlacesAPIKey: String {
        guard let key = Bundle.main.infoDictionary?["GOOGLE_PLACES_API_KEY"] as? String,
              !key.isEmpty else {
            fatalError("GOOGLE_PLACES_API_KEY not set in build configuration")
        }
        return key
    }

    static var supabaseURL: String {
        Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
    }

    static var supabaseAnonKey: String {
        Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
    }
}
