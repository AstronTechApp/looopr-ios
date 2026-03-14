import UIKit
import CoreLocation

actor PhotoStorageService: PhotoManaging {
    private let fileStore: FileStore
    private let metadataStore: PersistenceStoring
    private let metadataKey = "muter.photoMetadata"
    private let logger = AppLogger(category: "PhotoStorage")

    init(store: PersistenceStoring) {
        self.fileStore = FileStore(subdirectory: "MuterPhotos")
        self.metadataStore = store
    }

    func savePhoto(
        image: UIImage,
        routeId: UUID,
        location: CLLocationCoordinate2D?,
        note: String?
    ) async throws -> RoutePhoto {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw MuterError.photo(.compressionFailed)
        }
        let photoId = UUID()
        let filename = "\(photoId.uuidString).jpg"
        try await fileStore.save(data: data, filename: filename)

        let photo = RoutePhoto(
            id: photoId,
            routeId: routeId,
            latitude: location?.latitude ?? 0,
            longitude: location?.longitude ?? 0,
            filename: filename,
            note: note
        )

        var all = loadAllMetadata()
        all.append(photo)
        try metadataStore.save(all, forKey: metadataKey)
        return photo
    }

    func loadImage(for photo: RoutePhoto) async -> UIImage? {
        guard let data = try? await fileStore.load(filename: photo.filename) else { return nil }
        return UIImage(data: data)
    }

    func deletePhoto(_ photo: RoutePhoto) async throws {
        try await fileStore.delete(filename: photo.filename)
        var all = loadAllMetadata()
        all.removeAll { $0.id == photo.id }
        try metadataStore.save(all, forKey: metadataKey)
    }

    func photos(for routeId: UUID) async -> [RoutePhoto] {
        loadAllMetadata().filter { $0.routeId == routeId }
    }

    func updateNote(photoId: UUID, note: String?) async throws {
        var all = loadAllMetadata()
        guard let index = all.firstIndex(where: { $0.id == photoId }) else {
            throw MuterError.photo(.notFound)
        }
        all[index].note = note
        try metadataStore.save(all, forKey: metadataKey)
    }

    private func loadAllMetadata() -> [RoutePhoto] {
        (try? metadataStore.load([RoutePhoto].self, forKey: metadataKey)) ?? []
    }
}
