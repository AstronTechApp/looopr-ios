import Foundation

protocol VideoGenerating: Sendable {
    func generateVideo(
        for route: Route,
        photos: [RoutePhoto],
        progress: @Sendable (Double) -> Void
    ) async throws -> URL
}
