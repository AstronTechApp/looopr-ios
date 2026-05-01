import Foundation

enum AppEnvironment {
    case debug
    case staging
    case production

    static var current: AppEnvironment {
        #if DEBUG
        return .debug
        #else
        return .production
        #endif
    }
}
