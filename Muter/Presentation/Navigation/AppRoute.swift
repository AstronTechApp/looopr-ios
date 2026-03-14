import CoreLocation

enum AppRoute: Hashable {
    case discovery
    case routeDetail(Route)
    case walkNavigation(Route)
    case finishWalk(WalkSession)
    case locationSearch
    case settings
    case paywall
}
