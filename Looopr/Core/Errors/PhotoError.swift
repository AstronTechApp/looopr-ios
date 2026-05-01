import Foundation

enum PhotoError: Error, Equatable {
    case compressionFailed
    case saveFailed(String)
    case deleteFailed(String)
    case notFound

    var userFacingMessage: String {
        switch self {
        case .compressionFailed:
            return "Could not save the photo."
        case .saveFailed:
            return "Failed to save photo to device."
        case .deleteFailed:
            return "Failed to delete the photo."
        case .notFound:
            return "Photo not found."
        }
    }
}
