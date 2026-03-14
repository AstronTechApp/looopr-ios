import Foundation
import CoreGraphics

struct AppConfiguration: Sendable {

    static let current: AppConfiguration = {
        switch AppEnvironment.current {
        case .debug:    return .debug
        case .staging:  return .staging
        case .production: return .production
        }
    }()

    // MARK: - Route Generation

    struct Generation: Sendable {
        let debounceSeconds: TimeInterval
        let maxCandidates: Int
        let maxRetryAttempts: Int
        let cacheTTLSeconds: TimeInterval
        let walkingSpeedKmH: Double
        let radiusMultiplier: Double
        let shortRatioThreshold: Double
        let longRatioThreshold: Double
        let scaleUpFactor: Double
        let scaleDownFactor: Double
        let toleranceMinutes: Int
        let maxTerrainFactors: Int
        let significantLocationChangeMeters: Double
        let backtrackOverlapThreshold: Double
    }
    let generation: Generation

    // MARK: - POI

    struct POIConfig: Sendable {
        struct QualityThresholds: Sendable {
            let minRating: Double
            let minReviewCount: Int
        }
        let attractionThresholds: QualityThresholds
        let foodThresholds: QualityThresholds
        let foodFallbackMinRating: Double
        let maxDistanceFromRouteMeters: Double
        let maxPOIsPerRoute: Int
        let searchRadiusCapMeters: Double
        let cacheTTLSeconds: TimeInterval
        let googlePlacesCacheTTLSeconds: TimeInterval
    }
    let poi: POIConfig

    // MARK: - Navigation

    struct Navigation: Sendable {
        let stepAdvanceThresholdMeters: Double
        let offRouteThresholdMeters: Double
        let offRouteHoldSeconds: TimeInterval
        let rerouteCooldownSeconds: TimeInterval
        let noProgressTimeoutSeconds: TimeInterval
        let directionCheckDistanceMeters: Double
        let directionReverseRatio: Double
    }
    let navigation: Navigation

    // MARK: - Photo

    struct Photo: Sendable {
        let jpegCompressionQuality: CGFloat
        let maxPhotosPerRoute: Int
    }
    let photo: Photo

    // MARK: - Freemium

    struct Freemium: Sendable {
        let freeRouteLimit: Int
        let paidRouteLimit: Int
    }
    let freemium: Freemium

    // MARK: - Presets

    static let production = AppConfiguration(
        generation: Generation(
            debounceSeconds: 2.0,
            maxCandidates: 8,
            maxRetryAttempts: 3,
            cacheTTLSeconds: 10,
            walkingSpeedKmH: 4.0,
            radiusMultiplier: 0.20,
            shortRatioThreshold: 0.80,
            longRatioThreshold: 1.20,
            scaleUpFactor: 1.3,
            scaleDownFactor: 0.75,
            toleranceMinutes: 10,
            maxTerrainFactors: 20,
            significantLocationChangeMeters: 50,
            backtrackOverlapThreshold: 0.30
        ),
        poi: POIConfig(
            attractionThresholds: .init(minRating: 4.0, minReviewCount: 30),
            foodThresholds: .init(minRating: 4.4, minReviewCount: 20),
            foodFallbackMinRating: 4.0,
            maxDistanceFromRouteMeters: 200,
            maxPOIsPerRoute: 6,
            searchRadiusCapMeters: 2000,
            cacheTTLSeconds: 300,
            googlePlacesCacheTTLSeconds: 3600
        ),
        navigation: Navigation(
            stepAdvanceThresholdMeters: 25,
            offRouteThresholdMeters: 50,
            offRouteHoldSeconds: 5,
            rerouteCooldownSeconds: 30,
            noProgressTimeoutSeconds: 90,
            directionCheckDistanceMeters: 50,
            directionReverseRatio: 0.6
        ),
        photo: Photo(jpegCompressionQuality: 0.8, maxPhotosPerRoute: 50),
        freemium: Freemium(freeRouteLimit: 1, paidRouteLimit: 8)
    )

    static let debug = production
    static let staging = production
}
