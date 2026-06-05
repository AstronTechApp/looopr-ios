import SwiftUI

@main
struct LoooprApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        ServiceContainer.shared.registerProductionServices()
        SettingsManager.shared.restoreOnLaunch()

        // Clean up any orphaned Live Activities from a previous force-quit or crash.
        // This runs on every cold launch so the Dynamic Island never shows stale data.
        LiveActivityManager.shared.endAllActivities()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
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
}
