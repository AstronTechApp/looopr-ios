import SwiftUI
import PostHog

@main
struct LoooprApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // First, so a crash anywhere in startup is still reported.
        CrashReporter.start()
        configurePostHog()
        ServiceContainer.shared.registerProductionServices()
        SettingsManager.shared.restoreOnLaunch()

        // Clean up any orphaned Live Activities from a previous force-quit or crash.
        // This runs on every cold launch so the Dynamic Island never shows stale data.
        LiveActivityManager.shared.endAllActivities()
    }

    /// Product analytics (PostHog, EU cloud). Crashes stay in Sentry, so
    /// PostHog's own error capture is off. A missing token only logs: the app
    /// must never crash or block because analytics isn't configured.
    private func configurePostHog() {
        guard Secrets.hasPostHogProjectToken, Secrets.hasPostHogHost else {
            #if DEBUG
            print("PostHog not configured (POSTHOG_PROJECT_TOKEN / POSTHOG_HOST in Secrets.xcconfig); analytics goes to Supabase only.")
            #endif
            return
        }
        let config = PostHogConfig(
            projectToken: Secrets.postHogProjectToken,
            host: Secrets.postHogHost
        )
        config.errorTrackingConfig.autoCapture = false
        PostHogSDK.shared.setup(config)
    }

    var body: some Scene {
        WindowGroup {
            AppearanceRoot()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // The app moved to background. Don't end the *active* walk's
                // Live Activity (the user may just be switching apps), but
                // sweep any orphaned activities from previous sessions.
                // The staleDate on each content push (5 min) ensures that if
                // the app is force-quit, the activity auto-dismisses.
                LiveActivityManager.shared.endOrphanedActivities()
            }
        }
    }

    /// UI tests only: `-uiTest.appearance dark` forces the scheme, because the
    /// simulator's own appearance can't be switched reliably from a test.
    /// Always nil in Release, so the app follows the system setting.
    fileprivate static var uiTestColorScheme: ColorScheme? {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "uiTest.appearance") {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
        #else
        return nil
        #endif
    }
}

/// The app's root with the look chosen in Settings > Appearance applied
/// (System follows the phone). A view of its own so a change of the setting
/// redraws it. The UI-test override, when present, wins.
private struct AppearanceRoot: View {
    var body: some View {
        let appearance = SettingsManager.shared.appearance
        AppRootView()
            .preferredColorScheme(LoooprApp.uiTestColorScheme ?? appearance.colorScheme)
    }
}

private extension SettingsManager.Appearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
