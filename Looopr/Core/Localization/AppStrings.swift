import Foundation

// MARK: - Localization String Constants

enum L10n {
    // MARK: - Tab Navigation
    enum Tab {
        static var home: String { String(localized: "tab.home", defaultValue: "Home", bundle: LocalizationManager.bundle) }
        static var explore: String { String(localized: "tab.explore", defaultValue: "Explore", bundle: LocalizationManager.bundle) }
        static var savedRoutes: String { String(localized: "tab.savedRoutes", defaultValue: "Saved", bundle: LocalizationManager.bundle) }
        static var profile: String { String(localized: "tab.profile", defaultValue: "Profile", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Home Screen
    enum Home {
        static var title: String { String(localized: "home.title", defaultValue: "Home", bundle: LocalizationManager.bundle) }
        static var readyToLooopr: String { String(localized: "home.readyToLooopr", defaultValue: "Ready to Looopr?", bundle: LocalizationManager.bundle) }
        static var howLongWalk: String { String(localized: "home.howLongWalk", defaultValue: "How long do you want to walk?", bundle: LocalizationManager.bundle) }
        static var duration15min: String { String(localized: "home.duration.15min", defaultValue: "15min", bundle: LocalizationManager.bundle) }
        static var duration3h: String { String(localized: "home.duration.3h", defaultValue: "3h", bundle: LocalizationManager.bundle) }
        static var walkingPace: String { String(localized: "home.walkingPace", defaultValue: "WALKING PACE", bundle: LocalizationManager.bundle) }
        static var findMyLooopr: String { String(localized: "home.findMyLooopr", defaultValue: "Find My Looopr", bundle: LocalizationManager.bundle) }
        static var savedLoooprs: String { String(localized: "home.savedLoooprs", defaultValue: "Saved Loooprs", bundle: LocalizationManager.bundle) }
        static var viewAll: String { String(localized: "home.viewAll", defaultValue: "VIEW ALL", bundle: LocalizationManager.bundle) }
        static var noSavedRoutes: String { String(localized: "home.noSavedRoutes", defaultValue: "No saved routes yet", bundle: LocalizationManager.bundle) }
        static var bookmarkRoutesDescription: String { String(localized: "home.bookmarkRoutesDescription", defaultValue: "Bookmark routes you love and they'll appear here", bundle: LocalizationManager.bundle) }
        static var recentLoooprs: String { String(localized: "home.recentLoooprs", defaultValue: "Recent Loooprs", bundle: LocalizationManager.bundle) }
        static var goodMorning: String { String(localized: "home.greeting.morning", defaultValue: "Good morning", bundle: LocalizationManager.bundle) }
        static var goodAfternoon: String { String(localized: "home.greeting.afternoon", defaultValue: "Good afternoon", bundle: LocalizationManager.bundle) }
        static var goodEvening: String { String(localized: "home.greeting.evening", defaultValue: "Good evening", bundle: LocalizationManager.bundle) }
        static var currentLocation: String { String(localized: "home.currentLocation", defaultValue: "Current Location", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Authentication
    enum Auth {
        static var welcome: String { String(localized: "auth.welcome", defaultValue: "Welcome to Looopr", bundle: LocalizationManager.bundle) }
        static var discoverRoutesDescription: String { String(localized: "auth.discoverRoutesDescription", defaultValue: "Discover walking routes around you", bundle: LocalizationManager.bundle) }
        static var continueWithoutAccount: String { String(localized: "auth.continueWithoutAccount", defaultValue: "Continue without an account", bundle: LocalizationManager.bundle) }
        static var signInToShare: String { String(localized: "auth.signInToShare", defaultValue: "Sign in to share routes with a link.", bundle: LocalizationManager.bundle) }
        static var signInToSendFeedback: String { String(localized: "auth.signInToSendFeedback", defaultValue: "Sign in to send us feedback.", bundle: LocalizationManager.bundle) }
        static var signInToSync: String { String(localized: "auth.signInToSync", defaultValue: "Sign in to back up your walks and saved routes, and use them on your other devices.", bundle: LocalizationManager.bundle) }
        static var signInGoogle: String { String(localized: "auth.signInGoogle", defaultValue: "Sign in with Google", bundle: LocalizationManager.bundle) }
        static var signingIn: String { String(localized: "auth.signingIn", defaultValue: "Signing in...", bundle: LocalizationManager.bundle) }
        static var appleIDCredentialsFailed: String { String(localized: "auth.appleIDCredentialsFailed", defaultValue: "Failed to get Apple ID credentials.", bundle: LocalizationManager.bundle) }
        static var privacyAgreement: String { String(localized: "auth.privacyAgreement", defaultValue: "By signing in, you agree to our [Privacy Policy](https://looopr.app/privacy.html). We collect your name, email, saved routes, and walk history to provide the service.", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Route Names
    enum RouteName {
        static var loop: String { String(localized: "routeName.loop", defaultValue: "Loop", bundle: LocalizationManager.bundle) }
        static var north: String { String(localized: "routeName.north", defaultValue: "North", bundle: LocalizationManager.bundle) }
        static var northeast: String { String(localized: "routeName.northeast", defaultValue: "Northeast", bundle: LocalizationManager.bundle) }
        static var east: String { String(localized: "routeName.east", defaultValue: "East", bundle: LocalizationManager.bundle) }
        static var southeast: String { String(localized: "routeName.southeast", defaultValue: "Southeast", bundle: LocalizationManager.bundle) }
        static var south: String { String(localized: "routeName.south", defaultValue: "South", bundle: LocalizationManager.bundle) }
        static var southwest: String { String(localized: "routeName.southwest", defaultValue: "Southwest", bundle: LocalizationManager.bundle) }
        static var west: String { String(localized: "routeName.west", defaultValue: "West", bundle: LocalizationManager.bundle) }
        static var northwest: String { String(localized: "routeName.northwest", defaultValue: "Northwest", bundle: LocalizationManager.bundle) }

        /// Word order of a route name. %1$@ is the direction, %2$@ is the loop word.
        /// English/German put the direction first ("East Loop"); Dutch and the Romance
        /// languages put the loop word first ("Rondje Oost", "Boucle Est").
        static var format: String { String(localized: "routeName.format", defaultValue: "%1$@ %2$@", bundle: LocalizationManager.bundle) }

        /// Composes a display name from a localized direction and loop word using the
        /// language's word order.
        static func compose(direction: String, loop loopWord: String) -> String {
            String(format: format, locale: nil, direction, loopWord)
        }

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
                        return compose(direction: entry.localized(), loop: loop)
                    }
                    return compose(direction: entry.localized(), loop: suffix)
                }
            }
            return englishName
        }
    }


    // MARK: - Route Selection
    enum RouteSelection {
        static var yourRoutes: String { String(localized: "routeSelection.yourRoutes", defaultValue: "Your Routes", bundle: LocalizationManager.bundle) }
        static var walkLabel: String { String(localized: "routeSelection.walkLabel", defaultValue: "walk", bundle: LocalizationManager.bundle) }
        static var noRoutesFound: String { String(localized: "routeSelection.noRoutesFound", defaultValue: "No routes found nearby", bundle: LocalizationManager.bundle) }
        static var findingMore: String { String(localized: "routeSelection.findingMore", defaultValue: "Finding more routes…", bundle: LocalizationManager.bundle) }
        static var noRoutesBody: String { String(localized: "routeSelection.noRoutesBody", defaultValue: "We couldn't build a loop this short from here. Shorter walks are the hardest to fit — a longer one usually works.", bundle: LocalizationManager.bundle) }
        static var noRoutesBodyShort: String { String(localized: "routeSelection.noRoutesBodyShort", defaultValue: "We couldn't build a loop of this length from here. Try again, or start from a different spot.", bundle: LocalizationManager.bundle) }
        static var searchFailedBody: String { String(localized: "routeSelection.searchFailedBody", defaultValue: "Something went wrong while finding routes. Check your connection and try again.", bundle: LocalizationManager.bundle) }
        static var locationUnavailableTitle: String { String(localized: "routeSelection.locationUnavailableTitle", defaultValue: "Couldn't find your location", bundle: LocalizationManager.bundle) }
        static var locationUnavailableBody: String { String(localized: "routeSelection.locationUnavailableBody", defaultValue: "Routes start from where you are. Make sure Location is allowed for Looopr, then try again.", bundle: LocalizationManager.bundle) }
        static var tryAgain: String { String(localized: "routeSelection.tryAgain", defaultValue: "Try again", bundle: LocalizationManager.bundle) }
        static var chooseStartingPoint: String { String(localized: "routeSelection.chooseStartingPoint", defaultValue: "Choose a starting point", bundle: LocalizationManager.bundle) }
        static var openSettings: String { String(localized: "routeSelection.openSettings", defaultValue: "Open Settings", bundle: LocalizationManager.bundle) }
        static var locationDeniedBody: String { String(localized: "routeSelection.locationDeniedBody", defaultValue: "Location access is off for Looopr. Turn it on in Settings, or choose a starting point to plan a loop from there.", bundle: LocalizationManager.bundle) }
        static var stillSearching: String { String(localized: "routeSelection.stillSearching", defaultValue: "Still finding the best loops around you…", bundle: LocalizationManager.bundle) }
        static var searchTimedOutTitle: String { String(localized: "routeSelection.searchTimedOutTitle", defaultValue: "This is taking too long", bundle: LocalizationManager.bundle) }
        static var searchTimedOutBody: String { String(localized: "routeSelection.searchTimedOutBody", defaultValue: "Finding routes is slower than usual right now. Check your connection and try again.", bundle: LocalizationManager.bundle) }
        static func closestMatches(_ duration: String) -> String {
            String(format: NSLocalizedString("routeSelection.closestMatches", tableName: nil, bundle: LocalizationManager.bundle, value: "There's no %@ loop from here. These are the closest we found.", comment: ""), duration)
        }
        static func tryLongerWalk(_ duration: String) -> String {
            String(format: NSLocalizedString("routeSelection.tryLongerWalk", tableName: nil, bundle: LocalizationManager.bundle, value: "Try a %@ walk", comment: ""), duration)
        }
        static var upgradeTitle: String { String(localized: "routeSelection.upgradeTitle", defaultValue: "Want more options?", bundle: LocalizationManager.bundle) }
        static var upgradeBody: String { String(localized: "routeSelection.upgradeBody", defaultValue: "Looopr Pro finds up to 8 loops per walk and shows the cafés along the way. The first week is free.", bundle: LocalizationManager.bundle) }
        static var upgradeCTA: String { String(localized: "routeSelection.upgradeCTA", defaultValue: "Try Pro free", bundle: LocalizationManager.bundle) }
        static var loopLabel: String { String(localized: "routeSelection.loopLabel", defaultValue: "loop", bundle: LocalizationManager.bundle) }
        static var includesFerry: String { String(localized: "routeSelection.includesFerry", defaultValue: "Includes ferry crossing", bundle: LocalizationManager.bundle) }
        static var startWalk: String { String(localized: "routeSelection.startWalk", defaultValue: "Start Walk", bundle: LocalizationManager.bundle) }
        static var statDistance: String { String(localized: "routeSelection.statDistance", defaultValue: "Distance", bundle: LocalizationManager.bundle) }
        static var statTime: String { String(localized: "routeSelection.statTime", defaultValue: "Time", bundle: LocalizationManager.bundle) }
        static func subtitleFinding(_ value: String) -> String {
            String(format: NSLocalizedString("routeSelection.subtitleFinding", tableName: nil, bundle: LocalizationManager.bundle, value: "Finding routes · %@ walk", comment: ""), value)
        }
        static func lockedTitle(count: Int) -> String {
            if count == 1 {
                return NSLocalizedString("routeSelection.lockedTitle.one", tableName: nil, bundle: LocalizationManager.bundle, value: "1 more loop with Pro", comment: "")
            }
            return String(format: NSLocalizedString("routeSelection.lockedTitle.other", tableName: nil, bundle: LocalizationManager.bundle, value: "%@ more loops with Pro", comment: ""), "\(count)")
        }
        static var lockedBody: String { String(localized: "routeSelection.lockedBody", defaultValue: "Looopr found these for your walk too. Pro unlocks them, plus the cafés along the way.", bundle: LocalizationManager.bundle) }
        static var lockedCTA: String { String(localized: "routeSelection.lockedCTA", defaultValue: "Try Pro free for a week", bundle: LocalizationManager.bundle) }
        static var lockedRowTitle: String { String(localized: "routeSelection.lockedRowTitle", defaultValue: "Another loop", bundle: LocalizationManager.bundle) }
        static var viewMap: String { String(localized: "routeSelection.viewMap", defaultValue: "View map", bundle: LocalizationManager.bundle) }
        static var poiRowTitlePro: String { String(localized: "routeSelection.poiRowTitlePro", defaultValue: "Sights and cafés along this loop", bundle: LocalizationManager.bundle) }
        static var poiRowSubtitlePro: String { String(localized: "routeSelection.poiRowSubtitlePro", defaultValue: "See them on the map", bundle: LocalizationManager.bundle) }
        static var poiRowTitleFree: String { String(localized: "routeSelection.poiRowTitleFree", defaultValue: "Sights along this loop", bundle: LocalizationManager.bundle) }
        static var poiRowSubtitleFree: String { String(localized: "routeSelection.poiRowSubtitleFree", defaultValue: "Cafés unlock with Pro", bundle: LocalizationManager.bundle) }
        static func subtitleFound(count: Int, duration: String) -> String {
            if count == 1 {
                return String(format: NSLocalizedString("routeSelection.subtitleFound.one", tableName: nil, bundle: LocalizationManager.bundle, value: "1 route found · %@ walk", comment: ""), duration)
            }
            return String(format: NSLocalizedString("routeSelection.subtitleFound.other", tableName: nil, bundle: LocalizationManager.bundle, value: "%1$@ routes found · %2$@ walk", comment: ""), "\(count)", duration)
        }
    }

    // MARK: - Route Detail
    enum RouteDetail {
        static var startThisLooopr: String { String(localized: "routeDetail.startThisLooopr", defaultValue: "Start This Looopr", bundle: LocalizationManager.bundle) }
        static var foodStopNearby: String { String(localized: "routeDetail.foodStopNearby", defaultValue: "There's already a food stop nearby — consider one further along the route", bundle: LocalizationManager.bundle) }

        static func foodStopsAdded(_ count: Int) -> String {
            if count == 1 {
                return String(localized: "routeDetail.foodStops.singular", defaultValue: "1 food stop added", bundle: LocalizationManager.bundle)
            } else {
                return String(format: NSLocalizedString("routeDetail.foodStops.plural", tableName: nil, bundle: LocalizationManager.bundle, value: "%@ food stop(s) added", comment: ""), "\(count)")
            }
        }

        static var aboutThisRoute: String { String(localized: "routeDetail.aboutThisRoute", defaultValue: "ABOUT THIS ROUTE", bundle: LocalizationManager.bundle) }
        static var loopDuration: String { String(localized: "routeDetail.loopDuration", defaultValue: "loop", bundle: LocalizationManager.bundle) }
        static var includeFerryDescription: String { String(localized: "routeDetail.includeFerryDescription", defaultValue: "This route includes a ferry crossing", bundle: LocalizationManager.bundle) }
        static var leavingTime: String { String(localized: "routeDetail.leavingTime", defaultValue: "Leaving time", bundle: LocalizationManager.bundle) }
        static var findingNearbyAttractions: String { String(localized: "routeDetail.findingNearbyAttractions", defaultValue: "Finding nearby attractions...", bundle: LocalizationManager.bundle) }
        static var sightsUnavailable: String { String(localized: "routeDetail.sightsUnavailable", defaultValue: "Couldn't load the sights along this loop.", bundle: LocalizationManager.bundle) }
        static var findingMoreSights: String { String(localized: "routeDetail.findingMoreSights", defaultValue: "Finding more sights…", bundle: LocalizationManager.bundle) }
        static var pointsOfInterest: String { String(localized: "routeDetail.pointsOfInterest", defaultValue: "POINTS OF INTEREST", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Points of Interest (POI)
    enum POI {
        static var onRoute: String { String(localized: "poi.onRoute", defaultValue: "On Route", bundle: LocalizationManager.bundle) }
        static var nearRoute: String { String(localized: "poi.nearRoute", defaultValue: "Near Route", bundle: LocalizationManager.bundle) }
        static var foodAndDrinks: String { String(localized: "poi.foodAndDrinks", defaultValue: "Food & Drinks", bundle: LocalizationManager.bundle) }
        static func todayHours(_ hours: String) -> String {
            String(format: NSLocalizedString("poi.todayHours", tableName: nil, bundle: LocalizationManager.bundle, value: "Today: %@", comment: ""), hours)
        }
        static var cafes: String { String(localized: "poi.cafes", defaultValue: "Cafes", bundle: LocalizationManager.bundle) }
        static var restaurants: String { String(localized: "poi.restaurants", defaultValue: "Restaurants", bundle: LocalizationManager.bundle) }
        static var findingNearby: String { String(localized: "poi.findingNearby", defaultValue: "Finding nearby cafes & restaurants...", bundle: LocalizationManager.bundle) }
        static var noRestaurantsFound: String { String(localized: "poi.noRestaurantsFound", defaultValue: "No highly-rated cafes or restaurants found nearby", bundle: LocalizationManager.bundle) }
        static var tapToFind: String { String(localized: "poi.tapToFind", defaultValue: "Tap to find nearby cafes & restaurants", bundle: LocalizationManager.bundle) }

        /// Distance along the route paired with a rough walking time, e.g. "2.1 km · ~25min walk".
        static func walkingInfo(distance: String, time: String) -> String {
            return String(format: NSLocalizedString("poi.walkingInfo", tableName: nil, bundle: LocalizationManager.bundle, value: "%1$@ · %2$@ walk", comment: ""), distance, time)
        }

        static var walkTimeUnderMinute: String { String(localized: "poi.walkTimeUnderMinute", defaultValue: "<1min", bundle: LocalizationManager.bundle) }

        static func walkTimeMinutes(_ minutes: Int) -> String {
            return String(format: NSLocalizedString("poi.walkTimeMinutes", tableName: nil, bundle: LocalizationManager.bundle, value: "~%@min", comment: ""), "\(minutes)")
        }

        static func walkTimeHours(_ hours: Int) -> String {
            return String(format: NSLocalizedString("poi.walkTimeHours", tableName: nil, bundle: LocalizationManager.bundle, value: "~%@h", comment: ""), "\(hours)")
        }

        static func walkTimeHoursMinutes(_ hours: Int, _ minutes: Int) -> String {
            return String(format: NSLocalizedString("poi.walkTimeHoursMinutes", tableName: nil, bundle: LocalizationManager.bundle, value: "~%1$@h %2$@min", comment: ""), "\(hours)", "\(minutes)")
        }
        static var foodLockedTitle: String { String(localized: "poi.foodLockedTitle", defaultValue: "Cafés & restaurants are Pro", bundle: LocalizationManager.bundle) }
        static var foodLockedBody: String { String(localized: "poi.foodLockedBody", defaultValue: "See the best coffee and food stops along this route, with ratings and opening hours. The first week is free.", bundle: LocalizationManager.bundle) }
        static var foodLockedCTA: String { String(localized: "poi.foodLockedCTA", defaultValue: "Try Pro free", bundle: LocalizationManager.bundle) }
        static var fromRoute: String { String(localized: "poi.fromRoute", defaultValue: "from route", bundle: LocalizationManager.bundle) }
        static var walkTime: String { String(localized: "poi.walkTime", defaultValue: "walk", bundle: LocalizationManager.bundle) }
        static var openNow: String { String(localized: "poi.openNow", defaultValue: "Open now", bundle: LocalizationManager.bundle) }
        static var openThen: String { String(localized: "poi.openThen", defaultValue: "Open then", bundle: LocalizationManager.bundle) }
        static var openingSoon: String { String(localized: "poi.openingSoon", defaultValue: "Opening soon", bundle: LocalizationManager.bundle) }
        static var closed: String { String(localized: "poi.closed", defaultValue: "Closed", bundle: LocalizationManager.bundle) }
        static var closedThen: String { String(localized: "poi.closedThen", defaultValue: "Closed then", bundle: LocalizationManager.bundle) }
        static var googleMaps: String { String(localized: "poi.googleMaps", defaultValue: "Google Maps", bundle: LocalizationManager.bundle) }
        static var appleMaps: String { String(localized: "poi.appleMaps", defaultValue: "Apple Maps", bundle: LocalizationManager.bundle) }

        // MARK: - POI Categories
        enum Category {
            static var museum: String { String(localized: "poi.category.museum", defaultValue: "Museum", bundle: LocalizationManager.bundle) }
            static var monument: String { String(localized: "poi.category.monument", defaultValue: "Monument", bundle: LocalizationManager.bundle) }
            static var historicSite: String { String(localized: "poi.category.historicSite", defaultValue: "Historic Site", bundle: LocalizationManager.bundle) }
            static var church: String { String(localized: "poi.category.church", defaultValue: "Church", bundle: LocalizationManager.bundle) }
            static var castle: String { String(localized: "poi.category.castle", defaultValue: "Castle", bundle: LocalizationManager.bundle) }
            static var park: String { String(localized: "poi.category.park", defaultValue: "Park", bundle: LocalizationManager.bundle) }
            static var garden: String { String(localized: "poi.category.garden", defaultValue: "Garden", bundle: LocalizationManager.bundle) }
            static var gallery: String { String(localized: "poi.category.gallery", defaultValue: "Gallery", bundle: LocalizationManager.bundle) }
            static var theater: String { String(localized: "poi.category.theater", defaultValue: "Theater", bundle: LocalizationManager.bundle) }
            static var zoo: String { String(localized: "poi.category.zoo", defaultValue: "Zoo", bundle: LocalizationManager.bundle) }
            static var aquarium: String { String(localized: "poi.category.aquarium", defaultValue: "Aquarium", bundle: LocalizationManager.bundle) }
            static var landmark: String { String(localized: "poi.category.landmark", defaultValue: "Landmark", bundle: LocalizationManager.bundle) }
            static var viewpoint: String { String(localized: "poi.category.viewpoint", defaultValue: "Viewpoint", bundle: LocalizationManager.bundle) }
            static var restaurant: String { String(localized: "poi.category.restaurant", defaultValue: "Restaurant", bundle: LocalizationManager.bundle) }
            static var cafe: String { String(localized: "poi.category.cafe", defaultValue: "Café", bundle: LocalizationManager.bundle) }
            static var bakery: String { String(localized: "poi.category.bakery", defaultValue: "Bakery", bundle: LocalizationManager.bundle) }
            static var bar: String { String(localized: "poi.category.bar", defaultValue: "Bar", bundle: LocalizationManager.bundle) }
            static var other: String { String(localized: "poi.category.other", defaultValue: "Other", bundle: LocalizationManager.bundle) }
        }

        /// Fallback one-line descriptions when Google Places has no editorial summary.
        enum CategoryDescription {
            static var museum: String { String(localized: "poi.categoryDescription.museum", defaultValue: "Museum and cultural exhibition", bundle: LocalizationManager.bundle) }
            static var monument: String { String(localized: "poi.categoryDescription.monument", defaultValue: "Historic monument and memorial", bundle: LocalizationManager.bundle) }
            static var historicSite: String { String(localized: "poi.categoryDescription.historicSite", defaultValue: "Historic site of cultural significance", bundle: LocalizationManager.bundle) }
            static var church: String { String(localized: "poi.categoryDescription.church", defaultValue: "Church and place of worship", bundle: LocalizationManager.bundle) }
            static var castle: String { String(localized: "poi.categoryDescription.castle", defaultValue: "Castle and historic fortification", bundle: LocalizationManager.bundle) }
            static var park: String { String(localized: "poi.categoryDescription.park", defaultValue: "Park and green space", bundle: LocalizationManager.bundle) }
            static var garden: String { String(localized: "poi.categoryDescription.garden", defaultValue: "Garden and botanical area", bundle: LocalizationManager.bundle) }
            static var gallery: String { String(localized: "poi.categoryDescription.gallery", defaultValue: "Art gallery and exhibition space", bundle: LocalizationManager.bundle) }
            static var theater: String { String(localized: "poi.categoryDescription.theater", defaultValue: "Theater and performing arts venue", bundle: LocalizationManager.bundle) }
            static var zoo: String { String(localized: "poi.categoryDescription.zoo", defaultValue: "Zoo and wildlife park", bundle: LocalizationManager.bundle) }
            static var aquarium: String { String(localized: "poi.categoryDescription.aquarium", defaultValue: "Aquarium and marine life center", bundle: LocalizationManager.bundle) }
            static var landmark: String { String(localized: "poi.categoryDescription.landmark", defaultValue: "Notable landmark and point of interest", bundle: LocalizationManager.bundle) }
            static var viewpoint: String { String(localized: "poi.categoryDescription.viewpoint", defaultValue: "Scenic viewpoint", bundle: LocalizationManager.bundle) }
            static var restaurant: String { String(localized: "poi.categoryDescription.restaurant", defaultValue: "Restaurant", bundle: LocalizationManager.bundle) }
            static var cafe: String { String(localized: "poi.categoryDescription.cafe", defaultValue: "Cafe and coffee house", bundle: LocalizationManager.bundle) }
            static var bakery: String { String(localized: "poi.categoryDescription.bakery", defaultValue: "Bakery and pastry shop", bundle: LocalizationManager.bundle) }
            static var bar: String { String(localized: "poi.categoryDescription.bar", defaultValue: "Bar and lounge", bundle: LocalizationManager.bundle) }
            static var other: String { String(localized: "poi.categoryDescription.other", defaultValue: "Point of interest", bundle: LocalizationManager.bundle) }
        }
    }

    // MARK: - POI Detail
    enum POIDetail {
        static var loadingDetails: String { String(localized: "poiDetail.loadingDetails", defaultValue: "Loading details...", bundle: LocalizationManager.bundle) }
        static var hours: String { String(localized: "poiDetail.hours", defaultValue: "Hours", bundle: LocalizationManager.bundle) }
        static var admission: String { String(localized: "poiDetail.admission", defaultValue: "Admission", bundle: LocalizationManager.bundle) }
        static var phone: String { String(localized: "poiDetail.phone", defaultValue: "Phone", bundle: LocalizationManager.bundle) }
        static var accessibility: String { String(localized: "poiDetail.accessibility", defaultValue: "Accessibility", bundle: LocalizationManager.bundle) }

        static var viewOnGoogleMaps: String { String(localized: "poiDetail.viewOnGoogleMaps", defaultValue: "View on Google Maps", bundle: LocalizationManager.bundle) }
        static var bookTickets: String { String(localized: "poiDetail.bookTickets", defaultValue: "Book Tickets", bundle: LocalizationManager.bundle) }

        static var visitWebsite: String { String(localized: "poiDetail.visitWebsite", defaultValue: "Visit Website", bundle: LocalizationManager.bundle) }
        static var call: String { String(localized: "poiDetail.call", defaultValue: "Call", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Walk Navigation
    enum WalkNavigation {
        static var endWalk: String { String(localized: "walkNavigation.endWalk", defaultValue: "End walk?", bundle: LocalizationManager.bundle) }
        static var endWalkButton: String { String(localized: "walkNavigation.endWalkButton", defaultValue: "End Walk", bundle: LocalizationManager.bundle) }
        static var progressNotSaved: String { String(localized: "walkNavigation.progressNotSaved", defaultValue: "Your progress will not be saved.", bundle: LocalizationManager.bundle) }
        static var preparingNavigation: String { String(localized: "walkNavigation.preparingNavigation", defaultValue: "Preparing navigation...", bundle: LocalizationManager.bundle) }
        static var nearby: String { String(localized: "walkNavigation.nearby", defaultValue: "Nearby", bundle: LocalizationManager.bundle) }
        static var checkIn: String { String(localized: "walkNavigation.checkIn", defaultValue: "Check in", bundle: LocalizationManager.bundle) }
        static var finishWalk: String { String(localized: "walkNavigation.finishWalk", defaultValue: "Finish Walk", bundle: LocalizationManager.bundle) }
        static var remaining: String { String(localized: "walkNavigation.remaining", defaultValue: "remaining", bundle: LocalizationManager.bundle) }
        static var statTime: String { String(localized: "walkNavigation.statTime", defaultValue: "Time", bundle: LocalizationManager.bundle) }
        static var statDistance: String { String(localized: "walkNavigation.statDistance", defaultValue: "Distance", bundle: LocalizationManager.bundle) }
        static var statRemaining: String { String(localized: "walkNavigation.statRemaining", defaultValue: "Remaining", bundle: LocalizationManager.bundle) }
        static var routeUpdated: String { String(localized: "walkNavigation.routeUpdated", defaultValue: "Route updated", bundle: LocalizationManager.bundle) }
        static var routeFlipping: String { String(localized: "walkNavigation.routeFlipping", defaultValue: "Flipping route...", bundle: LocalizationManager.bundle) }
        static var arrived: String { String(localized: "walkNavigation.arrived", defaultValue: "You've arrived!", bundle: LocalizationManager.bundle) }
        static var saveAndFinish: String { String(localized: "walkNavigation.saveAndFinish", defaultValue: "Save & Finish", bundle: LocalizationManager.bundle) }
        static var routeFlipped: String { String(localized: "walkNavigation.routeFlipped", defaultValue: "Route flipped — enjoy the walk!", bundle: LocalizationManager.bundle) }
        static var routeFlipFailed: String { String(localized: "walkNavigation.routeFlipFailed", defaultValue: "Couldn't flip route. Try again in a moment.", bundle: LocalizationManager.bundle) }
        static var recenter: String { String(localized: "walkNavigation.recenter", defaultValue: "Re-center", bundle: LocalizationManager.bundle) }
        static var approaching: String { String(localized: "walkNavigation.approaching", defaultValue: "APPROACHING", bundle: LocalizationManager.bundle) }

        /// Preview of the instruction after the current one, e.g. "Then turn left onto Keizersgracht".
        static func thenInstruction(_ instruction: String) -> String {
            return String(format: NSLocalizedString("walkNavigation.thenInstruction", tableName: nil, bundle: LocalizationManager.bundle, value: "Then %@", comment: ""), instruction)
        }

        static func percentComplete(_ percent: Int) -> String {
            return String(format: NSLocalizedString("walkNavigation.percentComplete", tableName: nil, bundle: LocalizationManager.bundle, value: "%@%% complete", comment: ""), "\(percent)")
        }

        /// Rough walking time to an upcoming point of interest.
        static func approximateMinutes(_ minutes: Int) -> String {
            return String(format: NSLocalizedString("walkNavigation.approximateMinutes", tableName: nil, bundle: LocalizationManager.bundle, value: "~%@ min", comment: ""), "\(minutes)")
        }
    }

    // MARK: - Food Check-in
    enum FoodCheckIn {
        static func nearestFood(_ name: String) -> String {
            return String(format: NSLocalizedString("foodCheckIn.nearestFood", tableName: nil, bundle: LocalizationManager.bundle, value: "You're near %@", comment: ""), name)
        }

        static var stoppingForBreak: String { String(localized: "foodCheckIn.stoppingForBreak", defaultValue: "Stopping for a break?", bundle: LocalizationManager.bundle) }
        static var checkInButton: String { String(localized: "foodCheckIn.checkInButton", defaultValue: "Check in", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Wrong Way Alert
    enum WrongWay {
        static var title: String { String(localized: "wrongWay.title", defaultValue: "Walking the other way?", bundle: LocalizationManager.bundle) }
        static var message: String { String(localized: "wrongWay.message", defaultValue: "Looks like you're heading in the opposite direction. Want to flip the route to match?", bundle: LocalizationManager.bundle) }
        static var flipRoute: String { String(localized: "wrongWay.flipRoute", defaultValue: "Yes, flip route", bundle: LocalizationManager.bundle) }
        static var turnAround: String { String(localized: "wrongWay.turnAround", defaultValue: "No, stay as is", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Finish Walk
    enum FinishWalk {
        static func shareCompleted(distance: String, duration: String) -> String {
            String(format: NSLocalizedString("finishWalk.shareCompleted", tableName: nil, bundle: LocalizationManager.bundle, value: "Just walked %1$@ in %2$@ with Looopr!", comment: ""), distance, duration)
        }
        static func shareSteps(_ steps: String) -> String {
            String(format: NSLocalizedString("finishWalk.shareSteps", tableName: nil, bundle: LocalizationManager.bundle, value: "%@ steps.", comment: ""), steps)
        }
        static func shareFoodStops(_ count: Int) -> String {
            if count == 1 {
                return NSLocalizedString("finishWalk.shareFoodStops.one", tableName: nil, bundle: LocalizationManager.bundle, value: "Stopped at 1 café or restaurant.", comment: "")
            }
            return String(format: NSLocalizedString("finishWalk.shareFoodStops.other", tableName: nil, bundle: LocalizationManager.bundle, value: "Stopped at %@ cafés and restaurants.", comment: ""), "\(count)")
        }
        static var backupTitle: String { String(localized: "finishWalk.backupTitle", defaultValue: "Keep your walks safe", bundle: LocalizationManager.bundle) }
        static var backupNotNow: String { String(localized: "finishWalk.backupNotNow", defaultValue: "Not now", bundle: LocalizationManager.bundle) }
        static var title: String { String(localized: "finishWalk.title", defaultValue: "Looopr Complete!", bundle: LocalizationManager.bundle) }
        static var breaks: String { String(localized: "finishWalk.breaks", defaultValue: "BREAKS", bundle: LocalizationManager.bundle) }

        static func breakAt(_ name: String) -> String {
            return String(format: NSLocalizedString("finishWalk.breakAt", tableName: nil, bundle: LocalizationManager.bundle, value: "A break at %@", comment: ""), name)
        }

        static var share: String { String(localized: "finishWalk.share", defaultValue: "Share", bundle: LocalizationManager.bundle) }
        static var save: String { String(localized: "finishWalk.save", defaultValue: "Save", bundle: LocalizationManager.bundle) }
        static var saved: String { String(localized: "finishWalk.saved", defaultValue: "Saved!", bundle: LocalizationManager.bundle) }
        static var shareLooopr: String { String(localized: "finishWalk.shareLooopr", defaultValue: "Share Looopr", bundle: LocalizationManager.bundle) }
        static var saveRoute: String { String(localized: "finishWalk.saveRoute", defaultValue: "Save Route", bundle: LocalizationManager.bundle) }
        static var routeSaved: String { String(localized: "finishWalk.routeSaved", defaultValue: "Route Saved", bundle: LocalizationManager.bundle) }
        static var shareRoute: String { String(localized: "finishWalk.shareRoute", defaultValue: "Share Route", bundle: LocalizationManager.bundle) }
        static var exportGPX: String { String(localized: "finishWalk.exportGPX", defaultValue: "Export GPX", bundle: LocalizationManager.bundle) }
        static var goHome: String { String(localized: "finishWalk.goHome", defaultValue: "Go Home", bundle: LocalizationManager.bundle) }
        static var distance: String { String(localized: "finishWalk.distance", defaultValue: "Distance", bundle: LocalizationManager.bundle) }
        static var duration: String { String(localized: "finishWalk.duration", defaultValue: "Duration", bundle: LocalizationManager.bundle) }
        static var avgPace: String { String(localized: "finishWalk.avgPace", defaultValue: "Avg Pace", bundle: LocalizationManager.bundle) }
        static var elevation: String { String(localized: "finishWalk.elevation", defaultValue: "Elevation", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Paywall
    enum Paywall {
        static var title: String { String(localized: "paywall.title", defaultValue: "Looopr Pro", bundle: LocalizationManager.bundle) }
        static var settingsRow: String { String(localized: "paywall.settingsRow", defaultValue: "Upgrade to Pro", bundle: LocalizationManager.bundle) }
        static var unavailable: String { String(localized: "paywall.unavailable", defaultValue: "Subscriptions aren't available right now. Please try again later.", bundle: LocalizationManager.bundle) }
        static var statusRow: String { String(localized: "paywall.statusRow", defaultValue: "Pro", bundle: LocalizationManager.bundle) }
        static var statusActive: String { String(localized: "paywall.statusActive", defaultValue: "Active", bundle: LocalizationManager.bundle) }
        static var manageSubscription: String { String(localized: "paywall.manageSubscription", defaultValue: "Manage Subscription", bundle: LocalizationManager.bundle) }
    }

    // MARK: - GPX export
    enum GPX {
        static var exportTitle: String { String(localized: "gpx.exportTitle", defaultValue: "Export GPX", bundle: LocalizationManager.bundle) }
        static var noTrack: String { String(localized: "gpx.noTrack", defaultValue: "This walk has no recorded GPS track to export.", bundle: LocalizationManager.bundle) }
        static var exportFailed: String { String(localized: "gpx.exportFailed", defaultValue: "Couldn't export GPX", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Saved Routes
    enum SavedRoutes {
        static var title: String { String(localized: "savedRoutes.title", defaultValue: "Saved Routes", bundle: LocalizationManager.bundle) }
        static var empty: String { String(localized: "savedRoutes.empty", defaultValue: "No saved routes yet", bundle: LocalizationManager.bundle) }
        static var emptyDescription: String { String(localized: "savedRoutes.emptyDescription", defaultValue: "Save routes you love to walk them again\nor share them with friends", bundle: LocalizationManager.bundle) }
        static var startWalk: String { String(localized: "savedRoutes.startWalk", defaultValue: "Start Walk", bundle: LocalizationManager.bundle) }
        static var share: String { String(localized: "savedRoutes.share", defaultValue: "Share", bundle: LocalizationManager.bundle) }
        static var remove: String { String(localized: "savedRoutes.remove", defaultValue: "Remove", bundle: LocalizationManager.bundle) }
        static var removeQuestion: String { String(localized: "savedRoutes.removeQuestion", defaultValue: "Remove from saved?", bundle: LocalizationManager.bundle) }

        static func willBeRemoved(_ name: String) -> String {
            return String(format: NSLocalizedString("savedRoutes.willBeRemoved", tableName: nil, bundle: LocalizationManager.bundle, value: "%@ will be removed from your saved routes.", comment: ""), name)
        }

        static var cancel: String { String(localized: "savedRoutes.cancel", defaultValue: "Cancel", bundle: LocalizationManager.bundle) }
        static var shareErrorTitle: String { String(localized: "savedRoutes.shareErrorTitle", defaultValue: "Couldn't Share", bundle: LocalizationManager.bundle) }
        static var shareErrorMessage: String { String(localized: "savedRoutes.shareErrorMessage", defaultValue: "Something went wrong. Please try again.", bundle: LocalizationManager.bundle) }

        static func shareTitle(_ name: String) -> String {
            return String(format: NSLocalizedString("savedRoutes.shareTitle", tableName: nil, bundle: LocalizationManager.bundle, value: "Check out this %@ walk on Looopr!", comment: ""), name)
        }
    }

    // MARK: - Profile
    enum Profile {
        static var title: String { String(localized: "profile.title", defaultValue: "Profile", bundle: LocalizationManager.bundle) }
        static var tabProgress: String { String(localized: "profile.tabProgress", defaultValue: "Progress", bundle: LocalizationManager.bundle) }
        static var tabActivities: String { String(localized: "profile.tabActivities", defaultValue: "Activities", bundle: LocalizationManager.bundle) }

        static func walksCompleted(_ count: Int) -> String {
            return String(format: NSLocalizedString("profile.walksCompleted", tableName: nil, bundle: LocalizationManager.bundle, value: "%@ walks completed", comment: ""), "\(count)")
        }

        static var thisWeek: String { String(localized: "profile.thisWeek", defaultValue: "THIS WEEK", bundle: LocalizationManager.bundle) }
        static var past8Weeks: String { String(localized: "profile.past8Weeks", defaultValue: "PAST 8 WEEKS", bundle: LocalizationManager.bundle) }
        static var weekStreak: String { String(localized: "profile.weekStreak", defaultValue: "Week Streak", bundle: LocalizationManager.bundle) }
        static var totalWalks: String { String(localized: "profile.totalWalks", defaultValue: "Total Walks", bundle: LocalizationManager.bundle) }
        static var completeFirstLooopr: String { String(localized: "profile.completeFirstLooopr", defaultValue: "Complete your first Looopr to see your progress here", bundle: LocalizationManager.bundle) }
        static var noWalksYet: String { String(localized: "profile.noWalksYet", defaultValue: "No walks yet", bundle: LocalizationManager.bundle) }
        static var startLoooprDescription: String { String(localized: "profile.startLoooprDescription", defaultValue: "Start a Looopr to build your activity history", bundle: LocalizationManager.bundle) }
        static var distance: String { String(localized: "profile.distance", defaultValue: "Distance", bundle: LocalizationManager.bundle) }
        static var steps: String { String(localized: "profile.steps", defaultValue: "Steps", bundle: LocalizationManager.bundle) }
        static var time: String { String(localized: "profile.time", defaultValue: "Time", bundle: LocalizationManager.bundle) }
        static var elevationGain: String { String(localized: "profile.elevationGain", defaultValue: "Elev Gain", bundle: LocalizationManager.bundle) }

        static var inAppleHealth: String { String(localized: "profile.inAppleHealth", defaultValue: "Apple Health", bundle: LocalizationManager.bundle) }

        static var deleteWalk: String { String(localized: "profile.deleteWalk", defaultValue: "Delete", bundle: LocalizationManager.bundle) }
        static var deleteWalkQuestion: String { String(localized: "profile.deleteWalkQuestion", defaultValue: "Delete this walk?", bundle: LocalizationManager.bundle) }
        static var cancel: String { String(localized: "profile.cancel", defaultValue: "Cancel", bundle: LocalizationManager.bundle) }

        static func willBeDeleted(_ name: String) -> String {
            return String(format: NSLocalizedString("profile.willBeDeleted", tableName: nil, bundle: LocalizationManager.bundle, value: "%@ will be permanently removed from your walk history. This cannot be undone.", comment: ""), name)
        }

        static var deleteFailedTitle: String { String(localized: "profile.deleteFailedTitle", defaultValue: "Delete incomplete", bundle: LocalizationManager.bundle) }
        static var deleteFailedMessage: String { String(localized: "profile.deleteFailedMessage", defaultValue: "The walk was removed from this device, but we couldn't reach the server. It may reappear when your other devices sync.", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Settings
    enum Settings {
        static var title: String { String(localized: "settings.title", defaultValue: "Settings", bundle: LocalizationManager.bundle) }
        static var account: String { String(localized: "settings.account", defaultValue: "ACCOUNT", bundle: LocalizationManager.bundle) }
        static var displayName: String { String(localized: "settings.displayName", defaultValue: "Display Name", bundle: LocalizationManager.bundle) }
        static var walkPreferences: String { String(localized: "settings.walkPreferences", defaultValue: "WALK PREFERENCES", bundle: LocalizationManager.bundle) }
        static var preferredUnits: String { String(localized: "settings.preferredUnits", defaultValue: "Preferred Units", bundle: LocalizationManager.bundle) }
        static var walkingPace: String { String(localized: "settings.walkingPace", defaultValue: "Walking Pace", bundle: LocalizationManager.bundle) }
        static var distanceUnits: String { String(localized: "settings.distanceUnits", defaultValue: "Distance Units", bundle: LocalizationManager.bundle) }
        static var units: String { String(localized: "settings.units", defaultValue: "Units", bundle: LocalizationManager.bundle) }
        static var language: String { String(localized: "settings.language", defaultValue: "Language", bundle: LocalizationManager.bundle) }
        static var appearance: String { String(localized: "settings.appearance", defaultValue: "Appearance", bundle: LocalizationManager.bundle) }
        static var appearanceSystem: String { String(localized: "settings.appearance.system", defaultValue: "System", bundle: LocalizationManager.bundle) }
        static var appearanceLight: String { String(localized: "settings.appearance.light", defaultValue: "Light", bundle: LocalizationManager.bundle) }
        static var appearanceDark: String { String(localized: "settings.appearance.dark", defaultValue: "Dark", bundle: LocalizationManager.bundle) }
        static var health: String { String(localized: "settings.health", defaultValue: "HEALTH", bundle: LocalizationManager.bundle) }
        static var appleHealth: String { String(localized: "settings.appleHealth", defaultValue: "Apple Health", bundle: LocalizationManager.bundle) }
        static var notConnected: String { String(localized: "settings.notConnected", defaultValue: "Not Connected", bundle: LocalizationManager.bundle) }
        static var connected: String { String(localized: "settings.connected", defaultValue: "Connected", bundle: LocalizationManager.bundle) }
        static var notifications: String { String(localized: "settings.notifications", defaultValue: "NOTIFICATIONS", bundle: LocalizationManager.bundle) }
        static var walkReminder: String { String(localized: "settings.walkReminder", defaultValue: "Walk Reminder", bundle: LocalizationManager.bundle) }
        static var walkReminderDescription: String { String(localized: "settings.walkReminderDescription", defaultValue: "Daily reminder to go for a walk", bundle: LocalizationManager.bundle) }
        static var reminderTime: String { String(localized: "settings.reminderTime", defaultValue: "Reminder Time", bundle: LocalizationManager.bundle) }
        static var weeklySummary: String { String(localized: "settings.weeklySummary", defaultValue: "Weekly Summary", bundle: LocalizationManager.bundle) }
        static var weeklySummaryDescription: String { String(localized: "settings.weeklySummaryDescription", defaultValue: "Sunday evening progress recap", bundle: LocalizationManager.bundle) }
        static var privacyAndData: String { String(localized: "settings.privacyAndData", defaultValue: "PRIVACY & DATA", bundle: LocalizationManager.bundle) }
        static var privacyAndDataLink: String { String(localized: "settings.privacyAndDataLink", defaultValue: "Privacy & Data", bundle: LocalizationManager.bundle) }
        static var manage: String { String(localized: "settings.manage", defaultValue: "Manage", bundle: LocalizationManager.bundle) }
        static var signIn: String { String(localized: "settings.signIn", defaultValue: "Sign In", bundle: LocalizationManager.bundle) }
        static var signOut: String { String(localized: "settings.signOut", defaultValue: "Sign Out", bundle: LocalizationManager.bundle) }
        static var cancel: String { String(localized: "settings.cancel", defaultValue: "Cancel", bundle: LocalizationManager.bundle) }
        static var about: String { String(localized: "settings.about", defaultValue: "ABOUT", bundle: LocalizationManager.bundle) }
        static var looopr: String { String(localized: "settings.looopr", defaultValue: "Looopr", bundle: LocalizationManager.bundle) }
        static var appVersion: String { String(localized: "settings.appVersion", defaultValue: "App Version", bundle: LocalizationManager.bundle) }
        static var rateLooopr: String { String(localized: "settings.rateLooopr", defaultValue: "Rate Looopr", bundle: LocalizationManager.bundle) }
        static var shareLooopr: String { String(localized: "settings.shareLooopr", defaultValue: "Share Looopr", bundle: LocalizationManager.bundle) }
        static var privacyPolicy: String { String(localized: "settings.privacyPolicy", defaultValue: "Privacy Policy", bundle: LocalizationManager.bundle) }
        static var termsOfService: String { String(localized: "settings.termsOfService", defaultValue: "Terms of Service", bundle: LocalizationManager.bundle) }
        static var support: String { String(localized: "settings.support", defaultValue: "Support", bundle: LocalizationManager.bundle) }
        static var sendFeedback: String { String(localized: "settings.sendFeedback", defaultValue: "Send feedback", bundle: LocalizationManager.bundle) }
        static var notificationsDisabled: String { String(localized: "settings.notificationsDisabled", defaultValue: "Notifications Disabled", bundle: LocalizationManager.bundle) }
        static var openSettings: String { String(localized: "settings.openSettings", defaultValue: "Open Settings", bundle: LocalizationManager.bundle) }
        static var enableNotificationsMessage: String { String(localized: "settings.enableNotificationsMessage", defaultValue: "Enable notifications in Settings to use walk reminders.", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Walking Pace
    enum WalkingPace {
        static var leisure: String { String(localized: "walkingPace.leisure", defaultValue: "Leisure", bundle: LocalizationManager.bundle) }
        static var moderate: String { String(localized: "walkingPace.moderate", defaultValue: "Moderate", bundle: LocalizationManager.bundle) }
        static var brisk: String { String(localized: "walkingPace.brisk", defaultValue: "Brisk", bundle: LocalizationManager.bundle) }
        static var leisureDescription: String { String(localized: "walkingPace.leisureDescription", defaultValue: "relaxed stroll", bundle: LocalizationManager.bundle) }
        static var moderateDescription: String { String(localized: "walkingPace.moderateDescription", defaultValue: "comfortable pace", bundle: LocalizationManager.bundle) }
        static var briskDescription: String { String(localized: "walkingPace.briskDescription", defaultValue: "fast walk", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Health Settings
    enum HealthSettings {
        static var appleHealth: String { String(localized: "healthSettings.appleHealth", defaultValue: "Apple Health", bundle: LocalizationManager.bundle) }
        static var connectAppleHealth: String { String(localized: "healthSettings.connectAppleHealth", defaultValue: "Connect Apple Health", bundle: LocalizationManager.bundle) }
        static var comingSoon: String { String(localized: "healthSettings.comingSoon", defaultValue: "Apple Health integration is coming in a future update. Stay tuned!", bundle: LocalizationManager.bundle) }
        static var syncWithAppleHealth: String { String(localized: "healthSettings.syncWithAppleHealth", defaultValue: "Sync with Apple Health", bundle: LocalizationManager.bundle) }
        static var descriptionMessage: String { String(localized: "healthSettings.descriptionMessage", defaultValue: "Connect Looopr with Apple Health to automatically save your walks and track your progress across all your health apps.", bundle: LocalizationManager.bundle) }
        static var privacyMessage: String { String(localized: "healthSettings.privacyMessage", defaultValue: "Your health data stays on your device. Looopr never uploads health information to any server.", bundle: LocalizationManager.bundle) }
        static var comingSoonButton: String { String(localized: "healthSettings.comingSoonButton", defaultValue: "Coming Soon", bundle: LocalizationManager.bundle) }
        static var ok: String { String(localized: "healthSettings.ok", defaultValue: "OK", bundle: LocalizationManager.bundle) }
        static var saveWalksToggle: String { String(localized: "healthSettings.saveWalksToggle", defaultValue: "Save walks to Apple Health", bundle: LocalizationManager.bundle) }
        static var saveWalksSubtitle: String { String(localized: "healthSettings.saveWalksSubtitle", defaultValue: "Each finished walk is added as a walking workout with its distance and route", bundle: LocalizationManager.bundle) }
        static var connectedMessage: String { String(localized: "healthSettings.connectedMessage", defaultValue: "Looopr is allowed to write walks to Apple Health.", bundle: LocalizationManager.bundle) }
        static var deniedMessage: String { String(localized: "healthSettings.deniedMessage", defaultValue: "Looopr isn't allowed to write to Apple Health. You can change that in the Health app under Sharing → Apps → Looopr.", bundle: LocalizationManager.bundle) }
        static var openHealthApp: String { String(localized: "healthSettings.openHealthApp", defaultValue: "Open Health", bundle: LocalizationManager.bundle) }
        static var unavailableMessage: String { String(localized: "healthSettings.unavailableMessage", defaultValue: "Apple Health isn't available on this device.", bundle: LocalizationManager.bundle) }
        static var featureWorkoutsTitle: String { String(localized: "healthSettings.featureWorkoutsTitle", defaultValue: "Walking Workouts", bundle: LocalizationManager.bundle) }
        static var featureWorkoutsDescription: String { String(localized: "healthSettings.featureWorkoutsDescription", defaultValue: "Every finished walk is saved as a workout in the Fitness app", bundle: LocalizationManager.bundle) }
        static var featureDistanceTitle: String { String(localized: "healthSettings.featureDistanceTitle", defaultValue: "Distance", bundle: LocalizationManager.bundle) }
        static var featureDistanceDescription: String { String(localized: "healthSettings.featureDistanceDescription", defaultValue: "The distance you actually walked, not the planned loop", bundle: LocalizationManager.bundle) }
        static var featureRouteTitle: String { String(localized: "healthSettings.featureRouteTitle", defaultValue: "Route Map", bundle: LocalizationManager.bundle) }
        static var featureRouteDescription: String { String(localized: "healthSettings.featureRouteDescription", defaultValue: "Your GPS track, shown on the workout's map", bundle: LocalizationManager.bundle) }
        static var permissionFailed: String { String(localized: "healthSettings.permissionFailed", defaultValue: "Couldn't request Apple Health access", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Health (saving walks)
    enum Health {
        static var saveTitle: String { String(localized: "health.saveTitle", defaultValue: "Save to Apple Health", bundle: LocalizationManager.bundle) }
        static var savedTitle: String { String(localized: "health.savedTitle", defaultValue: "Saved to Apple Health", bundle: LocalizationManager.bundle) }
        static var saving: String { String(localized: "health.saving", defaultValue: "Saving to Apple Health…", bundle: LocalizationManager.bundle) }
        static var saveFailedTitle: String { String(localized: "health.saveFailedTitle", defaultValue: "Couldn't save to Apple Health", bundle: LocalizationManager.bundle) }
        static var unavailable: String { String(localized: "health.unavailable", defaultValue: "Apple Health isn't available on this device.", bundle: LocalizationManager.bundle) }
        static var notAuthorized: String { String(localized: "health.notAuthorized", defaultValue: "Looopr doesn't have permission to write to Apple Health. You can grant it in Settings → Apple Health.", bundle: LocalizationManager.bundle) }
        static var nothingToSave: String { String(localized: "health.nothingToSave", defaultValue: "This walk has no distance or GPS track to save.", bundle: LocalizationManager.bundle) }
        static var saveFailed: String { String(localized: "health.saveFailed", defaultValue: "Apple Health didn't accept the workout. Please try again.", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Privacy Settings
    enum PrivacySettings {
        static var title: String { String(localized: "privacySettings.title", defaultValue: "Privacy & Data", bundle: LocalizationManager.bundle) }
        static var descriptionMessage: String { String(localized: "privacySettings.descriptionMessage", defaultValue: "We take your privacy seriously. Your data is encrypted and stored securely.", bundle: LocalizationManager.bundle) }
        static var exportMyData: String { String(localized: "privacySettings.exportMyData", defaultValue: "Export My Data", bundle: LocalizationManager.bundle) }
        static var downloadData: String { String(localized: "privacySettings.downloadData", defaultValue: "Download all your data as JSON", bundle: LocalizationManager.bundle) }
        static var dataSaved: String { String(localized: "privacySettings.dataSaved", defaultValue: "Your data has been saved to your Files app.", bundle: LocalizationManager.bundle) }
        static var exportComplete: String { String(localized: "privacySettings.exportComplete", defaultValue: "Export Complete", bundle: LocalizationManager.bundle) }
        static var deleteMyAccount: String { String(localized: "privacySettings.deleteMyAccount", defaultValue: "Delete My Account", bundle: LocalizationManager.bundle) }
        static var deleteWarning: String { String(localized: "privacySettings.deleteWarning", defaultValue: "This action cannot be undone. All your data, saved routes, and walk history will be permanently deleted.", bundle: LocalizationManager.bundle) }
        static var yourData: String { String(localized: "privacySettings.yourData", defaultValue: "YOUR DATA", bundle: LocalizationManager.bundle) }
        static var dangerZone: String { String(localized: "privacySettings.dangerZone", defaultValue: "DANGER ZONE", bundle: LocalizationManager.bundle) }
        static var deleteAccount: String { String(localized: "privacySettings.deleteAccount", defaultValue: "Delete Account", bundle: LocalizationManager.bundle) }
        static func exportFailed(_ value: String) -> String {
            String(format: NSLocalizedString("privacySettings.exportFailed", tableName: nil, bundle: LocalizationManager.bundle, value: "Export failed: %@", comment: ""), value)
        }
        static func deletionFailed(_ value: String) -> String {
            String(format: NSLocalizedString("privacySettings.deletionFailed", tableName: nil, bundle: LocalizationManager.bundle, value: "Deletion failed: %@", comment: ""), value)
        }
        static var permanentlyRemoveData: String { String(localized: "privacySettings.permanentlyRemoveData", defaultValue: "Permanently remove all your data", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Notifications
    enum Notifications {
        static var timeForLooopr: String { String(localized: "notifications.timeForLooopr", defaultValue: "Time for a Looopr!", bundle: LocalizationManager.bundle) }
        static var getOutside: String { String(localized: "notifications.getOutside", defaultValue: "Get outside and discover a new route near you.", bundle: LocalizationManager.bundle) }
        static var weeklySummary: String { String(localized: "notifications.weeklySummary", defaultValue: "Your weekly Looopr summary", bundle: LocalizationManager.bundle) }
        static var checkOutProgress: String { String(localized: "notifications.checkOutProgress", defaultValue: "Check out how far you walked this week!", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Location Search
    enum LocationSearch {
        static var useCurrentLocation: String { String(localized: "locationSearch.useCurrentLocation", defaultValue: "Use Current Location", bundle: LocalizationManager.bundle) }
        static var routesNearYou: String { String(localized: "locationSearch.routesNearYou", defaultValue: "Routes near where you are now", bundle: LocalizationManager.bundle) }
        static var recent: String { String(localized: "locationSearch.recent", defaultValue: "Recent", bundle: LocalizationManager.bundle) }
        static var results: String { String(localized: "locationSearch.results", defaultValue: "Results", bundle: LocalizationManager.bundle) }
        static var cancel: String { String(localized: "locationSearch.cancel", defaultValue: "Cancel", bundle: LocalizationManager.bundle) }
        static var resolveFailedTitle: String { String(localized: "locationSearch.resolveFailedTitle", defaultValue: "Couldn't find that place", bundle: LocalizationManager.bundle) }
        static var resolveFailedMessage: String { String(localized: "locationSearch.resolveFailedMessage", defaultValue: "Maps didn't return a location for it. Check your connection or try a more specific search.", bundle: LocalizationManager.bundle) }
        static var searchLocation: String { String(localized: "locationSearch.searchLocation", defaultValue: "Search Location", bundle: LocalizationManager.bundle) }
        static var prompt: String { String(localized: "locationSearch.prompt", defaultValue: "Search city, address, or place", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Live Activity
    enum LiveActivity {
        static var walked: String { String(localized: "liveActivity.walked", defaultValue: "walked", bundle: LocalizationManager.bundle) }
        static var ahead: String { String(localized: "liveActivity.ahead", defaultValue: "ahead", bundle: LocalizationManager.bundle) }
        static var next: String { String(localized: "liveActivity.next", defaultValue: "Next:", bundle: LocalizationManager.bundle) }
        static var turnAhead: String { String(localized: "liveActivity.turnAhead", defaultValue: "Turn ahead", bundle: LocalizationManager.bundle) }
        static var inDistance: String { String(localized: "liveActivity.inDistance", defaultValue: "in", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Time/Duration
    enum Time {
        static var min: String { String(localized: "time.min", defaultValue: "min", bundle: LocalizationManager.bundle) }
        static var h: String { String(localized: "time.h", defaultValue: "h", bundle: LocalizationManager.bundle) }
        static var hMin: String { String(localized: "time.hMin", defaultValue: "h min", bundle: LocalizationManager.bundle) }

        static func hoursAndMinutes(_ hours: Int, _ minutes: Int) -> String {
            return String(format: NSLocalizedString("time.hoursAndMinutes", tableName: nil, bundle: LocalizationManager.bundle, value: "%@h %@min", comment: ""), "\(hours)", "\(minutes)")
        }
    }

    // MARK: - Error Messages
    enum Errors {
        // Route Errors
        static var routeNotFound: String { String(localized: "error.route.notFound", defaultValue: "Route not found", bundle: LocalizationManager.bundle) }
        static var routeLoadFailed: String { String(localized: "error.route.loadFailed", defaultValue: "Failed to load route", bundle: LocalizationManager.bundle) }
        static var invalidRoute: String { String(localized: "error.route.invalid", defaultValue: "Invalid route data", bundle: LocalizationManager.bundle) }

        // Network Errors
        static var networkUnavailable: String { String(localized: "error.network.unavailable", defaultValue: "Network connection unavailable", bundle: LocalizationManager.bundle) }
        static var requestFailed: String { String(localized: "error.network.requestFailed", defaultValue: "Request failed", bundle: LocalizationManager.bundle) }
        static var serverError: String { String(localized: "error.network.serverError", defaultValue: "Server error", bundle: LocalizationManager.bundle) }

        // Navigation Errors
        static var navigationNotAvailable: String { String(localized: "error.navigation.notAvailable", defaultValue: "Navigation not available", bundle: LocalizationManager.bundle) }
        static var locationPermissionDenied: String { String(localized: "error.navigation.locationPermissionDenied", defaultValue: "Location permission denied", bundle: LocalizationManager.bundle) }

        // POI Errors
        static var poiNotFound: String { String(localized: "error.poi.notFound", defaultValue: "Point of interest not found", bundle: LocalizationManager.bundle) }
        static var poiDataInvalid: String { String(localized: "error.poi.dataInvalid", defaultValue: "Invalid point of interest data", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Share Messages
    enum Share {
        static var discoveringRoutes: String { String(localized: "share.discoveringRoutes", defaultValue: "I've been discovering new walks with Looopr! Check it out:", bundle: LocalizationManager.bundle) }
        static var checkOutRoute: String { String(localized: "share.checkOutRoute", defaultValue: "Check out this walking route on Looopr!", bundle: LocalizationManager.bundle) }

        static func walkedRoute(_ name: String) -> String {
            return String(format: NSLocalizedString("share.walkedRoute", tableName: nil, bundle: LocalizationManager.bundle, value: "I just walked the %@ with Looopr!", comment: ""), name)
        }

        static var shareThisLooopr: String { String(localized: "share.shareThisLooopr", defaultValue: "Share This Looopr", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Walk Detail
    enum WalkDetail {
        static func checkedInAt(_ value: String) -> String {
            String(format: NSLocalizedString("walkDetail.checkedInAt", tableName: nil, bundle: LocalizationManager.bundle, value: "Checked in at %@", comment: ""), value)
        }
        static var noRouteData: String { String(localized: "walkDetail.noRouteData", defaultValue: "This walk has no route data to share.", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Shared Route
    enum SharedRoute {
        static var loading: String { String(localized: "sharedRoute.loading", defaultValue: "Loading shared route...", bundle: LocalizationManager.bundle) }
        static var notFoundTitle: String { String(localized: "sharedRoute.notFoundTitle", defaultValue: "Route Not Found", bundle: LocalizationManager.bundle) }
        static var notFoundSubtitle: String { String(localized: "sharedRoute.notFoundSubtitle", defaultValue: "This route may have expired or been removed.", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Send Feedback (Settings)
    enum SendFeedback {
        static var title: String { String(localized: "sendFeedback.title", defaultValue: "Send feedback", bundle: LocalizationManager.bundle) }
        static var prompt: String { String(localized: "sendFeedback.prompt", defaultValue: "What works, what doesn't, and what should Looopr do next?", bundle: LocalizationManager.bundle) }
        static var messagePlaceholder: String { String(localized: "sendFeedback.messagePlaceholder", defaultValue: "Your message", bundle: LocalizationManager.bundle) }
        static var emailLabel: String { String(localized: "sendFeedback.emailLabel", defaultValue: "Email (optional)", bundle: LocalizationManager.bundle) }
        static var emailHint: String { String(localized: "sendFeedback.emailHint", defaultValue: "Only used if we need to reply.", bundle: LocalizationManager.bundle) }
        static var send: String { String(localized: "sendFeedback.send", defaultValue: "Send", bundle: LocalizationManager.bundle) }
        static var sending: String { String(localized: "sendFeedback.sending", defaultValue: "Sending…", bundle: LocalizationManager.bundle) }
        static var sentTitle: String { String(localized: "sendFeedback.sentTitle", defaultValue: "Thanks, got it", bundle: LocalizationManager.bundle) }
        static var sentBody: String { String(localized: "sendFeedback.sentBody", defaultValue: "We read every message. If you left an email, we'll get back to you.", bundle: LocalizationManager.bundle) }
        static var footer: String { String(localized: "sendFeedback.footer", defaultValue: "Sent with your app version and device model so we can reproduce what you saw.", bundle: LocalizationManager.bundle) }
        static var errorSend: String { String(localized: "sendFeedback.errorSend", defaultValue: "Couldn't send right now. Check your connection and try again.", bundle: LocalizationManager.bundle) }
        static var errorEmail: String { String(localized: "sendFeedback.errorEmail", defaultValue: "That email address doesn't look right.", bundle: LocalizationManager.bundle) }
        static var errorSignIn: String { String(localized: "sendFeedback.errorSignIn", defaultValue: "Sign in to send feedback.", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Miscellaneous
    enum Misc {
        static var walker: String { String(localized: "misc.walker", defaultValue: "Walker", bundle: LocalizationManager.bundle) }
        static var walk: String { String(localized: "misc.walk", defaultValue: "Walk", bundle: LocalizationManager.bundle) }
        static var name: String { String(localized: "misc.name", defaultValue: "Name", bundle: LocalizationManager.bundle) }
        static var loading: String { String(localized: "misc.loading", defaultValue: "Loading...", bundle: LocalizationManager.bundle) }
        static var cancel: String { String(localized: "misc.cancel", defaultValue: "Cancel", bundle: LocalizationManager.bundle) }
        static var error: String { String(localized: "misc.error", defaultValue: "Error", bundle: LocalizationManager.bundle) }
        static var retry: String { String(localized: "misc.retry", defaultValue: "Retry", bundle: LocalizationManager.bundle) }
        static var okay: String { String(localized: "misc.okay", defaultValue: "OK", bundle: LocalizationManager.bundle) }
        static var done: String { String(localized: "misc.done", defaultValue: "Done", bundle: LocalizationManager.bundle) }
        static var now: String { String(localized: "misc.now", defaultValue: "Now", bundle: LocalizationManager.bundle) }
        static var yes: String { String(localized: "misc.yes", defaultValue: "Yes", bundle: LocalizationManager.bundle) }
        static var no: String { String(localized: "misc.no", defaultValue: "No", bundle: LocalizationManager.bundle) }
        static var close: String { String(localized: "misc.close", defaultValue: "Close", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Off-Route Banner
    enum OffRoute {
        static var offRoute: String { String(localized: "offRoute.offRoute", defaultValue: "You're off the route", bundle: LocalizationManager.bundle) }
        static var returnToRoute: String { String(localized: "offRoute.returnToRoute", defaultValue: "Return to the marked path", bundle: LocalizationManager.bundle) }
        static var recalculating: String { String(localized: "offRoute.recalculating", defaultValue: "Recalculating...", bundle: LocalizationManager.bundle) }
        static var ownWayTitle: String { String(localized: "offRoute.ownWayTitle", defaultValue: "Going your own way?", bundle: LocalizationManager.bundle) }
        static var ownWayBody: String { String(localized: "offRoute.ownWayBody", defaultValue: "We've stopped recalculating. Directions resume when you're back on the route.", bundle: LocalizationManager.bundle) }
        static var guideMeBack: String { String(localized: "offRoute.guideMeBack", defaultValue: "Guide me back", bundle: LocalizationManager.bundle) }
        static var checkingRoute: String { String(localized: "offRoute.checkingRoute", defaultValue: "Checking route...", bundle: LocalizationManager.bundle) }
        static var findingPath: String { String(localized: "offRoute.findingPath", defaultValue: "Finding your path forward", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Feedback
    enum Feedback {
        static var howWasWalk: String { String(localized: "feedback.howWasWalk", defaultValue: "How was your walk?", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Language Restart Prompt
    enum LanguageRestart {
        static var title: String { String(localized: "languageRestart.title", defaultValue: "Language Changed", bundle: LocalizationManager.bundle) }
        static var message: String { String(localized: "languageRestart.message", defaultValue: "The app needs to restart for the language change to take effect.", bundle: LocalizationManager.bundle) }
        static var restartLater: String { String(localized: "languageRestart.restartLater", defaultValue: "Restart Later", bundle: LocalizationManager.bundle) }
        static var restart: String { String(localized: "languageRestart.restart", defaultValue: "OK", bundle: LocalizationManager.bundle) }
    }

    // MARK: - Onboarding (first launch)
    enum Onboarding {
        private static var b: Bundle { LocalizationManager.bundle }
        static var skip: String { String(localized: "onboarding.skip", defaultValue: "Skip", bundle: b) }
        static var next: String { String(localized: "onboarding.next", defaultValue: "Next", bundle: b) }
        static var getStarted: String { String(localized: "onboarding.getStarted", defaultValue: "Get started", bundle: b) }
        static var locationNote: String { String(localized: "onboarding.locationNote", defaultValue: "Looopr uses your location to build loops around you.", bundle: b) }
        static func pageIndicator(_ page: Int, _ total: Int) -> String {
            String(format: String(localized: "onboarding.pageIndicator", defaultValue: "Page %1$d of %2$d", bundle: b), page, total)
        }

        static var page1Eyebrow: String { String(localized: "onboarding.page1.eyebrow", defaultValue: "Pick a time", bundle: b) }
        static var page1Title: String { String(localized: "onboarding.page1.title", defaultValue: "Say how long.\nGet a loop.", bundle: b) }
        static var page1Body: String { String(localized: "onboarding.page1.body", defaultValue: "Choose 15 minutes to 3 hours. We\u{2019}ll plan a walk that ends right where you started.", bundle: b) }

        static var page2Eyebrow: String { String(localized: "onboarding.page2.eyebrow", defaultValue: "Along the way", bundle: b) }
        static var page2Title: String { String(localized: "onboarding.page2.title", defaultValue: "Something to see\non every walk", bundle: b) }
        static var page2Body: String { String(localized: "onboarding.page2.body", defaultValue: "Parks, landmarks and local spots along your route, with ratings and opening hours. The first week is free.", bundle: b) }

        static var page3Eyebrow: String { String(localized: "onboarding.page3.eyebrow", defaultValue: "Walk it", bundle: b) }
        static var page3Title: String { String(localized: "onboarding.page3.title", defaultValue: "Just walk.\nWe\u{2019}ll guide you.", bundle: b) }
        static var page3Body: String { String(localized: "onboarding.page3.body", defaultValue: "Turn-by-turn directions, even on your lock screen. Every walk is saved to Apple Health.", bundle: b) }

        // Illustration labels
        static var minutesUnit: String { String(localized: "onboarding.illustration.minutesUnit", defaultValue: "min", bundle: b) }
        static var sampleRouteName: String { String(localized: "onboarding.illustration.sampleRouteName", defaultValue: "South Loop (4.0 km)", bundle: b) }
        static var pointsOfInterest: String { String(localized: "onboarding.illustration.pointsOfInterest", defaultValue: "POINTS OF INTEREST", bundle: b) }
        static func onRoute(_ distance: String) -> String {
            String(format: String(localized: "onboarding.illustration.onRoute", defaultValue: "On route · %@", bundle: b), distance)
        }
        static var sampleNextTurn: String { String(localized: "onboarding.illustration.nextTurn", defaultValue: "Then turn right onto Keizersgracht", bundle: b) }
        static var statTime: String { String(localized: "onboarding.illustration.statTime", defaultValue: "Time", bundle: b) }
        static var statDistance: String { String(localized: "onboarding.illustration.statDistance", defaultValue: "Distance", bundle: b) }
        static var statRemaining: String { String(localized: "onboarding.illustration.statRemaining", defaultValue: "Remaining", bundle: b) }
    }
}
