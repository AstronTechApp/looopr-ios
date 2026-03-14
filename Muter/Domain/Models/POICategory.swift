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
        case .historicSite: return "Historic Site"
        default: return rawValue.capitalized
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

    static func from(mapKitCategory: MKPointOfInterestCategory?) -> POICategory {
        guard let category = mapKitCategory else { return .landmark }
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
        if !types.isDisjoint(with: ["restaurant", "meal_takeaway", "meal_delivery"]) { return .restaurant }
        if types.contains("cafe") || types.contains("coffee_shop") { return .cafe }
        if types.contains("bakery") { return .bakery }
        if types.contains("bar") || types.contains("night_club") { return .bar }
        if types.contains("museum") { return .museum }
        if types.contains("church") || types.contains("place_of_worship") { return .church }
        if types.contains("park") || types.contains("national_park") { return .park }
        if types.contains("art_gallery") { return .gallery }
        if types.contains("zoo") { return .zoo }
        if types.contains("aquarium") { return .aquarium }
        if types.contains("castle") { return .castle }
        if types.contains("tourist_attraction") { return .landmark }
        return .other
    }
}
