import Foundation

// MARK: - Localization String Constants

enum L10n {
    // MARK: - Tab Navigation
    enum Tab {
        static var home: String { String(localized: "tab.home", defaultValue: "Home", bundle: LocalizationManager.shared.localizedBundle) }
        static var explore: String { String(localized: "tab.explore", defaultValue: "Explore", bundle: LocalizationManager.shared.localizedBundle) }
        static var savedRoutes: String { String(localized: "tab.savedRoutes", defaultValue: "Saved", bundle: LocalizationManager.shared.localizedBundle) }
        static var profile: String { String(localized: "tab.profile", defaultValue: "Profile", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Home Screen
    enum Home {
        static var title: String { String(localized: "home.title", defaultValue: "Home", bundle: LocalizationManager.shared.localizedBundle) }
        static var readyToLooopr: String { String(localized: "home.readyToLooopr", defaultValue: "Ready to Looopr?", bundle: LocalizationManager.shared.localizedBundle) }
        static var howLongWalk: String { String(localized: "home.howLongWalk", defaultValue: "How long do you want to walk?", bundle: LocalizationManager.shared.localizedBundle) }
        static var duration15min: String { String(localized: "home.duration.15min", defaultValue: "15min", bundle: LocalizationManager.shared.localizedBundle) }
        static var duration3h: String { String(localized: "home.duration.3h", defaultValue: "3h", bundle: LocalizationManager.shared.localizedBundle) }
        static var walkingPace: String { String(localized: "home.walkingPace", defaultValue: "WALKING PACE", bundle: LocalizationManager.shared.localizedBundle) }
        static var findMyLooopr: String { String(localized: "home.findMyLooopr", defaultValue: "Find My Looopr", bundle: LocalizationManager.shared.localizedBundle) }
        static var savedLoooprs: String { String(localized: "home.savedLoooprs", defaultValue: "Saved Loooprs", bundle: LocalizationManager.shared.localizedBundle) }
        static var viewAll: String { String(localized: "home.viewAll", defaultValue: "VIEW ALL", bundle: LocalizationManager.shared.localizedBundle) }
        static var noSavedRoutes: String { String(localized: "home.noSavedRoutes", defaultValue: "No saved routes yet", bundle: LocalizationManager.shared.localizedBundle) }
        static var bookmarkRoutesDescription: String { String(localized: "home.bookmarkRoutesDescription", defaultValue: "Bookmark routes you love and they'll appear here", bundle: LocalizationManager.shared.localizedBundle) }
        static var recentLoooprs: String { String(localized: "home.recentLoooprs", defaultValue: "Recent Loooprs", bundle: LocalizationManager.shared.localizedBundle) }
        static var findingNearbyExperiences: String { String(localized: "home.findingNearbyExperiences", defaultValue: "Finding nearby experiences...", bundle: LocalizationManager.shared.localizedBundle) }
        static var goodMorning: String { String(localized: "home.greeting.morning", defaultValue: "Good morning", bundle: LocalizationManager.shared.localizedBundle) }
        static var goodAfternoon: String { String(localized: "home.greeting.afternoon", defaultValue: "Good afternoon", bundle: LocalizationManager.shared.localizedBundle) }
        static var goodEvening: String { String(localized: "home.greeting.evening", defaultValue: "Good evening", bundle: LocalizationManager.shared.localizedBundle) }
        static var currentLocation: String { String(localized: "home.currentLocation", defaultValue: "Current Location", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Authentication
    enum Auth {
        static var welcome: String { String(localized: "auth.welcome", defaultValue: "Welcome to Looopr", bundle: LocalizationManager.shared.localizedBundle) }
        static var discoverRoutesDescription: String { String(localized: "auth.discoverRoutesDescription", defaultValue: "Discover walking routes around you", bundle: LocalizationManager.shared.localizedBundle) }
        static var signInGoogle: String { String(localized: "auth.signInGoogle", defaultValue: "Sign in with Google", bundle: LocalizationManager.shared.localizedBundle) }
        static var signingIn: String { String(localized: "auth.signingIn", defaultValue: "Signing in...", bundle: LocalizationManager.shared.localizedBundle) }
        static var appleIDCredentialsFailed: String { String(localized: "auth.appleIDCredentialsFailed", defaultValue: "Failed to get Apple ID credentials.", bundle: LocalizationManager.shared.localizedBundle) }
        static var privacyAgreement: String { String(localized: "auth.privacyAgreement", defaultValue: "By signing in, you agree to our [Privacy Policy](https://looopr.app/privacy). We collect your name, email, saved routes, and walk history to provide the service.", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Route Names
    enum RouteName {
        static var loop: String { String(localized: "routeName.loop", defaultValue: "Loop", bundle: LocalizationManager.shared.localizedBundle) }
        static var north: String { String(localized: "routeName.north", defaultValue: "North", bundle: LocalizationManager.shared.localizedBundle) }
        static var northeast: String { String(localized: "routeName.northeast", defaultValue: "Northeast", bundle: LocalizationManager.shared.localizedBundle) }
        static var east: String { String(localized: "routeName.east", defaultValue: "East", bundle: LocalizationManager.shared.localizedBundle) }
        static var southeast: String { String(localized: "routeName.southeast", defaultValue: "Southeast", bundle: LocalizationManager.shared.localizedBundle) }
        static var south: String { String(localized: "routeName.south", defaultValue: "South", bundle: LocalizationManager.shared.localizedBundle) }
        static var southwest: String { String(localized: "routeName.southwest", defaultValue: "Southwest", bundle: LocalizationManager.shared.localizedBundle) }
        static var west: String { String(localized: "routeName.west", defaultValue: "West", bundle: LocalizationManager.shared.localizedBundle) }
        static var northwest: String { String(localized: "routeName.northwest", defaultValue: "Northwest", bundle: LocalizationManager.shared.localizedBundle) }

        /// Translates a stored English route name (e.g. "Northwest Loop") at display time.
        /// Sorted longest-first so "Northwest" matches before "North".
        /// Also handles spaced variants like "North West" and "North East".
        static func localized(_ englishName: String) -> String {
            // Longest keys first so "Northwest" is checked before "North"
            let directionMap: [(english: String, localized: () -> String)] = [
                ("Northwest", { northwest }),
                ("Northeast", { northeast }),
                ("Southwest", { southwest }),
                ("Southeast", { southeast }),
                ("North West", { northwest }),
                ("North East", { northeast }),
                ("South West", { southwest }),
                ("South East", { southeast }),
                ("North", { north }),
                ("South", { south }),
                ("East", { east }),
                ("West", { west }),
            ]
            for entry in directionMap {
                if englishName.hasPrefix(entry.english) {
                    let suffix = englishName.dropFirst(entry.english.count).trimmingCharacters(in: .whitespaces)
                    if suffix == "Loop" || suffix.isEmpty {
                        return "\(entry.localized()) \(loop)"
                    }
                    return "\(entry.localized()) \(suffix)"
                }
            }
            return englishName
        }
    }

    // MARK: - Route Selection
    enum RouteSelection {
        static var yourRoutes: String { String(localized: "routeSelection.yourRoutes", defaultValue: "Your Routes", bundle: LocalizationManager.shared.localizedBundle) }
        static var walkLabel: String { String(localized: "routeSelection.walkLabel", defaultValue: "walk", bundle: LocalizationManager.shared.localizedBundle) }
        static var noRoutesFound: String { String(localized: "routeSelection.noRoutesFound", defaultValue: "No routes found nearby", bundle: LocalizationManager.shared.localizedBundle) }
        static var difficulty: String { String(localized: "routeSelection.difficulty", defaultValue: "Difficulty", bundle: LocalizationManager.shared.localizedBundle) }
        static var loopLabel: String { String(localized: "routeSelection.loopLabel", defaultValue: "loop", bundle: LocalizationManager.shared.localizedBundle) }
        static var includesFerry: String { String(localized: "routeSelection.includesFerry", defaultValue: "Includes ferry crossing", bundle: LocalizationManager.shared.localizedBundle) }
        static var startWalk: String { String(localized: "routeSelection.startWalk", defaultValue: "Start Walk", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Route Detail
    enum RouteDetail {
        static var startThisLooopr: String { String(localized: "routeDetail.startThisLooopr", defaultValue: "Start This Looopr", bundle: LocalizationManager.shared.localizedBundle) }
        static var foodStopNearby: String { String(localized: "routeDetail.foodStopNearby", defaultValue: "There's already a food stop nearby — consider one further along the route", bundle: LocalizationManager.shared.localizedBundle) }

        static func foodStopsAdded(_ count: Int) -> String {
            if count == 1 {
                return String(localized: "routeDetail.foodStops.singular", defaultValue: "1 food stop added", bundle: LocalizationManager.shared.localizedBundle)
            } else {
                return String(format: NSLocalizedString("routeDetail.foodStops.plural", tableName: nil, bundle: LocalizationManager.shared.localizedBundle, value: "%@ food stop(s) added", comment: ""), "\(count)")
            }
        }

        static var aboutThisRoute: String { String(localized: "routeDetail.aboutThisRoute", defaultValue: "ABOUT THIS ROUTE", bundle: LocalizationManager.shared.localizedBundle) }
        static var loopDuration: String { String(localized: "routeDetail.loopDuration", defaultValue: "loop", bundle: LocalizationManager.shared.localizedBundle) }
        static var includeFerryDescription: String { String(localized: "routeDetail.includeFerryDescription", defaultValue: "This route includes a ferry crossing", bundle: LocalizationManager.shared.localizedBundle) }
        static var leavingTime: String { String(localized: "routeDetail.leavingTime", defaultValue: "Leaving time", bundle: LocalizationManager.shared.localizedBundle) }
        static var findingNearbyAttractions: String { String(localized: "routeDetail.findingNearbyAttractions", defaultValue: "Finding nearby attractions...", bundle: LocalizationManager.shared.localizedBundle) }
        static var pointsOfInterest: String { String(localized: "routeDetail.pointsOfInterest", defaultValue: "POINTS OF INTEREST", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Points of Interest (POI)
    enum POI {
        static var onRoute: String { String(localized: "poi.onRoute", defaultValue: "On Route", bundle: LocalizationManager.shared.localizedBundle) }
        static var nearRoute: String { String(localized: "poi.nearRoute", defaultValue: "Near Route", bundle: LocalizationManager.shared.localizedBundle) }
        static var foodAndDrinks: String { String(localized: "poi.foodAndDrinks", defaultValue: "Food & Drinks", bundle: LocalizationManager.shared.localizedBundle) }
        static var cafes: String { String(localized: "poi.cafes", defaultValue: "Cafes", bundle: LocalizationManager.shared.localizedBundle) }
        static var restaurants: String { String(localized: "poi.restaurants", defaultValue: "Restaurants", bundle: LocalizationManager.shared.localizedBundle) }
        static var findingNearby: String { String(localized: "poi.findingNearby", defaultValue: "Finding nearby cafes & restaurants...", bundle: LocalizationManager.shared.localizedBundle) }
        static var noRestaurantsFound: String { String(localized: "poi.noRestaurantsFound", defaultValue: "No highly-rated cafes or restaurants found nearby", bundle: LocalizationManager.shared.localizedBundle) }
        static var tapToFind: String { String(localized: "poi.tapToFind", defaultValue: "Tap to find nearby cafes & restaurants", bundle: LocalizationManager.shared.localizedBundle) }
        static var fromRoute: String { String(localized: "poi.fromRoute", defaultValue: "from route", bundle: LocalizationManager.shared.localizedBundle) }
        static var walkTime: String { String(localized: "poi.walkTime", defaultValue: "walk", bundle: LocalizationManager.shared.localizedBundle) }
        static var openNow: String { String(localized: "poi.openNow", defaultValue: "Open now", bundle: LocalizationManager.shared.localizedBundle) }
        static var openThen: String { String(localized: "poi.openThen", defaultValue: "Open then", bundle: LocalizationManager.shared.localizedBundle) }
        static var openingSoon: String { String(localized: "poi.openingSoon", defaultValue: "Opening soon", bundle: LocalizationManager.shared.localizedBundle) }
        static var closed: String { String(localized: "poi.closed", defaultValue: "Closed", bundle: LocalizationManager.shared.localizedBundle) }
        static var closedThen: String { String(localized: "poi.closedThen", defaultValue: "Closed then", bundle: LocalizationManager.shared.localizedBundle) }
        static var googleMaps: String { String(localized: "poi.googleMaps", defaultValue: "Google Maps", bundle: LocalizationManager.shared.localizedBundle) }
        static var appleMaps: String { String(localized: "poi.appleMaps", defaultValue: "Apple Maps", bundle: LocalizationManager.shared.localizedBundle) }

        // MARK: - POI Categories
        enum Category {
            static var museum: String { String(localized: "poi.category.museum", defaultValue: "Museum", bundle: LocalizationManager.shared.localizedBundle) }
            static var monument: String { String(localized: "poi.category.monument", defaultValue: "Monument", bundle: LocalizationManager.shared.localizedBundle) }
            static var historicSite: String { String(localized: "poi.category.historicSite", defaultValue: "Historic Site", bundle: LocalizationManager.shared.localizedBundle) }
            static var church: String { String(localized: "poi.category.church", defaultValue: "Church", bundle: LocalizationManager.shared.localizedBundle) }
            static var castle: String { String(localized: "poi.category.castle", defaultValue: "Castle", bundle: LocalizationManager.shared.localizedBundle) }
            static var park: String { String(localized: "poi.category.park", defaultValue: "Park", bundle: LocalizationManager.shared.localizedBundle) }
            static var garden: String { String(localized: "poi.category.garden", defaultValue: "Garden", bundle: LocalizationManager.shared.localizedBundle) }
            static var gallery: String { String(localized: "poi.category.gallery", defaultValue: "Gallery", bundle: LocalizationManager.shared.localizedBundle) }
            static var theater: String { String(localized: "poi.category.theater", defaultValue: "Theater", bundle: LocalizationManager.shared.localizedBundle) }
            static var zoo: String { String(localized: "poi.category.zoo", defaultValue: "Zoo", bundle: LocalizationManager.shared.localizedBundle) }
            static var aquarium: String { String(localized: "poi.category.aquarium", defaultValue: "Aquarium", bundle: LocalizationManager.shared.localizedBundle) }
            static var landmark: String { String(localized: "poi.category.landmark", defaultValue: "Landmark", bundle: LocalizationManager.shared.localizedBundle) }
            static var viewpoint: String { String(localized: "poi.category.viewpoint", defaultValue: "Viewpoint", bundle: LocalizationManager.shared.localizedBundle) }
            static var restaurant: String { String(localized: "poi.category.restaurant", defaultValue: "Restaurant", bundle: LocalizationManager.shared.localizedBundle) }
            static var cafe: String { String(localized: "poi.category.cafe", defaultValue: "Café", bundle: LocalizationManager.shared.localizedBundle) }
            static var bakery: String { String(localized: "poi.category.bakery", defaultValue: "Bakery", bundle: LocalizationManager.shared.localizedBundle) }
            static var bar: String { String(localized: "poi.category.bar", defaultValue: "Bar", bundle: LocalizationManager.shared.localizedBundle) }
            static var other: String { String(localized: "poi.category.other", defaultValue: "Other", bundle: LocalizationManager.shared.localizedBundle) }
        }
    }

    // MARK: - POI Detail
    enum POIDetail {
        static var loadingDetails: String { String(localized: "poiDetail.loadingDetails", defaultValue: "Loading details...", bundle: LocalizationManager.shared.localizedBundle) }
        static var findingTickets: String { String(localized: "poiDetail.findingTickets", defaultValue: "Finding tickets...", bundle: LocalizationManager.shared.localizedBundle) }

        static func compareProviders(_ count: Int) -> String {
            return String(format: NSLocalizedString("poiDetail.compareProviders", tableName: nil, bundle: LocalizationManager.shared.localizedBundle, value: "Compare providers (%@)", comment: ""), "\(count)")
        }

        static var viewOnGoogleMaps: String { String(localized: "poiDetail.viewOnGoogleMaps", defaultValue: "View on Google Maps", bundle: LocalizationManager.shared.localizedBundle) }
        static var bookTickets: String { String(localized: "poiDetail.bookTickets", defaultValue: "Book Tickets", bundle: LocalizationManager.shared.localizedBundle) }

        static func bookOn(_ provider: String) -> String {
            return String(format: NSLocalizedString("poiDetail.bookOn", tableName: nil, bundle: LocalizationManager.shared.localizedBundle, value: "Book on %@", comment: ""), provider)
        }

        static var buyTickets: String { String(localized: "poiDetail.buyTickets", defaultValue: "Buy Tickets", bundle: LocalizationManager.shared.localizedBundle) }
        static var visitWebsite: String { String(localized: "poiDetail.visitWebsite", defaultValue: "Visit Website", bundle: LocalizationManager.shared.localizedBundle) }
        static var call: String { String(localized: "poiDetail.call", defaultValue: "Call", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Walk Navigation
    enum WalkNavigation {
        static var endWalk: String { String(localized: "walkNavigation.endWalk", defaultValue: "End walk?", bundle: LocalizationManager.shared.localizedBundle) }
        static var endWalkButton: String { String(localized: "walkNavigation.endWalkButton", defaultValue: "End Walk", bundle: LocalizationManager.shared.localizedBundle) }
        static var progressNotSaved: String { String(localized: "walkNavigation.progressNotSaved", defaultValue: "Your progress will not be saved.", bundle: LocalizationManager.shared.localizedBundle) }
        static var preparingNavigation: String { String(localized: "walkNavigation.preparingNavigation", defaultValue: "Preparing navigation...", bundle: LocalizationManager.shared.localizedBundle) }
        static var nearby: String { String(localized: "walkNavigation.nearby", defaultValue: "Nearby", bundle: LocalizationManager.shared.localizedBundle) }
        static var checkIn: String { String(localized: "walkNavigation.checkIn", defaultValue: "Check in", bundle: LocalizationManager.shared.localizedBundle) }
        static var finishWalk: String { String(localized: "walkNavigation.finishWalk", defaultValue: "Finish Walk", bundle: LocalizationManager.shared.localizedBundle) }
        static var remaining: String { String(localized: "walkNavigation.remaining", defaultValue: "remaining", bundle: LocalizationManager.shared.localizedBundle) }
        static var routeUpdated: String { String(localized: "walkNavigation.routeUpdated", defaultValue: "Route updated", bundle: LocalizationManager.shared.localizedBundle) }
        static var routeFlipping: String { String(localized: "walkNavigation.routeFlipping", defaultValue: "Flipping route...", bundle: LocalizationManager.shared.localizedBundle) }
        static var routeFlipped: String { String(localized: "walkNavigation.routeFlipped", defaultValue: "Route flipped — enjoy the walk!", bundle: LocalizationManager.shared.localizedBundle) }
        static var routeFlipFailed: String { String(localized: "walkNavigation.routeFlipFailed", defaultValue: "Couldn't flip route. Try again in a moment.", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Food Check-in
    enum FoodCheckIn {
        static func nearestFood(_ name: String) -> String {
            return String(format: NSLocalizedString("foodCheckIn.nearestFood", tableName: nil, bundle: LocalizationManager.shared.localizedBundle, value: "You're near %@", comment: ""), name)
        }

        static var stoppingForBreak: String { String(localized: "foodCheckIn.stoppingForBreak", defaultValue: "Stopping for a break?", bundle: LocalizationManager.shared.localizedBundle) }
        static var checkInButton: String { String(localized: "foodCheckIn.checkInButton", defaultValue: "Check in", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Wrong Way Alert
    enum WrongWay {
        static var title: String { String(localized: "wrongWay.title", defaultValue: "Walking the other way?", bundle: LocalizationManager.shared.localizedBundle) }
        static var message: String { String(localized: "wrongWay.message", defaultValue: "Looks like you're heading in the opposite direction. Want to flip the route to match?", bundle: LocalizationManager.shared.localizedBundle) }
        static var flipRoute: String { String(localized: "wrongWay.flipRoute", defaultValue: "Yes, flip route", bundle: LocalizationManager.shared.localizedBundle) }
        static var turnAround: String { String(localized: "wrongWay.turnAround", defaultValue: "No, stay as is", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Finish Walk
    enum FinishWalk {
        static var title: String { String(localized: "finishWalk.title", defaultValue: "Looopr Complete!", bundle: LocalizationManager.shared.localizedBundle) }
        static var breaks: String { String(localized: "finishWalk.breaks", defaultValue: "BREAKS", bundle: LocalizationManager.shared.localizedBundle) }

        static func breakAt(_ name: String) -> String {
            return String(format: NSLocalizedString("finishWalk.breakAt", tableName: nil, bundle: LocalizationManager.shared.localizedBundle, value: "A break at %@", comment: ""), name)
        }

        static var share: String { String(localized: "finishWalk.share", defaultValue: "Share", bundle: LocalizationManager.shared.localizedBundle) }
        static var save: String { String(localized: "finishWalk.save", defaultValue: "Save", bundle: LocalizationManager.shared.localizedBundle) }
        static var saved: String { String(localized: "finishWalk.saved", defaultValue: "Saved!", bundle: LocalizationManager.shared.localizedBundle) }
        static var shareLooopr: String { String(localized: "finishWalk.shareLooopr", defaultValue: "Share Looopr", bundle: LocalizationManager.shared.localizedBundle) }
        static var saveRoute: String { String(localized: "finishWalk.saveRoute", defaultValue: "Save Route", bundle: LocalizationManager.shared.localizedBundle) }
        static var routeSaved: String { String(localized: "finishWalk.routeSaved", defaultValue: "Route Saved", bundle: LocalizationManager.shared.localizedBundle) }
        static var shareRoute: String { String(localized: "finishWalk.shareRoute", defaultValue: "Share Route", bundle: LocalizationManager.shared.localizedBundle) }
        static var goHome: String { String(localized: "finishWalk.goHome", defaultValue: "Go Home", bundle: LocalizationManager.shared.localizedBundle) }
        static var distance: String { String(localized: "finishWalk.distance", defaultValue: "Distance", bundle: LocalizationManager.shared.localizedBundle) }
        static var duration: String { String(localized: "finishWalk.duration", defaultValue: "Duration", bundle: LocalizationManager.shared.localizedBundle) }
        static var avgPace: String { String(localized: "finishWalk.avgPace", defaultValue: "Avg Pace", bundle: LocalizationManager.shared.localizedBundle) }
        static var elevation: String { String(localized: "finishWalk.elevation", defaultValue: "Elevation", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Saved Routes
    enum SavedRoutes {
        static var title: String { String(localized: "savedRoutes.title", defaultValue: "Saved Routes", bundle: LocalizationManager.shared.localizedBundle) }
        static var empty: String { String(localized: "savedRoutes.empty", defaultValue: "No saved routes yet", bundle: LocalizationManager.shared.localizedBundle) }
        static var emptyDescription: String { String(localized: "savedRoutes.emptyDescription", defaultValue: "Save routes you love to walk them again\nor share them with friends", bundle: LocalizationManager.shared.localizedBundle) }
        static var startWalk: String { String(localized: "savedRoutes.startWalk", defaultValue: "Start Walk", bundle: LocalizationManager.shared.localizedBundle) }
        static var share: String { String(localized: "savedRoutes.share", defaultValue: "Share", bundle: LocalizationManager.shared.localizedBundle) }
        static var remove: String { String(localized: "savedRoutes.remove", defaultValue: "Remove", bundle: LocalizationManager.shared.localizedBundle) }
        static var removeQuestion: String { String(localized: "savedRoutes.removeQuestion", defaultValue: "Remove from saved?", bundle: LocalizationManager.shared.localizedBundle) }

        static func willBeRemoved(_ name: String) -> String {
            return String(format: NSLocalizedString("savedRoutes.willBeRemoved", tableName: nil, bundle: LocalizationManager.shared.localizedBundle, value: "%@ will be removed from your saved routes.", comment: ""), name)
        }

        static var cancel: String { String(localized: "savedRoutes.cancel", defaultValue: "Cancel", bundle: LocalizationManager.shared.localizedBundle) }
        static var shareErrorTitle: String { String(localized: "savedRoutes.shareErrorTitle", defaultValue: "Couldn't Share", bundle: LocalizationManager.shared.localizedBundle) }
        static var shareErrorMessage: String { String(localized: "savedRoutes.shareErrorMessage", defaultValue: "Something went wrong. Please try again.", bundle: LocalizationManager.shared.localizedBundle) }

        static func shareTitle(_ name: String) -> String {
            return String(format: NSLocalizedString("savedRoutes.shareTitle", tableName: nil, bundle: LocalizationManager.shared.localizedBundle, value: "Check out this %@ walk on Looopr!", comment: ""), name)
        }
    }

    // MARK: - Profile
    enum Profile {
        static var title: String { String(localized: "profile.title", defaultValue: "Profile", bundle: LocalizationManager.shared.localizedBundle) }
        static var tabProgress: String { String(localized: "profile.tabProgress", defaultValue: "Progress", bundle: LocalizationManager.shared.localizedBundle) }
        static var tabActivities: String { String(localized: "profile.tabActivities", defaultValue: "Activities", bundle: LocalizationManager.shared.localizedBundle) }

        static func walksCompleted(_ count: Int) -> String {
            return String(format: NSLocalizedString("profile.walksCompleted", tableName: nil, bundle: LocalizationManager.shared.localizedBundle, value: "%@ walks completed", comment: ""), "\(count)")
        }

        static var thisWeek: String { String(localized: "profile.thisWeek", defaultValue: "THIS WEEK", bundle: LocalizationManager.shared.localizedBundle) }
        static var past8Weeks: String { String(localized: "profile.past8Weeks", defaultValue: "PAST 8 WEEKS", bundle: LocalizationManager.shared.localizedBundle) }
        static var weekStreak: String { String(localized: "profile.weekStreak", defaultValue: "Week Streak", bundle: LocalizationManager.shared.localizedBundle) }
        static var totalWalks: String { String(localized: "profile.totalWalks", defaultValue: "Total Walks", bundle: LocalizationManager.shared.localizedBundle) }
        static var completeFirstLooopr: String { String(localized: "profile.completeFirstLooopr", defaultValue: "Complete your first Looopr to see your progress here", bundle: LocalizationManager.shared.localizedBundle) }
        static var noWalksYet: String { String(localized: "profile.noWalksYet", defaultValue: "No walks yet", bundle: LocalizationManager.shared.localizedBundle) }
        static var startLoooprDescription: String { String(localized: "profile.startLoooprDescription", defaultValue: "Start a Looopr to build your activity history", bundle: LocalizationManager.shared.localizedBundle) }
        static var distance: String { String(localized: "profile.distance", defaultValue: "Distance", bundle: LocalizationManager.shared.localizedBundle) }
        static var steps: String { String(localized: "profile.steps", defaultValue: "Steps", bundle: LocalizationManager.shared.localizedBundle) }
        static var time: String { String(localized: "profile.time", defaultValue: "Time", bundle: LocalizationManager.shared.localizedBundle) }
        static var elevationGain: String { String(localized: "profile.elevationGain", defaultValue: "Elev Gain", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Settings
    enum Settings {
        static var title: String { String(localized: "settings.title", defaultValue: "Settings", bundle: LocalizationManager.shared.localizedBundle) }
        static var account: String { String(localized: "settings.account", defaultValue: "ACCOUNT", bundle: LocalizationManager.shared.localizedBundle) }
        static var displayName: String { String(localized: "settings.displayName", defaultValue: "Display Name", bundle: LocalizationManager.shared.localizedBundle) }
        static var walkPreferences: String { String(localized: "settings.walkPreferences", defaultValue: "WALK PREFERENCES", bundle: LocalizationManager.shared.localizedBundle) }
        static var preferredUnits: String { String(localized: "settings.preferredUnits", defaultValue: "Preferred Units", bundle: LocalizationManager.shared.localizedBundle) }
        static var walkingPace: String { String(localized: "settings.walkingPace", defaultValue: "Walking Pace", bundle: LocalizationManager.shared.localizedBundle) }
        static var distanceUnits: String { String(localized: "settings.distanceUnits", defaultValue: "Distance Units", bundle: LocalizationManager.shared.localizedBundle) }
        static var language: String { String(localized: "settings.language", defaultValue: "Language", bundle: LocalizationManager.shared.localizedBundle) }
        static var health: String { String(localized: "settings.health", defaultValue: "HEALTH", bundle: LocalizationManager.shared.localizedBundle) }
        static var appleHealth: String { String(localized: "settings.appleHealth", defaultValue: "Apple Health", bundle: LocalizationManager.shared.localizedBundle) }
        static var notConnected: String { String(localized: "settings.notConnected", defaultValue: "Not Connected", bundle: LocalizationManager.shared.localizedBundle) }
        static var notifications: String { String(localized: "settings.notifications", defaultValue: "NOTIFICATIONS", bundle: LocalizationManager.shared.localizedBundle) }
        static var walkReminder: String { String(localized: "settings.walkReminder", defaultValue: "Walk Reminder", bundle: LocalizationManager.shared.localizedBundle) }
        static var walkReminderDescription: String { String(localized: "settings.walkReminderDescription", defaultValue: "Daily reminder to go for a walk", bundle: LocalizationManager.shared.localizedBundle) }
        static var reminderTime: String { String(localized: "settings.reminderTime", defaultValue: "Reminder Time", bundle: LocalizationManager.shared.localizedBundle) }
        static var weeklySummary: String { String(localized: "settings.weeklySummary", defaultValue: "Weekly Summary", bundle: LocalizationManager.shared.localizedBundle) }
        static var weeklySummaryDescription: String { String(localized: "settings.weeklySummaryDescription", defaultValue: "Sunday evening progress recap", bundle: LocalizationManager.shared.localizedBundle) }
        static var privacyAndData: String { String(localized: "settings.privacyAndData", defaultValue: "PRIVACY & DATA", bundle: LocalizationManager.shared.localizedBundle) }
        static var privacyAndDataLink: String { String(localized: "settings.privacyAndDataLink", defaultValue: "Privacy & Data", bundle: LocalizationManager.shared.localizedBundle) }
        static var manage: String { String(localized: "settings.manage", defaultValue: "Manage", bundle: LocalizationManager.shared.localizedBundle) }
        static var signOut: String { String(localized: "settings.signOut", defaultValue: "Sign Out", bundle: LocalizationManager.shared.localizedBundle) }
        static var cancel: String { String(localized: "settings.cancel", defaultValue: "Cancel", bundle: LocalizationManager.shared.localizedBundle) }
        static var about: String { String(localized: "settings.about", defaultValue: "ABOUT", bundle: LocalizationManager.shared.localizedBundle) }
        static var looopr: String { String(localized: "settings.looopr", defaultValue: "Looopr", bundle: LocalizationManager.shared.localizedBundle) }
        static var appVersion: String { String(localized: "settings.appVersion", defaultValue: "App Version", bundle: LocalizationManager.shared.localizedBundle) }
        static var rateLooopr: String { String(localized: "settings.rateLooopr", defaultValue: "Rate Looopr", bundle: LocalizationManager.shared.localizedBundle) }
        static var shareLooopr: String { String(localized: "settings.shareLooopr", defaultValue: "Share Looopr", bundle: LocalizationManager.shared.localizedBundle) }
        static var privacyPolicy: String { String(localized: "settings.privacyPolicy", defaultValue: "Privacy Policy", bundle: LocalizationManager.shared.localizedBundle) }
        static var notificationsDisabled: String { String(localized: "settings.notificationsDisabled", defaultValue: "Notifications Disabled", bundle: LocalizationManager.shared.localizedBundle) }
        static var openSettings: String { String(localized: "settings.openSettings", defaultValue: "Open Settings", bundle: LocalizationManager.shared.localizedBundle) }
        static var enableNotificationsMessage: String { String(localized: "settings.enableNotificationsMessage", defaultValue: "Enable notifications in Settings to use walk reminders.", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Walking Pace
    enum WalkingPace {
        static var leisure: String { String(localized: "walkingPace.leisure", defaultValue: "Leisure", bundle: LocalizationManager.shared.localizedBundle) }
        static var moderate: String { String(localized: "walkingPace.moderate", defaultValue: "Moderate", bundle: LocalizationManager.shared.localizedBundle) }
        static var brisk: String { String(localized: "walkingPace.brisk", defaultValue: "Brisk", bundle: LocalizationManager.shared.localizedBundle) }
        static var leisureDescription: String { String(localized: "walkingPace.leisureDescription", defaultValue: "relaxed stroll", bundle: LocalizationManager.shared.localizedBundle) }
        static var moderateDescription: String { String(localized: "walkingPace.moderateDescription", defaultValue: "comfortable pace", bundle: LocalizationManager.shared.localizedBundle) }
        static var briskDescription: String { String(localized: "walkingPace.briskDescription", defaultValue: "fast walk", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Health Settings
    enum HealthSettings {
        static var appleHealth: String { String(localized: "healthSettings.appleHealth", defaultValue: "Apple Health", bundle: LocalizationManager.shared.localizedBundle) }
        static var connectAppleHealth: String { String(localized: "healthSettings.connectAppleHealth", defaultValue: "Connect Apple Health", bundle: LocalizationManager.shared.localizedBundle) }
        static var comingSoon: String { String(localized: "healthSettings.comingSoon", defaultValue: "Apple Health integration is coming in a future update. Stay tuned!", bundle: LocalizationManager.shared.localizedBundle) }
        static var syncWithAppleHealth: String { String(localized: "healthSettings.syncWithAppleHealth", defaultValue: "Sync with Apple Health", bundle: LocalizationManager.shared.localizedBundle) }
        static var descriptionMessage: String { String(localized: "healthSettings.descriptionMessage", defaultValue: "Connect Looopr with Apple Health to automatically save your walks and track your progress across all your health apps.", bundle: LocalizationManager.shared.localizedBundle) }
        static var privacyMessage: String { String(localized: "healthSettings.privacyMessage", defaultValue: "Your health data stays on your device. Looopr never uploads health information to any server.", bundle: LocalizationManager.shared.localizedBundle) }
        static var comingSoonButton: String { String(localized: "healthSettings.comingSoonButton", defaultValue: "Coming Soon", bundle: LocalizationManager.shared.localizedBundle) }
        static var ok: String { String(localized: "healthSettings.ok", defaultValue: "OK", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Privacy Settings
    enum PrivacySettings {
        static var title: String { String(localized: "privacySettings.title", defaultValue: "Privacy & Data", bundle: LocalizationManager.shared.localizedBundle) }
        static var descriptionMessage: String { String(localized: "privacySettings.descriptionMessage", defaultValue: "We take your privacy seriously. Your data is encrypted and stored securely.", bundle: LocalizationManager.shared.localizedBundle) }
        static var exportMyData: String { String(localized: "privacySettings.exportMyData", defaultValue: "Export My Data", bundle: LocalizationManager.shared.localizedBundle) }
        static var downloadData: String { String(localized: "privacySettings.downloadData", defaultValue: "Download all your data as JSON", bundle: LocalizationManager.shared.localizedBundle) }
        static var dataSaved: String { String(localized: "privacySettings.dataSaved", defaultValue: "Your data has been saved to your Files app.", bundle: LocalizationManager.shared.localizedBundle) }
        static var exportComplete: String { String(localized: "privacySettings.exportComplete", defaultValue: "Export Complete", bundle: LocalizationManager.shared.localizedBundle) }
        static var deleteMyAccount: String { String(localized: "privacySettings.deleteMyAccount", defaultValue: "Delete My Account", bundle: LocalizationManager.shared.localizedBundle) }
        static var deleteWarning: String { String(localized: "privacySettings.deleteWarning", defaultValue: "This action cannot be undone. All your data, saved routes, and walk history will be permanently deleted.", bundle: LocalizationManager.shared.localizedBundle) }
        static var yourData: String { String(localized: "privacySettings.yourData", defaultValue: "YOUR DATA", bundle: LocalizationManager.shared.localizedBundle) }
        static var dangerZone: String { String(localized: "privacySettings.dangerZone", defaultValue: "DANGER ZONE", bundle: LocalizationManager.shared.localizedBundle) }
        static var deleteAccount: String { String(localized: "privacySettings.deleteAccount", defaultValue: "Delete Account", bundle: LocalizationManager.shared.localizedBundle) }
        static var permanentlyRemoveData: String { String(localized: "privacySettings.permanentlyRemoveData", defaultValue: "Permanently remove all your data", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Notifications
    enum Notifications {
        static var timeForLooopr: String { String(localized: "notifications.timeForLooopr", defaultValue: "Time for a Looopr!", bundle: LocalizationManager.shared.localizedBundle) }
        static var getOutside: String { String(localized: "notifications.getOutside", defaultValue: "Get outside and discover a new route near you.", bundle: LocalizationManager.shared.localizedBundle) }
        static var weeklySummary: String { String(localized: "notifications.weeklySummary", defaultValue: "Your weekly Looopr summary", bundle: LocalizationManager.shared.localizedBundle) }
        static var checkOutProgress: String { String(localized: "notifications.checkOutProgress", defaultValue: "Check out how far you walked this week!", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Location Search
    enum LocationSearch {
        static var useCurrentLocation: String { String(localized: "locationSearch.useCurrentLocation", defaultValue: "Use Current Location", bundle: LocalizationManager.shared.localizedBundle) }
        static var routesNearYou: String { String(localized: "locationSearch.routesNearYou", defaultValue: "Routes near where you are now", bundle: LocalizationManager.shared.localizedBundle) }
        static var recent: String { String(localized: "locationSearch.recent", defaultValue: "Recent", bundle: LocalizationManager.shared.localizedBundle) }
        static var results: String { String(localized: "locationSearch.results", defaultValue: "Results", bundle: LocalizationManager.shared.localizedBundle) }
        static var cancel: String { String(localized: "locationSearch.cancel", defaultValue: "Cancel", bundle: LocalizationManager.shared.localizedBundle) }
        static var searchLocation: String { String(localized: "locationSearch.searchLocation", defaultValue: "Search Location", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Nearby Experiences
    enum NearbyExperiences {
        static var title: String { String(localized: "nearbyExperiences.title", defaultValue: "NEARBY EXPERIENCES", bundle: LocalizationManager.shared.localizedBundle) }
        static var poweredByGetYourGuide: String { String(localized: "nearbyExperiences.poweredByGetYourGuide", defaultValue: "Powered by GetYourGuide", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Live Activity
    enum LiveActivity {
        static var walked: String { String(localized: "liveActivity.walked", defaultValue: "walked", bundle: LocalizationManager.shared.localizedBundle) }
        static var ahead: String { String(localized: "liveActivity.ahead", defaultValue: "ahead", bundle: LocalizationManager.shared.localizedBundle) }
        static var next: String { String(localized: "liveActivity.next", defaultValue: "Next:", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Time/Duration
    enum Time {
        static var min: String { String(localized: "time.min", defaultValue: "min", bundle: LocalizationManager.shared.localizedBundle) }
        static var h: String { String(localized: "time.h", defaultValue: "h", bundle: LocalizationManager.shared.localizedBundle) }
        static var hMin: String { String(localized: "time.hMin", defaultValue: "h min", bundle: LocalizationManager.shared.localizedBundle) }

        static func hoursAndMinutes(_ hours: Int, _ minutes: Int) -> String {
            return String(format: NSLocalizedString("time.hoursAndMinutes", tableName: nil, bundle: LocalizationManager.shared.localizedBundle, value: "%@h %@min", comment: ""), "\(hours)", "\(minutes)")
        }
    }

    // MARK: - Error Messages
    enum Errors {
        // Route Errors
        static var routeNotFound: String { String(localized: "error.route.notFound", defaultValue: "Route not found", bundle: LocalizationManager.shared.localizedBundle) }
        static var routeLoadFailed: String { String(localized: "error.route.loadFailed", defaultValue: "Failed to load route", bundle: LocalizationManager.shared.localizedBundle) }
        static var invalidRoute: String { String(localized: "error.route.invalid", defaultValue: "Invalid route data", bundle: LocalizationManager.shared.localizedBundle) }

        // Network Errors
        static var networkUnavailable: String { String(localized: "error.network.unavailable", defaultValue: "Network connection unavailable", bundle: LocalizationManager.shared.localizedBundle) }
        static var requestFailed: String { String(localized: "error.network.requestFailed", defaultValue: "Request failed", bundle: LocalizationManager.shared.localizedBundle) }
        static var serverError: String { String(localized: "error.network.serverError", defaultValue: "Server error", bundle: LocalizationManager.shared.localizedBundle) }

        // Navigation Errors
        static var navigationNotAvailable: String { String(localized: "error.navigation.notAvailable", defaultValue: "Navigation not available", bundle: LocalizationManager.shared.localizedBundle) }
        static var locationPermissionDenied: String { String(localized: "error.navigation.locationPermissionDenied", defaultValue: "Location permission denied", bundle: LocalizationManager.shared.localizedBundle) }

        // POI Errors
        static var poiNotFound: String { String(localized: "error.poi.notFound", defaultValue: "Point of interest not found", bundle: LocalizationManager.shared.localizedBundle) }
        static var poiDataInvalid: String { String(localized: "error.poi.dataInvalid", defaultValue: "Invalid point of interest data", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Share Messages
    enum Share {
        static var discoveringRoutes: String { String(localized: "share.discoveringRoutes", defaultValue: "I've been discovering new walks with Looopr! Check it out:", bundle: LocalizationManager.shared.localizedBundle) }
        static var checkOutRoute: String { String(localized: "share.checkOutRoute", defaultValue: "Check out this walking route on Looopr!", bundle: LocalizationManager.shared.localizedBundle) }

        static func walkedRoute(_ name: String) -> String {
            return String(format: NSLocalizedString("share.walkedRoute", tableName: nil, bundle: LocalizationManager.shared.localizedBundle, value: "I just walked the %@ with Looopr!", comment: ""), name)
        }
    }

    // MARK: - Miscellaneous
    enum Misc {
        static var walker: String { String(localized: "misc.walker", defaultValue: "Walker", bundle: LocalizationManager.shared.localizedBundle) }
        static var walk: String { String(localized: "misc.walk", defaultValue: "Walk", bundle: LocalizationManager.shared.localizedBundle) }
        static var name: String { String(localized: "misc.name", defaultValue: "Name", bundle: LocalizationManager.shared.localizedBundle) }
        static var loading: String { String(localized: "misc.loading", defaultValue: "Loading...", bundle: LocalizationManager.shared.localizedBundle) }
        static var error: String { String(localized: "misc.error", defaultValue: "Error", bundle: LocalizationManager.shared.localizedBundle) }
        static var retry: String { String(localized: "misc.retry", defaultValue: "Retry", bundle: LocalizationManager.shared.localizedBundle) }
        static var okay: String { String(localized: "misc.okay", defaultValue: "OK", bundle: LocalizationManager.shared.localizedBundle) }
        static var done: String { String(localized: "misc.done", defaultValue: "Done", bundle: LocalizationManager.shared.localizedBundle) }
        static var now: String { String(localized: "misc.now", defaultValue: "Now", bundle: LocalizationManager.shared.localizedBundle) }
        static var yes: String { String(localized: "misc.yes", defaultValue: "Yes", bundle: LocalizationManager.shared.localizedBundle) }
        static var no: String { String(localized: "misc.no", defaultValue: "No", bundle: LocalizationManager.shared.localizedBundle) }
        static var close: String { String(localized: "misc.close", defaultValue: "Close", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Off-Route Banner
    enum OffRoute {
        static var offRoute: String { String(localized: "offRoute.offRoute", defaultValue: "You're off the route", bundle: LocalizationManager.shared.localizedBundle) }
        static var returnToRoute: String { String(localized: "offRoute.returnToRoute", defaultValue: "Return to the marked path", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Feedback
    enum Feedback {
        static var howWasWalk: String { String(localized: "feedback.howWasWalk", defaultValue: "How was your walk?", bundle: LocalizationManager.shared.localizedBundle) }
    }

    // MARK: - Language Restart Prompt
    enum LanguageRestart {
        static var title: String { String(localized: "languageRestart.title", defaultValue: "Language Changed", bundle: LocalizationManager.shared.localizedBundle) }
        static var message: String { String(localized: "languageRestart.message", defaultValue: "The app needs to restart for the language change to take effect.", bundle: LocalizationManager.shared.localizedBundle) }
        static var restartLater: String { String(localized: "languageRestart.restartLater", defaultValue: "Restart Later", bundle: LocalizationManager.shared.localizedBundle) }
        static var restart: String { String(localized: "languageRestart.restart", defaultValue: "OK", bundle: LocalizationManager.shared.localizedBundle) }
    }
}
