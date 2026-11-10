import Foundation

/// Where the paywall was opened from. Stored as the `source` property of
/// the paywall analytics events.
enum PaywallSource: String, Sendable {
    /// Settings › Upgrade to Pro.
    case settings
    /// The upgrade card under the loops when no locked loops are shown.
    case upgradeCard = "upgrade_card"
    /// A locked loop (or its button) on the route list.
    case lockedRoute = "locked_route"
    /// The locked Cafés & restaurants tab on a route.
    case foodLock = "food_lock"
    /// Shown once on its own after the first search that found loops.
    case firstSearch = "first_search"
}
