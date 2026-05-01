import CoreLocation

enum AppRoute: Hashable {
    case home
    case routeSelection(walkMinutes: Int, customLocation: CustomRouteLocation? = nil)
    case routeDetail(Route)
    case walkNavigation(Route)
    case finishWalk(WalkSession, Route)
    case walkDetail(WalkSession)
    case sharedRoute(UUID)
    case locationSearch
    case settings
    case paywall
}

/// Hashable wrapper for passing a custom location through navigation.
/// CLLocationCoordinate2D is not Hashable, so we use this lightweight struct.
struct CustomRouteLocation: Hashable {
    let latitude: Double
    let longitude: Double
    let displayName: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(from selected: SelectedLocation) {
        self.latitude = selected.latitude
        self.longitude = selected.longitude
        self.displayName = selected.displayName
    }

    init(latitude: Double, longitude: Double, displayName: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.displayName = displayName
    }
}
