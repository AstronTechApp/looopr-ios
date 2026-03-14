import Foundation

enum CollageTemplate: String, CaseIterable, Identifiable, Sendable {
    case grid2x2
    case grid3x3
    case filmStrip
    case story
    case polaroid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grid2x2:    return "2x2 Grid"
        case .grid3x3:    return "3x3 Grid"
        case .filmStrip:  return "Film Strip"
        case .story:      return "Story"
        case .polaroid:   return "Polaroid"
        }
    }

    var requiredPhotos: Int {
        switch self {
        case .grid2x2:    return 4
        case .grid3x3:    return 9
        case .filmStrip:  return 3
        case .story:      return 5
        case .polaroid:   return 1
        }
    }
}
