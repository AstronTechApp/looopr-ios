import Foundation

protocol POIEnriching: Sendable {
    func enrich(poi: POI, minRating: Double?) async -> POI?
}
