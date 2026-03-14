import UIKit
import CoreLocation

protocol PhotoManaging: Sendable {
    func savePhoto(
        image: UIImage,
        routeId: UUID,
        location: CLLocationCoordinate2D?,
        note: String?
    ) async throws -> RoutePhoto

    func loadImage(for photo: RoutePhoto) async -> UIImage?
    func deletePhoto(_ photo: RoutePhoto) async throws
    func photos(for routeId: UUID) async -> [RoutePhoto]
    func updateNote(photoId: UUID, note: String?) async throws
}
