import Foundation
import Sentry

/// Thin façade over the Sentry SDK so the rest of the app never imports
/// `Sentry` directly. Every call is a no-op until `start()` has run with a
/// DSN, which only happens when `SENTRY_DSN` is set in Secrets.xcconfig —
/// the same dark-until-configured pattern as RevenueCat.
///
/// What it does once live:
/// - Uploads crashes, hangs (>2s main-thread stalls) and watchdog kills,
///   symbolicated against the dSYMs uploaded per release.
/// - Tags every event with the release (`nl.astrontech.looopr@1.0.0+4`)
///   and environment (`debug` / `production`) so the morning triage can
///   tell which build a crash belongs to.
/// - Attaches the signed-in Supabase user id (id only — no email, no PII)
///   so "how many users does this affect" is answerable.
/// - Records `AppLogger` warnings/errors as breadcrumbs, giving each crash
///   the last ~100 log lines of context that led up to it.
///
/// What it deliberately does *not* do: performance tracing, screenshots,
/// view-hierarchy capture, or default PII. Looopr tracks location — keep
/// the crash payload minimal.
enum CrashReporter {

    /// True when the SDK has been started with a DSN.
    static var isEnabled: Bool { SentrySDK.isEnabled }

    /// Call as the very first thing in `LoooprApp.init()`, before any other
    /// service is registered, so a crash during startup is still captured.
    static func start() {
        let dsn = Secrets.sentryDSN
        guard !dsn.isEmpty else { return }

        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = environmentName
            options.releaseName = releaseName
            options.debug = false

            // Crash / stability signals only.
            options.enableAutoSessionTracking = true
            options.enableAppHangTracking = true
            options.enableWatchdogTerminationTracking = true

            // Explicitly off — privacy-first for a location app.
            options.sendDefaultPii = false
            options.attachScreenshot = false
            options.attachViewHierarchy = false
            options.tracesSampleRate = 0
        }
    }

    // MARK: - Context

    /// Ties events to the signed-in account (Supabase user id only).
    /// Pass nil on sign-out.
    static func setUser(id: String?) {
        guard isEnabled else { return }
        if let id {
            SentrySDK.setUser(User(userId: id))
        } else {
            SentrySDK.setUser(nil)
        }
    }

    /// Records a breadcrumb so crashes carry the log trail that preceded
    /// them. Called automatically from `AppLogger.warning/error`.
    static func breadcrumb(category: String, message: String, level: SentryLevel = .info) {
        guard isEnabled else { return }
        let crumb = Breadcrumb()
        crumb.level = level
        crumb.category = category
        crumb.message = message
        SentrySDK.addBreadcrumb(crumb)
    }

    /// Reports a handled error that didn't crash but shouldn't have
    /// happened (e.g. a decoding failure on a Supabase row). Use sparingly
    /// — every call is an issue in the dashboard and a candidate for the
    /// morning triage.
    static func capture(_ error: Error, category: String) {
        guard isEnabled else { return }
        SentrySDK.capture(error: error) { scope in
            scope.setTag(value: category, key: "category")
        }
    }

    // MARK: - Private

    private static var environmentName: String {
        #if DEBUG
        return "debug"
        #else
        return "production"
        #endif
    }

    private static var releaseName: String? {
        let info = Bundle.main.infoDictionary
        guard let version = info?["CFBundleShortVersionString"] as? String,
              let build = info?["CFBundleVersion"] as? String,
              let bundleID = Bundle.main.bundleIdentifier else { return nil }
        return "\(bundleID)@\(version)+\(build)"
    }
}
