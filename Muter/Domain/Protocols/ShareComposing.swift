import UIKit

protocol ShareComposing: Sendable {
    func renderShareImage(for route: Route) async -> UIImage?
    func renderStoryImage(for route: Route, photos: [UIImage]) async -> UIImage?
}
