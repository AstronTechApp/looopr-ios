import SwiftUI

@main
struct MuterApp: App {
    init() {
        ServiceContainer.shared.registerProductionServices()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}
