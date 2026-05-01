import MapKit

enum POICategory: String, Codable, CaseIterable, Sendable {
    // Primary - Tourist Attractions (highlighted, revenue-generating)
    case museum
    case monument
    case historicSite
    case church
    case castle
    case park
    case garden
    case gallery
    case theater
    case zoo
    case aquarium
    case landmark
    case viewpoint

    // Secondary - Food & Drink (add-on suggestions, 4.4+ rating)
    case restaurant
    case cafe
    case bakery
    case bar

    case other

    var isTouristAttraction: Bool {
        switch self {
        case .museum, .monument, .historicSite, .church, .castle,
             .park, .garden, .gallery, .theater, .zoo, .aquarium,
             .landmark, .viewpoint:
            return true
        default:
            return false
        }
    }

    /// Categories where visitors typically buy tickets/admission
    var isTypicallyTicketed: Bool {
        switch self {
        case .museum, .castle, .gallery, .theater, .zoo, .aquarium, .historicSite:
            return true
        default:
            return false
        }
    }

    var isFood: Bool {
        switch self {
        case .restaurant, .cafe, .bakery, .bar:
            return true
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .museum: return L10n.POI.Category.museum
        case .monument: return L10n.POI.Category.monument
        case .historicSite: return L10n.POI.Category.historicSite
        case .church: return L10n.POI.Category.church
        case .castle: return L10n.POI.Category.castle
        case .park: return L10n.POI.Category.park
        case .garden: return L10n.POI.Category.garden
        case .gallery: return L10n.POI.Category.gallery
        case .theater: return L10n.POI.Category.theater
        case .zoo: return L10n.POI.Category.zoo
        case .aquarium: return L10n.POI.Category.aquarium
        case .landmark: return L10n.POI.Category.landmark
        case .viewpoint: return L10n.POI.Category.viewpoint
        case .restaurant: return L10n.POI.Category.restaurant
        case .cafe: return L10n.POI.Category.cafe
        case .bakery: return L10n.POI.Category.bakery
        case .bar: return L10n.POI.Category.bar
        case .other: return L10n.POI.Category.other
        }
    }

    var systemImage: String {
        switch self {
        case .museum:       return "building.columns"
        case .monument:     return "obelisk"
        case .historicSite: return "building.columns.fill"
        case .church:       return "cross"
        case .castle:       return "building.2"
        case .park:         return "tree"
        case .garden:       return "leaf"
        case .gallery:      return "paintpalette"
        case .theater:      return "theatermasks"
        case .zoo:          return "pawprint"
        case .aquarium:     return "fish"
        case .landmark:     return "mappin.and.ellipse"
        case .viewpoint:    return "binoculars"
        case .restaurant:   return "fork.knife"
        case .cafe:         return "cup.and.saucer"
        case .bakery:       return "birthday.cake"
        case .bar:          return "wineglass"
        case .other:        return "mappin"
        }
    }

    /// Selection priority tier (lower = selected first when capping).
    ///
    /// When a route has more qualified attractions than the display limit,
    /// higher-priority categories fill first, then lower tiers fill remaining
    /// slots. Within each tier, POIs are distributed randomly along the route
    /// so every section of the walk has something to see.
    ///
    /// Tier 0 — Landmarks & tourist attractions (The Gherkin, Tower Bridge)
    /// Tier 1 — Parks, gardens, viewpoints (natural highlights of any walk)
    /// Tier 2 — Museums, major galleries, castles, historic sites (cultural)
    /// Tier 3 — Churches, monuments (common in European cities, lower novelty)
    /// Tier 4 — Theaters, zoos, aquariums (niche — still shown if space)
    /// Tier 5 — Everything else
    var selectionPriority: Int {
        switch self {
        case .landmark:
            return 0
        case .park, .garden, .viewpoint:
            return 1
        case .museum, .gallery, .castle, .historicSite:
            return 2
        case .church, .monument:
            return 3
        case .theater, .zoo, .aquarium:
            return 4
        default:
            return 5
        }
    }

    /// Sort priority within the attractions list (lower = shown first).
    /// Museums and major cultural venues appear before theaters.
    var sortPriority: Int {
        selectionPriority
    }

    /// Fallback description when Google Places doesn't provide an editorial summary
    var genericDescription: String {
        switch self {
        case .museum:       return "Museum and cultural exhibition"
        case .monument:     return "Historic monument and memorial"
        case .historicSite: return "Historic site of cultural significance"
        case .church:       return "Church and place of worship"
        case .castle:       return "Castle and historic fortification"
        case .park:         return "Park and green space"
        case .garden:       return "Garden and botanical area"
        case .gallery:      return "Art gallery and exhibition space"
        case .theater:      return "Theater and performing arts venue"
        case .zoo:          return "Zoo and wildlife park"
        case .aquarium:     return "Aquarium and marine life center"
        case .landmark:     return "Notable landmark and point of interest"
        case .viewpoint:    return "Scenic viewpoint"
        case .restaurant:   return "Restaurant"
        case .cafe:         return "Cafe and coffee house"
        case .bakery:       return "Bakery and pastry shop"
        case .bar:          return "Bar and lounge"
        case .other:        return "Point of interest"
        }
    }

    static func from(mapKitCategory: MKPointOfInterestCategory?) -> POICategory {
        guard let category = mapKitCategory else { return .landmark }

        // iOS 18+ categories — checked first to avoid compiler warnings in the
        // main switch (which only covers categories available on iOS 17).
        if #available(iOS 18.0, *) {
            if category == .landmark       { return .landmark }
            if category == .castle         { return .castle }
            if category == .amusementPark  { return .zoo }
        }

        switch category {
        case .museum:                return .museum
        case .park, .nationalPark:   return .park
        case .theater:               return .theater
        case .restaurant:            return .restaurant
        case .cafe, .bakery:         return .cafe
        case .zoo:                   return .zoo
        case .aquarium:              return .aquarium
        default:                     return .landmark
        }
    }

    static func from(googleTypes: [String]) -> POICategory {
        let types = Set(googleTypes)
        // Food categories (check first — a restaurant in a historic building is still food)
        // Cafe/coffee_shop checked before restaurant because Google often tags coffee shops
        // with both ["cafe", "restaurant"] — the more specific type should win.
        if types.contains("cafe") || types.contains("coffee_shop") { return .cafe }
        if types.contains("bakery") { return .bakery }
        if !types.isDisjoint(with: ["restaurant", "meal_takeaway", "meal_delivery", "food"]) { return .restaurant }
        if types.contains("bar") || types.contains("night_club") { return .bar }
        // Attraction categories
        if types.contains("museum") { return .museum }
        if types.contains("church") || types.contains("place_of_worship") { return .church }
        if types.contains("park") || types.contains("national_park") { return .park }
        if types.contains("art_gallery") { return .gallery }
        if types.contains("zoo") { return .zoo }
        if types.contains("aquarium") { return .aquarium }
        if types.contains("castle") { return .castle }
        if types.contains("tourist_attraction") { return .landmark }
        if types.contains("point_of_interest") { return .landmark }
        return .other
    }
}
