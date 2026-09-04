import CoreLocation
import Foundation

/// One recorded GPS fix from a walk — what the user *actually* walked, as
/// opposed to the planned route polyline in `WalkSession.routeCoordinates`.
///
/// Timestamps are what make this exportable to Strava/GPX: every trackpoint
/// in a GPX/TCX/FIT upload must carry a time.
///
/// Coding keys are deliberately short: a one-hour walk is roughly a thousand
/// of these and they're stored as JSON both locally and in Supabase.
struct TrackPoint: Codable, Sendable, Hashable {
    let latitude: Double
    let longitude: Double
    /// Metres above sea level; `nil` when the fix had no valid altitude.
    let altitude: Double?
    let timestamp: Date
    /// Horizontal accuracy in metres; `nil` when unknown.
    let horizontalAccuracy: Double?

    private enum CodingKeys: String, CodingKey {
        case latitude = "lat"
        case longitude = "lon"
        case altitude = "ele"
        case timestamp = "t"
        case horizontalAccuracy = "acc"
    }

    init(
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        timestamp: Date,
        horizontalAccuracy: Double? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
    }

    init(location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.verticalAccuracy >= 0 ? location.altitude : nil
        self.timestamp = location.timestamp
        self.horizontalAccuracy = location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
