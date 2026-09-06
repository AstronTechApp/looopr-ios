import Foundation
import Supabase

/// What the user typed in the feedback sheet. Everything else that lands in
/// the row (app version, OS, device, locale, premium state) is attached by
/// the service so a report is actionable without a follow-up email.
struct FeedbackSubmission: Sendable {
    let message: String
    let replyEmail: String?
}

protocol FeedbackSending: Sendable {
    func send(_ submission: FeedbackSubmission) async throws
}

enum FeedbackError: Error {
    /// RLS requires an authenticated user; there is no session to attribute
    /// the row to.
    case notSignedIn
}

/// Writes feedback to the `feedback` table in Supabase. The table is
/// insert-only for the app (no select policy), so nothing written here can
/// ever be read back by another user — it's a one-way letterbox that is
/// read in the dashboard.
final class LiveFeedbackService: FeedbackSending, @unchecked Sendable {
    private let supabase: SupabaseClientProvider
    private let subscription: SubscriptionProviding?
    private let logger = AppLogger(category: "Feedback")

    init(supabase: SupabaseClientProvider, subscription: SubscriptionProviding?) {
        self.supabase = supabase
        self.subscription = subscription
    }

    func send(_ submission: FeedbackSubmission) async throws {
        guard let session = try? await supabase.client.auth.session else {
            throw FeedbackError.notSignedIn
        }

        struct Row: Encodable {
            let user_id: UUID
            let message: String
            let reply_email: String?
            let app_version: String?
            let build: String?
            let os_version: String
            let device_model: String
            let locale: String
            let is_premium: Bool?
        }

        let info = Bundle.main.infoDictionary
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let row = Row(
            user_id: session.user.id,
            message: submission.message,
            reply_email: submission.replyEmail,
            app_version: info?["CFBundleShortVersionString"] as? String,
            build: info?["CFBundleVersion"] as? String,
            os_version: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            device_model: Self.deviceModel,
            locale: "app=\(LocalizationManager.currentLanguageCode) device=\(Locale.current.identifier)",
            is_premium: subscription?.isPaidSubscriber
        )

        do {
            try await supabase.client
                .from("feedback")
                .insert(row)
                .execute()
            logger.info("Feedback sent (\(submission.message.count) chars)")
        } catch {
            logger.error("Failed to send feedback: \(String(describing: error))")
            throw error
        }
    }

    /// Hardware identifier such as `iPhone17,1` — more useful than
    /// `UIDevice.model`, which only says "iPhone".
    private static var deviceModel: String {
        #if targetEnvironment(simulator)
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated + " (simulator)"
        }
        #endif
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }
}
