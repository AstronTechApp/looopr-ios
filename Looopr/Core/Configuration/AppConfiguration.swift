import Foundation

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
        /// Number of legs per loop for MKDirections (freemium). 4 = quadrilateral.
        let freemiumLegCount: Int
        /// Number of legs per loop for Mapbox (paid). 5 = pentagon.
        let paidLegCount: Int
    }
    let generation: Generation

    // MARK: - POI

    struct POIConfig: Sendable {
        struct QualityThresholds: Sendable {
            let minRating: Double
            let minReviewCount: Int
        }
        let attractionThresholds: QualityThresholds
        /// Higher bar for noisy categories (landmark, gallery) that need stronger quality signals.
        let attractionHighBarThresholds: QualityThresholds
        let foodThresholds: QualityThresholds
        let foodFallbackMinRating: Double
        let maxDistanceFromRouteMeters: Double
        /// POIs within this distance are "On Route"; beyond are "Near Route"
        let onRouteThresholdMeters: Double
        /// Cafes & restaurants must be within this distance to appear
        let foodMaxDistanceMeters: Double
        let maxPOIsPerRoute: Int
        let searchRadiusCapMeters: Double
        let cacheTTLSeconds: TimeInterval
        let googlePlacesCacheTTLSeconds: TimeInterval
        /// Spacing between Nearby Search query points along the route.
        let searchIntervalMeters: Double
        /// Radius per Nearby Search query point (strict geographic).
        let searchRadiusPerPointMeters: Double
        /// Post-fetch hard filter: discard results beyond this distance from any route waypoint.
        let maxCorridorDistanceMeters: Double
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
        let foodSpotProximityMeters: Double
        // Smart re-routing
        let gpsAccuracyThresholdMeters: Double
        let reentrySearchMinMeters: Double
        let reentrySearchMaxMeters: Double
        let reentryCorridorDegrees: Double
        let suppressRerouteLastPercent: Double
        let rerouteToastDismissSeconds: TimeInterval
        let midWalkDirectionThresholdDegrees: Double
        let midWalkDirectionConsecutiveChecks: Int
        let midWalkDirectionCooldownSeconds: TimeInterval
        // Wrong-way detection
        let wrongWayWarmupSeconds: TimeInterval
        let wrongWayDetectionWindowMeters: Double
        let wrongWayDivergenceDegrees: Double
        let wrongWayTriggerMeters: Double
        /// Maximum number of user-confirmed route flips per session.
        let wrongWayMaxFlips: Int
    }
    let navigation: Navigation

    // MARK: - Freemium

    struct Freemium: Sendable {
        /// Routes shown to free users (MKDirections quadrilateral loops).
        let freeRouteLimit: Int
        /// Routes shown to paid users (Mapbox pentagon loops).
        let paidRouteLimit: Int
    }
    let freemium: Freemium

    // MARK: - Presets

    static let production = AppConfiguration(
        generation: Generation(
            debounceSeconds: 1.0,
            maxCandidates: 8,
            maxRetryAttempts: 3,
            cacheTTLSeconds: 300,
            walkingSpeedKmH: 4.0,
            radiusMultiplier: 0.20,
            shortRatioThreshold: 0.65,
            longRatioThreshold: 1.45,
            scaleUpFactor: 1.3,
            scaleDownFactor: 0.75,
            toleranceMinutes: 10,
            maxTerrainFactors: 20,
            significantLocationChangeMeters: 50,
            backtrackOverlapThreshold: 0.25,
            freemiumLegCount: 4,
            paidLegCount: 5
        ),
        poi: POIConfig(
            attractionThresholds: .init(minRating: 4.0, minReviewCount: 30),
            attractionHighBarThresholds: .init(minRating: 4.0, minReviewCount: 100),
            foodThresholds: .init(minRating: 4.4, minReviewCount: 5),
            foodFallbackMinRating: 4.0,
            maxDistanceFromRouteMeters: 500,
            onRouteThresholdMeters: 100,
            foodMaxDistanceMeters: 400,
            maxPOIsPerRoute: 20,
            searchRadiusCapMeters: 2000,
            cacheTTLSeconds: 300,
            googlePlacesCacheTTLSeconds: 3600,
            searchIntervalMeters: 350,
            searchRadiusPerPointMeters: 300,
            maxCorridorDistanceMeters: 400
        ),
        navigation: Navigation(
            stepAdvanceThresholdMeters: 12,
            offRouteThresholdMeters: 50,
            offRouteHoldSeconds: 8,
            rerouteCooldownSeconds: 30,
            noProgressTimeoutSeconds: 90,
            directionCheckDistanceMeters: 30,
            directionReverseRatio: 0.6,
            foodSpotProximityMeters: 50,
            gpsAccuracyThresholdMeters: 20,
            reentrySearchMinMeters: 150,
            reentrySearchMaxMeters: 500,
            reentryCorridorDegrees: 60,
            suppressRerouteLastPercent: 0.10,
            rerouteToastDismissSeconds: 3,
            midWalkDirectionThresholdDegrees: 150,
            midWalkDirectionConsecutiveChecks: 3,
            midWalkDirectionCooldownSeconds: 60,
            wrongWayWarmupSeconds: 5,
            wrongWayDetectionWindowMeters: 250,
            wrongWayDivergenceDegrees: 120,
            wrongWayTriggerMeters: 12,
            wrongWayMaxFlips: 1
        ),
        freemium: Freemium(freeRouteLimit: 2, paidRouteLimit: 8)
    )

    static let debug = production
    static let staging = production
}
