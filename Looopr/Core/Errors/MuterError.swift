import Foundation

enum LoooprError: Error, Equatable {
    case route(RouteError)
    case poi(POIError)
    case network(NetworkError)
    case photo(PhotoError)
    case navigation(NavigationError)
    case persistence(String)

    var userFacingMessage: String {
        switch self {
        case .route(let e):      return e.userFacingMessage
        case .poi(let e):        return e.userFacingMessage
        case .network(let e):    return e.userFacingMessage
        case .photo(let e):      return e.userFacingMessage
        case .navigation(let e): return e.userFacingMessage
        case .persistence(let msg): return msg
        }
    }
}
